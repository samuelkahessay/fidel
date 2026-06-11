import Foundation
import SwiftUI
import ImageIO
import UniformTypeIdentifiers

/// Converts raw `StrokePoint` arrays into smooth cubic-bezier SwiftUI `Path`s
/// using Catmull-Rom spline interpolation.
enum StrokeSmoother {

    /// Default tension for Catmull-Rom interpolation (0.5 = centripetal).
    static let defaultTension: CGFloat = 0.5

    /// Builds a smooth `CGPath` from normalized stroke points scaled to `canvasSize`.
    /// Falls back to straight line segments when fewer than 3 points are available.
    /// Used directly when Core Graphics APIs (e.g. envelope generation) are needed.
    static func smoothCGPath(
        from points: [StrokePoint],
        canvasSize: CGSize,
        tension: CGFloat = defaultTension
    ) -> CGPath {
        let cgPath = CGMutablePath()
        guard !points.isEmpty else { return cgPath }

        let scaled = points.map { CGPoint(x: $0.x * canvasSize.width, y: $0.y * canvasSize.height) }

        cgPath.move(to: scaled[0])

        guard scaled.count >= 3 else {
            for pt in scaled.dropFirst() {
                cgPath.addLine(to: pt)
            }
            return cgPath
        }

        for i in 0..<(scaled.count - 1) {
            let p0 = i > 0 ? scaled[i - 1] : mirror(scaled[1], around: scaled[0])
            let p1 = scaled[i]
            let p2 = scaled[i + 1]
            let p3 = (i + 2) < scaled.count ? scaled[i + 2] : mirror(scaled[scaled.count - 2], around: scaled[scaled.count - 1])

            let t = tension
            let cp1 = CGPoint(
                x: p1.x + (p2.x - p0.x) / (6.0 * t),
                y: p1.y + (p2.y - p0.y) / (6.0 * t)
            )
            let cp2 = CGPoint(
                x: p2.x - (p3.x - p1.x) / (6.0 * t),
                y: p2.y - (p3.y - p1.y) / (6.0 * t)
            )

            cgPath.addCurve(to: p2, control1: cp1, control2: cp2)
        }

        return cgPath
    }

    /// Builds a smooth SwiftUI `Path` from normalized stroke points scaled to `canvasSize`.
    /// Delegates to `smoothCGPath` for the actual Catmull-Rom computation.
    static func smoothPath(
        from points: [StrokePoint],
        canvasSize: CGSize,
        tension: CGFloat = defaultTension
    ) -> Path {
        Path(smoothCGPath(from: points, canvasSize: canvasSize, tension: tension))
    }

    /// Interpolates a position along the scaled point array at a fractional `t` (0...1).
    /// Used to compute the pen-tip indicator position.
    static func interpolatePosition(
        in points: [StrokePoint],
        at t: CGFloat,
        canvasSize: CGSize
    ) -> CGPoint? {
        guard !points.isEmpty else { return nil }
        let clamped = min(max(t, 0), 1)
        let index = clamped * CGFloat(points.count - 1)
        let lower = Int(index)
        let upper = min(lower + 1, points.count - 1)
        let frac = index - CGFloat(lower)

        let p = points[lower]
        let q = points[upper]
        let f = Double(frac)
        let interpX = p.x + (q.x - p.x) * f
        let interpY = p.y + (q.y - p.y) * f
        return CGPoint(x: interpX * canvasSize.width, y: interpY * canvasSize.height)
    }

    // MARK: - Private

    /// Reflects `point` across `center` to create a virtual endpoint.
    private static func mirror(_ point: CGPoint, around center: CGPoint) -> CGPoint {
        CGPoint(x: 2 * center.x - point.x, y: 2 * center.y - point.y)
    }
}

final class StrokeRevealRegion {
    let smoothedPath: Path
    let regionImage: CGImage

    private static let revealFeather: CGFloat = 0.022
    private static let progressDenominator = CGFloat(UInt16.max - 1)
    private let width: Int
    private let height: Int
    private let progressMap: [UInt16]
    private let ownedMask: [UInt8]
    private var revealedMask: [UInt8]
    private var lastProgress: CGFloat = -1
    private var cachedImage: CGImage?

    init(smoothedPath: Path, progressMap: [UInt16], ownedMask: [UInt8], width: Int, height: Int) {
        self.smoothedPath = smoothedPath
        self.regionImage = Self.makeAlphaImage(from: ownedMask, width: width, height: height)
        self.width = width
        self.height = height
        self.progressMap = progressMap
        self.ownedMask = ownedMask
        self.revealedMask = [UInt8](repeating: 0, count: ownedMask.count)
        self.cachedImage = Self.makeAlphaImage(from: revealedMask, width: width, height: height)
    }

    func image(for progress: CGFloat) -> CGImage {
        let clamped = min(max(progress, 0), 1)
        if abs(clamped - lastProgress) < 0.0001, let cachedImage {
            return cachedImage
        }

        if clamped <= 0 {
            lastProgress = 0
            reset()
            return cachedImage ?? Self.makeAlphaImage(from: revealedMask, width: width, height: height)
        }

        if clamped >= 1 {
            lastProgress = 1
            return regionImage
        }

        lastProgress = clamped

        let featherHalf = max(Self.revealFeather * 0.5, 0.0001)
        let denominator = Self.progressDenominator
        let edgeScale = max(Self.revealFeather, 0.0001)

        for index in 0..<revealedMask.count {
            guard ownedMask[index] > 127 else {
                revealedMask[index] = 0
                continue
            }

            let value = progressMap[index]
            guard value < UInt16.max else {
                revealedMask[index] = 0
                continue
            }

            let pixelProgress = CGFloat(value) / denominator
            let start = pixelProgress - featherHalf
            let end = pixelProgress + featherHalf
            let alpha: UInt8

            if clamped <= start {
                alpha = 0
            } else if clamped >= end {
                alpha = 255
            } else {
                let normalized = (clamped - start) / edgeScale
                alpha = UInt8((min(max(normalized, 0), 1) * 255).rounded(.toNearestOrAwayFromZero))
            }

            revealedMask[index] = alpha
        }

        let updatedImage = Self.makeAlphaImage(from: revealedMask, width: width, height: height)
        cachedImage = updatedImage
        return updatedImage
    }

    private func reset() {
        revealedMask = [UInt8](repeating: 0, count: revealedMask.count)
        cachedImage = Self.makeAlphaImage(from: revealedMask, width: width, height: height)
    }

    static func makeAlphaImage(from mask: [UInt8], width: Int, height: Int) -> CGImage {
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        for i in 0..<mask.count {
            let offset = i * 4
            rgba[offset] = 255
            rgba[offset + 1] = 255
            rgba[offset + 2] = 255
            rgba[offset + 3] = mask[i]
        }

        let data = Data(rgba)
        let provider = CGDataProvider(data: data as CFData)

        let fallback = CGImage(
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: CGDataProvider(data: Data([0, 0, 0, 0]) as CFData)!,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!

        guard let provider else { return fallback }

        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) ?? fallback
    }

    static func makeRGBAImage(from rgba: [UInt8], width: Int, height: Int) -> CGImage {
        let data = Data(rgba)
        let provider = CGDataProvider(data: data as CFData)

        let fallback = CGImage(
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: CGDataProvider(data: Data([0, 0, 0, 0]) as CFData)!,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!

        guard let provider else { return fallback }

        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) ?? fallback
    }
}

/// Result of building per-stroke reveal regions, including a debug image
/// of glyph pixels not claimed by any stroke envelope.
struct StrokeRevealResult {
    let regions: [StrokeRevealRegion]
    /// Glyph pixels that no stroke envelope covers. nil when every pixel is claimed.
    let unclaimedImage: CGImage?
    let debugArtifacts: StrokeRevealDebugArtifacts?
}

struct StrokeRevealDebugArtifacts {
    let ownedImages: [CGImage]
    let progressHeatmaps: [CGImage]
    let ownershipBoundaryImage: CGImage?
    let disputedPixelsImage: CGImage?
}

/// Builds per-stroke, glyph-clipped ownership regions used to prevent reveal bleed.
/// Regions are rasterized once and cached by character+size+stroke signature.
final class StrokeRegionBuilder {
    static let shared = StrokeRegionBuilder()

    private struct CacheKey: Hashable {
        let characterKey: String
        let width: Int
        let height: Int
        let strokeSignature: Int
        let debugSignature: Int
    }

    private var cache: [CacheKey: StrokeRevealResult] = [:]
    private let maxCacheEntries = 32

    private init() {}

    func regions(
        characterKey: String,
        glyphPath: CGPath,
        strokes: [RecordedStroke],
        canvasSize: CGSize,
        glyphStrokeWidth: CGFloat,
        recordingGlyphScale: Double
    ) -> StrokeRevealResult {
        let width = max(Int(canvasSize.width.rounded(.up)), 1)
        let height = max(Int(canvasSize.height.rounded(.up)), 1)

        let key = CacheKey(
            characterKey: characterKey,
            width: width,
            height: height,
            strokeSignature: strokeSignature(
                from: strokes,
                glyphStrokeWidth: glyphStrokeWidth,
                recordingGlyphScale: recordingGlyphScale
            ),
            debugSignature: debugEnabled(for: characterKey) ? 1 : 0
        )

        if let cached = cache[key] {
            return cached
        }

        let built = buildRegions(
            characterKey: characterKey,
            glyphPath: glyphPath,
            strokes: strokes,
            canvasSize: canvasSize,
            width: width,
            height: height,
            glyphStrokeWidth: glyphStrokeWidth,
            recordingGlyphScale: recordingGlyphScale
        )

        cache[key] = built
        if cache.count > maxCacheEntries, let keyToRemove = cache.keys.first {
            cache.removeValue(forKey: keyToRemove)
        }

        return built
    }

    private func buildRegions(
        characterKey: String,
        glyphPath: CGPath,
        strokes: [RecordedStroke],
        canvasSize: CGSize,
        width: Int,
        height: Int,
        glyphStrokeWidth: CGFloat,
        recordingGlyphScale: Double
    ) -> StrokeRevealResult {
        let glyphMask = rasterizeMask(for: glyphPath, width: width, height: height)
        let pixelCount = width * height
        var candidates: [StrokeCandidate] = []
        candidates.reserveCapacity(strokes.count)

        for stroke in strokes {
            let remapped = remap(points: stroke.points, recordingGlyphScale: recordingGlyphScale)
            let smoothedCGPath = StrokeSmoother.smoothCGPath(from: remapped, canvasSize: canvasSize)
            let smoothedPath = Path(smoothedCGPath)

            let penWidth = CGFloat(stroke.penWidth) * canvasSize.width
            let envelopeWidth: CGFloat
            if strokes.count == 1 {
                // Single stroke owns every glyph pixel — use bounding box diagonal
                let bounds = glyphPath.boundingBoxOfPath
                envelopeWidth = hypot(bounds.width, bounds.height)
            } else {
                envelopeWidth = StrokeMaskConfig.envelopeWidth(
                    penWidth: penWidth,
                    canvasWidth: canvasSize.width,
                    glyphStrokeWidth: glyphStrokeWidth
                )
            }

            let envelope = smoothedCGPath.copy(
                strokingWithWidth: envelopeWidth,
                lineCap: .round,
                lineJoin: .round,
                miterLimit: 10
            )
            let envelopeMask = rasterizeMask(for: envelope, width: width, height: height)
            let centerlineWidth = coreOwnershipWidth(
                penWidth: penWidth,
                glyphStrokeWidth: glyphStrokeWidth,
                envelopeWidth: envelopeWidth,
                canvasWidth: canvasSize.width
            )
            let centerlineCore = smoothedCGPath.copy(
                strokingWithWidth: centerlineWidth,
                lineCap: .round,
                lineJoin: .round,
                miterLimit: 10
            )
            let centerlineMask = rasterizeMask(for: centerlineCore, width: width, height: height)
            let (segments, totalLength) = buildPathSegments(from: smoothedCGPath)

            candidates.append(
                StrokeCandidate(
                    smoothedPath: smoothedPath,
                    envelopeMask: envelopeMask,
                    centerlineMask: centerlineMask,
                    envelopeWidth: envelopeWidth,
                    segments: segments,
                    totalLength: totalLength
                )
            )
        }

        var claimedMask = [UInt8](repeating: 0, count: pixelCount)
        var ownedMasks = Array(
            repeating: [UInt8](repeating: 0, count: pixelCount),
            count: candidates.count
        )
        var ownerIndexes = [Int16](repeating: -1, count: pixelCount)
        var disputedMask = [UInt8](repeating: 0, count: pixelCount)
        var claimers: [Int] = []
        claimers.reserveCapacity(candidates.count)

        for pixelIndex in 0..<pixelCount {
            guard glyphMask[pixelIndex] > 127 else { continue }

            claimers.removeAll(keepingCapacity: true)
            for candidateIndex in candidates.indices {
                if candidates[candidateIndex].envelopeMask[pixelIndex] > 127 {
                    claimers.append(candidateIndex)
                }
            }

            guard !claimers.isEmpty else { continue }

            let ownerIndex: Int
            if claimers.count == 1 {
                ownerIndex = claimers[0]
            } else {
                disputedMask[pixelIndex] = 255
                let x = pixelIndex % width
                let y = pixelIndex / width
                let point = CGPoint(x: CGFloat(x) + 0.5, y: CGFloat(y) + 0.5)
                ownerIndex = nearestStrokeIndex(
                    for: point,
                    claimers: claimers,
                    candidates: candidates
                )
            }

            ownedMasks[ownerIndex][pixelIndex] = 255
            claimedMask[pixelIndex] = 255
            ownerIndexes[pixelIndex] = Int16(ownerIndex)
        }

        // Preserve a thin centerline core for each stroke to prevent temporary
        // junction voids when Voronoi ownership boundaries cut through crossings.
        for strokeIndex in candidates.indices {
            let centerlineMask = candidates[strokeIndex].centerlineMask
            for pixelIndex in 0..<pixelCount where glyphMask[pixelIndex] > 127 && centerlineMask[pixelIndex] > 127 {
                ownedMasks[strokeIndex][pixelIndex] = 255
                claimedMask[pixelIndex] = 255
                if ownerIndexes[pixelIndex] < 0 {
                    ownerIndexes[pixelIndex] = Int16(strokeIndex)
                }
            }
        }

        var regions: [StrokeRevealRegion] = []
        var progressMaps: [[UInt16]] = []
        regions.reserveCapacity(candidates.count)
        progressMaps.reserveCapacity(candidates.count)
        for index in candidates.indices {
            let progressMap = buildProgressMap(
                ownedMask: ownedMasks[index],
                width: width,
                height: height,
                centerlineMask: candidates[index].centerlineMask,
                segments: candidates[index].segments,
                totalLength: candidates[index].totalLength
            )
            progressMaps.append(progressMap)

            regions.append(
                StrokeRevealRegion(
                    smoothedPath: candidates[index].smoothedPath,
                    progressMap: progressMap,
                    ownedMask: ownedMasks[index],
                    width: width,
                    height: height
                )
            )
        }

        // Build unclaimed-pixel debug image: glyph pixels no envelope reached
        var unclaimedMask = [UInt8](repeating: 0, count: width * height)
        var unclaimedCount = 0
        for i in 0..<glyphMask.count {
            if glyphMask[i] > 127 && claimedMask[i] == 0 {
                unclaimedMask[i] = 255
                unclaimedCount += 1
            }
        }
        let unclaimedImage = unclaimedCount > 0
            ? StrokeRevealRegion.makeAlphaImage(from: unclaimedMask, width: width, height: height)
            : nil

        let debugArtifacts = makeDebugArtifactsIfNeeded(
            characterKey: characterKey,
            width: width,
            height: height,
            ownedMasks: ownedMasks,
            progressMaps: progressMaps,
            ownerIndexes: ownerIndexes,
            disputedMask: disputedMask,
            unclaimedMask: unclaimedMask,
            unclaimedCount: unclaimedCount
        )

        return StrokeRevealResult(
            regions: regions,
            unclaimedImage: unclaimedImage,
            debugArtifacts: debugArtifacts
        )
    }

    private struct PathSegment {
        let start: CGPoint
        let deltaX: CGFloat
        let deltaY: CGFloat
        let length: CGFloat
        let lengthSquared: CGFloat
        let cumulativeStart: CGFloat
    }

    private struct StrokeCandidate {
        let smoothedPath: Path
        let envelopeMask: [UInt8]
        let centerlineMask: [UInt8]
        let envelopeWidth: CGFloat
        let segments: [PathSegment]
        let totalLength: CGFloat
    }

    private func buildProgressMap(
        ownedMask: [UInt8],
        width: Int,
        height: Int,
        centerlineMask: [UInt8],
        segments: [PathSegment],
        totalLength: CGFloat
    ) -> [UInt16] {
        let pixelCount = width * height
        var progressMap = [UInt16](repeating: UInt16.max, count: pixelCount)
        let invalidProgress = CGFloat(-1)

        if segments.isEmpty || totalLength <= .ulpOfOne {
            for index in 0..<ownedMask.count where ownedMask[index] > 127 {
                progressMap[index] = 0
            }
            return progressMap
        }

        var progressValues = [CGFloat](repeating: invalidProgress, count: pixelCount)
        var tieMask = [UInt8](repeating: 0, count: pixelCount)
        var hasTies = false

        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                guard ownedMask[index] > 127 else { continue }

                let point = CGPoint(x: CGFloat(x) + 0.5, y: CGFloat(y) + 0.5)
                let projection = nearestProjection(of: point, onto: segments)
                let progress = projection.arcLength / totalLength

                let clamped = min(max(progress, 0), 1)
                progressValues[index] = clamped
                if projection.tieCount > 1 {
                    tieMask[index] = 255
                    hasTies = true
                }
            }
        }

        if hasTies {
            applyLocalizedSmoothing(
                progressValues: &progressValues,
                tieMask: tieMask,
                ownedMask: ownedMask,
                centerlineMask: centerlineMask,
                width: width,
                height: height
            )
        }

        let maxValue = CGFloat(UInt16.max - 1)
        for index in 0..<progressValues.count where progressValues[index] >= 0 {
            progressMap[index] = UInt16((progressValues[index] * maxValue).rounded(.toNearestOrEven))
        }

        return progressMap
    }

    private func applyLocalizedSmoothing(
        progressValues: inout [CGFloat],
        tieMask: [UInt8],
        ownedMask: [UInt8],
        centerlineMask: [UInt8],
        width: Int,
        height: Int
    ) {
        let smoothingMask = dilatedTieMask(
            tieMask: tieMask,
            ownedMask: ownedMask,
            width: width,
            height: height,
            radius: 2
        )
        guard smoothingMask.contains(where: { $0 > 127 }) else { return }

        let kernel: [(dx: Int, dy: Int, weight: CGFloat)] = [
            (0, 0, 4),
            (-1, 0, 2), (1, 0, 2), (0, -1, 2), (0, 1, 2),
            (-1, -1, 1), (1, -1, 1), (-1, 1, 1), (1, 1, 1)
        ]
        var current = progressValues

        for _ in 0..<2 {
            var next = current

            for y in 0..<height {
                for x in 0..<width {
                    let index = y * width + x
                    guard smoothingMask[index] > 127 else { continue }
                    guard ownedMask[index] > 127 else { continue }
                    // Keep the centerline timing stable; smooth only off-center ambiguity.
                    guard centerlineMask[index] <= 127 else { continue }

                    var weightedSum: CGFloat = 0
                    var weightTotal: CGFloat = 0
                    var neighborMin: CGFloat = 1
                    var neighborMax: CGFloat = 0
                    var hasNeighbor = false

                    for entry in kernel {
                        let nx = x + entry.dx
                        let ny = y + entry.dy
                        guard nx >= 0, nx < width, ny >= 0, ny < height else { continue }
                        let neighborIndex = ny * width + nx
                        guard ownedMask[neighborIndex] > 127 else { continue }
                        let neighborProgress = current[neighborIndex]
                        guard neighborProgress >= 0 else { continue }

                        weightedSum += neighborProgress * entry.weight
                        weightTotal += entry.weight
                        neighborMin = min(neighborMin, neighborProgress)
                        neighborMax = max(neighborMax, neighborProgress)
                        hasNeighbor = true
                    }

                    guard hasNeighbor, weightTotal > .ulpOfOne else { continue }
                    let smoothed = weightedSum / weightTotal
                    next[index] = min(max(smoothed, neighborMin), neighborMax)
                }
            }

            current = next
        }

        progressValues = current
    }

    private func dilatedTieMask(
        tieMask: [UInt8],
        ownedMask: [UInt8],
        width: Int,
        height: Int,
        radius: Int
    ) -> [UInt8] {
        guard radius > 0 else { return tieMask }
        var current = tieMask

        for _ in 0..<radius {
            var next = current

            for y in 0..<height {
                for x in 0..<width {
                    let index = y * width + x
                    guard current[index] > 127 else { continue }

                    for dy in -1...1 {
                        for dx in -1...1 {
                            let nx = x + dx
                            let ny = y + dy
                            guard nx >= 0, nx < width, ny >= 0, ny < height else { continue }
                            let neighborIndex = ny * width + nx
                            guard ownedMask[neighborIndex] > 127 else { continue }
                            next[neighborIndex] = 255
                        }
                    }
                }
            }

            current = next
        }

        return current
    }

    /// Minimum spacing between projection segment endpoints. The dense curve
    /// sampling (48 steps per cubic) is needed for smooth rendering but is
    /// ~50x redundant for nearest-point projection, where error is bounded by
    /// segment length. Decimating keeps progress maps accurate to ~2pt while
    /// cutting the per-pixel projection cost by the same factor.
    private static let projectionSegmentSpacing: CGFloat = 2.0

    private func buildPathSegments(from path: CGPath) -> ([PathSegment], CGFloat) {
        let points = Self.decimate(sampledPoints(from: path), minSpacing: Self.projectionSegmentSpacing)
        guard points.count > 1 else { return ([], 0) }

        var segments: [PathSegment] = []
        var cumulative: CGFloat = 0

        for i in 0..<(points.count - 1) {
            let start = points[i]
            let end = points[i + 1]
            let deltaX = end.x - start.x
            let deltaY = end.y - start.y
            let lengthSquared = deltaX * deltaX + deltaY * deltaY
            guard lengthSquared > .ulpOfOne else { continue }
            let length = sqrt(lengthSquared)

            segments.append(
                PathSegment(
                    start: start,
                    deltaX: deltaX,
                    deltaY: deltaY,
                    length: length,
                    lengthSquared: lengthSquared,
                    cumulativeStart: cumulative
                )
            )
            cumulative += length
        }

        return (segments, cumulative)
    }

    /// Drops points closer than `minSpacing` to the previously kept point,
    /// always preserving the exact final point so arc endpoints stay stable.
    static func decimate(_ points: [CGPoint], minSpacing: CGFloat) -> [CGPoint] {
        guard points.count > 2 else { return points }

        var kept: [CGPoint] = [points[0]]
        for point in points.dropFirst() {
            let last = kept[kept.count - 1]
            if hypot(point.x - last.x, point.y - last.y) >= minSpacing {
                kept.append(point)
            }
        }

        if let final = points.last, let lastKept = kept.last,
           final.x != lastKept.x || final.y != lastKept.y {
            kept.append(final)
        }

        return kept
    }

    private func sampledPoints(from path: CGPath) -> [CGPoint] {
        let cubicSteps = 48
        let quadSteps = 28

        var points: [CGPoint] = []
        var currentPoint = CGPoint.zero
        var movePoint = CGPoint.zero

        path.applyWithBlock { elementPointer in
            processPathElement(
                elementPointer.pointee,
                currentPoint: &currentPoint,
                movePoint: &movePoint,
                points: &points,
                quadSteps: quadSteps,
                cubicSteps: cubicSteps
            )
        }

        var deduplicated: [CGPoint] = []
        deduplicated.reserveCapacity(points.count)
        for point in points {
            guard let last = deduplicated.last else {
                deduplicated.append(point)
                continue
            }

            if hypot(point.x - last.x, point.y - last.y) > 0.001 {
                deduplicated.append(point)
            }
        }

        return deduplicated
    }

    private func processPathElement(
        _ element: CGPathElement,
        currentPoint: inout CGPoint,
        movePoint: inout CGPoint,
        points: inout [CGPoint],
        quadSteps: Int,
        cubicSteps: Int
    ) {
        switch element.type {
        case .moveToPoint:
            let point = element.points[0]
            points.append(point)
            currentPoint = point
            movePoint = point

        case .addLineToPoint:
            let point = element.points[0]
            points.append(point)
            currentPoint = point

        case .addQuadCurveToPoint:
            let control = element.points[0]
            let end = element.points[1]
            for step in 1...quadSteps {
                let t = CGFloat(step) / CGFloat(quadSteps)
                points.append(quadPoint(start: currentPoint, control: control, end: end, t: t))
            }
            currentPoint = end

        case .addCurveToPoint:
            let control1 = element.points[0]
            let control2 = element.points[1]
            let end = element.points[2]
            for step in 1...cubicSteps {
                let t = CGFloat(step) / CGFloat(cubicSteps)
                points.append(cubicPoint(start: currentPoint, control1: control1, control2: control2, end: end, t: t))
            }
            currentPoint = end

        case .closeSubpath:
            points.append(movePoint)
            currentPoint = movePoint

        @unknown default:
            break
        }
    }

    private func quadPoint(start: CGPoint, control: CGPoint, end: CGPoint, t: CGFloat) -> CGPoint {
        let oneMinusT = 1 - t
        return CGPoint(
            x: oneMinusT * oneMinusT * start.x + 2 * oneMinusT * t * control.x + t * t * end.x,
            y: oneMinusT * oneMinusT * start.y + 2 * oneMinusT * t * control.y + t * t * end.y
        )
    }

    private func cubicPoint(
        start: CGPoint,
        control1: CGPoint,
        control2: CGPoint,
        end: CGPoint,
        t: CGFloat
    ) -> CGPoint {
        let oneMinusT = 1 - t
        let oneMinusTSquared = oneMinusT * oneMinusT
        let tSquared = t * t

        return CGPoint(
            x: oneMinusTSquared * oneMinusT * start.x
                + 3 * oneMinusTSquared * t * control1.x
                + 3 * oneMinusT * tSquared * control2.x
                + tSquared * t * end.x,
            y: oneMinusTSquared * oneMinusT * start.y
                + 3 * oneMinusTSquared * t * control1.y
                + 3 * oneMinusT * tSquared * control2.y
                + tSquared * t * end.y
        )
    }

    private func coreOwnershipWidth(
        penWidth: CGFloat,
        glyphStrokeWidth: CGFloat,
        envelopeWidth: CGFloat,
        canvasWidth: CGFloat
    ) -> CGFloat {
        let penBased = penWidth * 1.35
        let glyphBased = glyphStrokeWidth > 0 ? glyphStrokeWidth * 1.25 : canvasWidth * 0.03
        let base = max(penBased, glyphBased)
        let minWidth = canvasWidth * 0.02
        let clamped = max(base, minWidth)
        return min(clamped, envelopeWidth)
    }

    private func makeDebugArtifactsIfNeeded(
        characterKey: String,
        width: Int,
        height: Int,
        ownedMasks: [[UInt8]],
        progressMaps: [[UInt16]],
        ownerIndexes: [Int16],
        disputedMask: [UInt8],
        unclaimedMask: [UInt8],
        unclaimedCount: Int
    ) -> StrokeRevealDebugArtifacts? {
        guard debugEnabled(for: characterKey) else { return nil }

        let ownedImages = ownedMasks.enumerated().map { index, mask in
            makeTintedMaskImage(
                from: mask,
                width: width,
                height: height,
                color: paletteColor(for: index),
                alpha: 220
            )
        }

        let heatmaps = zip(progressMaps, ownedMasks).map { progressMap, ownedMask in
            makeProgressHeatmapImage(
                progressMap: progressMap,
                ownedMask: ownedMask,
                width: width,
                height: height
            )
        }

        let boundaryImage = makeOwnershipBoundaryImage(
            ownerIndexes: ownerIndexes,
            width: width,
            height: height
        )
        let disputedImage = makeTintedMaskImage(
            from: disputedMask,
            width: width,
            height: height,
            color: (255, 140, 0),
            alpha: 220
        )

        if debugHasFlag("-stroke-debug-export") {
            exportDebugImages(
                characterKey: characterKey,
                width: width,
                height: height,
                ownedImages: ownedImages,
                heatmaps: heatmaps,
                boundaryImage: boundaryImage,
                disputedImage: disputedImage,
                unclaimedMask: unclaimedMask,
                unclaimedCount: unclaimedCount
            )
        }

        return StrokeRevealDebugArtifacts(
            ownedImages: ownedImages,
            progressHeatmaps: heatmaps,
            ownershipBoundaryImage: boundaryImage,
            disputedPixelsImage: disputedImage
        )
    }

    private func makeOwnershipBoundaryImage(
        ownerIndexes: [Int16],
        width: Int,
        height: Int
    ) -> CGImage? {
        var boundaryMask = [UInt8](repeating: 0, count: width * height)
        var hasBoundary = false

        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                let owner = ownerIndexes[index]
                guard owner >= 0 else { continue }

                if x + 1 < width {
                    let right = ownerIndexes[index + 1]
                    if right >= 0 && right != owner {
                        boundaryMask[index] = 255
                        boundaryMask[index + 1] = 255
                        hasBoundary = true
                    }
                }

                if y + 1 < height {
                    let down = ownerIndexes[index + width]
                    if down >= 0 && down != owner {
                        boundaryMask[index] = 255
                        boundaryMask[index + width] = 255
                        hasBoundary = true
                    }
                }
            }
        }

        guard hasBoundary else { return nil }
        return makeTintedMaskImage(
            from: boundaryMask,
            width: width,
            height: height,
            color: (255, 0, 0),
            alpha: 255
        )
    }

    private func makeProgressHeatmapImage(
        progressMap: [UInt16],
        ownedMask: [UInt8],
        width: Int,
        height: Int
    ) -> CGImage {
        let denominator = CGFloat(UInt16.max - 1)
        var rgba = [UInt8](repeating: 0, count: width * height * 4)

        for index in 0..<ownedMask.count where ownedMask[index] > 127 {
            let value = progressMap[index]
            guard value < UInt16.max else { continue }
            let progress = CGFloat(value) / denominator
            let color = heatColor(for: progress)
            let offset = index * 4
            rgba[offset] = color.r
            rgba[offset + 1] = color.g
            rgba[offset + 2] = color.b
            rgba[offset + 3] = 230
        }

        return StrokeRevealRegion.makeRGBAImage(from: rgba, width: width, height: height)
    }

    private func heatColor(for progress: CGFloat) -> (r: UInt8, g: UInt8, b: UInt8) {
        let clamped = min(max(progress, 0), 1)
        if clamped < 0.33 {
            let t = clamped / 0.33
            return (
                r: UInt8((20 + t * 20).rounded(.toNearestOrEven)),
                g: UInt8((60 + t * 170).rounded(.toNearestOrEven)),
                b: UInt8((255 - t * 70).rounded(.toNearestOrEven))
            )
        } else if clamped < 0.66 {
            let t = (clamped - 0.33) / 0.33
            return (
                r: UInt8((40 + t * 215).rounded(.toNearestOrEven)),
                g: UInt8((230 - t * 40).rounded(.toNearestOrEven)),
                b: UInt8((185 - t * 185).rounded(.toNearestOrEven))
            )
        } else {
            let t = (clamped - 0.66) / 0.34
            return (
                r: 255,
                g: UInt8((190 - t * 150).rounded(.toNearestOrEven)),
                b: UInt8((0 + t * 40).rounded(.toNearestOrEven))
            )
        }
    }

    private func makeTintedMaskImage(
        from mask: [UInt8],
        width: Int,
        height: Int,
        color: (UInt8, UInt8, UInt8),
        alpha: UInt8
    ) -> CGImage {
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        for index in 0..<mask.count where mask[index] > 127 {
            let offset = index * 4
            rgba[offset] = color.0
            rgba[offset + 1] = color.1
            rgba[offset + 2] = color.2
            rgba[offset + 3] = alpha
        }
        return StrokeRevealRegion.makeRGBAImage(from: rgba, width: width, height: height)
    }

    private func paletteColor(for index: Int) -> (UInt8, UInt8, UInt8) {
        let colors: [(UInt8, UInt8, UInt8)] = [
            (66, 93, 255),
            (255, 102, 64),
            (64, 182, 120),
            (233, 184, 34),
            (149, 77, 255),
            (0, 170, 210)
        ]
        return colors[index % colors.count]
    }

    private func exportDebugImages(
        characterKey: String,
        width: Int,
        height: Int,
        ownedImages: [CGImage],
        heatmaps: [CGImage],
        boundaryImage: CGImage?,
        disputedImage: CGImage?,
        unclaimedMask: [UInt8],
        unclaimedCount: Int
    ) {
        let tmpDir = FileManager.default.temporaryDirectory
        let baseDir = tmpDir
            .appendingPathComponent("stroke-debug", isDirectory: true)
            .appendingPathComponent(safePathComponent(characterKey), isDirectory: true)

        do {
            try FileManager.default.createDirectory(
                at: baseDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            print("[StrokeDebug] Failed to create directory \(baseDir.path): \(error.localizedDescription)")
            return
        }

        for (index, image) in ownedImages.enumerated() {
            writePNG(image, to: baseDir.appendingPathComponent("owned-stroke-\(index + 1).png"))
        }

        for (index, image) in heatmaps.enumerated() {
            writePNG(image, to: baseDir.appendingPathComponent("progress-heatmap-stroke-\(index + 1).png"))
        }

        if let boundaryImage {
            writePNG(boundaryImage, to: baseDir.appendingPathComponent("ownership-boundary.png"))
        }

        if let disputedImage {
            writePNG(disputedImage, to: baseDir.appendingPathComponent("disputed-pixels.png"))
        }

        if unclaimedCount > 0 {
            let unclaimedImage = makeTintedMaskImage(
                from: unclaimedMask,
                width: width,
                height: height,
                color: (255, 230, 40),
                alpha: 255
            )
            writePNG(unclaimedImage, to: baseDir.appendingPathComponent("unclaimed-pixels.png"))
        }

        print("[StrokeDebug] Exported artifacts for \(characterKey) at \(baseDir.path)")
    }

    private func writePNG(_ image: CGImage, to url: URL) {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            return
        }

        CGImageDestinationAddImage(destination, image, nil)
        if !CGImageDestinationFinalize(destination) {
            print("[StrokeDebug] Failed writing \(url.path)")
        }
    }

    private func safePathComponent(_ value: String) -> String {
        value.map { character in
            switch character {
            case "a"..."z", "A"..."Z", "0"..."9", "-", "_":
                return character
            default:
                return "_"
            }
        }.reduce(into: "") { partialResult, character in
            partialResult.append(character)
        }
    }

    private func debugEnabled(for characterKey: String) -> Bool {
        guard debugHasFlag("-stroke-debug") else { return false }
        guard let filter = debugValue(for: "-stroke-debug-character"), !filter.isEmpty else {
            return true
        }
        return filter == characterKey
    }

    private func debugHasFlag(_ flag: String) -> Bool {
        ProcessInfo.processInfo.arguments.contains(flag)
    }

    private func debugValue(for flag: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: flag), index + 1 < args.count else {
            return nil
        }
        return args[index + 1]
    }

    private func nearestStrokeIndex(
        for point: CGPoint,
        claimers: [Int],
        candidates: [StrokeCandidate]
    ) -> Int {
        guard let first = claimers.first else { return 0 }
        var bestIndex = first
        var bestMetric = ownershipDistanceMetric(
            from: point,
            segments: candidates[first].segments,
            envelopeWidth: candidates[first].envelopeWidth
        )

        for index in claimers.dropFirst() {
            let metric = ownershipDistanceMetric(
                from: point,
                segments: candidates[index].segments,
                envelopeWidth: candidates[index].envelopeWidth
            )
            if metric + 0.0001 < bestMetric {
                bestMetric = metric
                bestIndex = index
            } else if abs(metric - bestMetric) <= 0.0001 {
                if candidates[index].envelopeWidth > candidates[bestIndex].envelopeWidth {
                    bestIndex = index
                }
            }
        }

        return bestIndex
    }

    private func ownershipDistanceMetric(
        from point: CGPoint,
        segments: [PathSegment],
        envelopeWidth: CGFloat
    ) -> CGFloat {
        let normalizedDenominator = max(envelopeWidth * envelopeWidth, 1)
        return nearestProjection(of: point, onto: segments).distanceSquared / normalizedDenominator
    }

    private struct ProjectionResult {
        let distanceSquared: CGFloat
        let arcLength: CGFloat
        let tieCount: Int
    }

    private func nearestProjection(
        of point: CGPoint,
        onto segments: [PathSegment]
    ) -> ProjectionResult {
        var bestDistanceSquared = CGFloat.greatestFiniteMagnitude
        var tieCandidates: [(distanceSquared: CGFloat, arcLength: CGFloat)] = []
        tieCandidates.reserveCapacity(4)
        let tieToleranceSquared: CGFloat = 0.35

        for segment in segments {
            let relativeX = point.x - segment.start.x
            let relativeY = point.y - segment.start.y
            let projection = (relativeX * segment.deltaX + relativeY * segment.deltaY) / segment.lengthSquared
            let t = min(max(projection, 0), 1)

            let projectedX = segment.start.x + t * segment.deltaX
            let projectedY = segment.start.y + t * segment.deltaY
            let dx = point.x - projectedX
            let dy = point.y - projectedY
            let distanceSquared = dx * dx + dy * dy
            let arcLength = segment.cumulativeStart + t * segment.length

            if distanceSquared + tieToleranceSquared < bestDistanceSquared {
                bestDistanceSquared = distanceSquared
                tieCandidates.removeAll(keepingCapacity: true)
                tieCandidates.append((distanceSquared: distanceSquared, arcLength: arcLength))
            } else if abs(distanceSquared - bestDistanceSquared) <= tieToleranceSquared {
                tieCandidates.append((distanceSquared: distanceSquared, arcLength: arcLength))
            }
        }

        guard let first = tieCandidates.first else {
            return ProjectionResult(distanceSquared: .greatestFiniteMagnitude, arcLength: 0, tieCount: 0)
        }

        if tieCandidates.count == 1 {
            return ProjectionResult(distanceSquared: first.distanceSquared, arcLength: first.arcLength, tieCount: 1)
        }

        let epsilon: CGFloat = 0.0001
        var weightedArc: CGFloat = 0
        var totalWeight: CGFloat = 0
        var minArc = CGFloat.greatestFiniteMagnitude
        var maxArc: CGFloat = 0

        for candidate in tieCandidates {
            let relativeDistance = max(candidate.distanceSquared - bestDistanceSquared, 0)
            let weight = 1 / (relativeDistance + epsilon)
            weightedArc += candidate.arcLength * weight
            totalWeight += weight
            minArc = min(minArc, candidate.arcLength)
            maxArc = max(maxArc, candidate.arcLength)
        }

        let blendedArc = totalWeight > .ulpOfOne
            ? weightedArc / totalWeight
            : tieCandidates.reduce(0) { partialResult, candidate in
                partialResult + candidate.arcLength
            } / CGFloat(tieCandidates.count)
        let clampedArc = min(max(blendedArc, minArc), maxArc)

        return ProjectionResult(
            distanceSquared: bestDistanceSquared,
            arcLength: clampedArc,
            tieCount: tieCandidates.count
        )
    }

    private func remap(points: [StrokePoint], recordingGlyphScale: Double) -> [StrokePoint] {
        let offset = (1.0 - recordingGlyphScale) / 2.0
        return points.map { point in
            StrokePoint(
                x: (point.x - offset) / recordingGlyphScale,
                y: (point.y - offset) / recordingGlyphScale
            )
        }
    }

    private func strokeSignature(
        from strokes: [RecordedStroke],
        glyphStrokeWidth: CGFloat,
        recordingGlyphScale: Double
    ) -> Int {
        var hasher = Hasher()
        hasher.combine(strokes.count)
        hasher.combine(Int(glyphStrokeWidth.rounded()))
        hasher.combine(Int((recordingGlyphScale * 10_000).rounded()))

        for stroke in strokes {
            hasher.combine(stroke.points.count)
            hasher.combine(Int((stroke.penWidth * 10_000).rounded()))

            if let first = stroke.points.first {
                hasher.combine(Int((first.x * 10_000).rounded()))
                hasher.combine(Int((first.y * 10_000).rounded()))
            }

            if let last = stroke.points.last {
                hasher.combine(Int((last.x * 10_000).rounded()))
                hasher.combine(Int((last.y * 10_000).rounded()))
            }
        }

        return hasher.finalize()
    }

    private func rasterizeMask(for path: CGPath, width: Int, height: Int) -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: width * height)

        pixels.withUnsafeMutableBytes { buffer in
            guard
                let baseAddress = buffer.baseAddress,
                let context = CGContext(
                    data: baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width,
                    space: CGColorSpaceCreateDeviceGray(),
                    bitmapInfo: CGImageAlphaInfo.none.rawValue
                )
            else {
                return
            }

            context.setShouldAntialias(true)
            context.setAllowsAntialiasing(true)
            context.translateBy(x: 0, y: CGFloat(height))
            context.scaleBy(x: 1, y: -1)
            context.setFillColor(gray: 1, alpha: 1)
            context.addPath(path)
            context.fillPath()
        }

        return pixels
    }
}
