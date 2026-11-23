import CoreGraphics
import CoreText
import Foundation
import SwiftUI

/// Extracts vector paths from Unicode characters using CoreText.
/// Used to render Fidel character outlines for tracing practice.
final class PathExtractor {
    static let shared = PathExtractor()

    private var pathCache: [String: Path] = [:]
    private var cgPathCache: [String: CGPath] = [:]
    private var strokeWidthCache: [String: CGFloat] = [:]

    private init() {}

    /// Extract a SwiftUI Path for the given character, normalized to fit within `size`.
    func extractPath(for character: String, size: CGSize) -> Path {
        let key = "\(character)-\(Int(size.width))x\(Int(size.height))"
        if let cached = pathCache[key] {
            return cached
        }
        let cgPath = extractCGPath(for: character, size: size)
        let path = Path(cgPath)
        pathCache[key] = path
        return path
    }

    /// Extract a CGPath for the given character, normalized to fit within `size`.
    func extractCGPath(for character: String, size: CGSize) -> CGPath {
        let key = "\(character)-\(Int(size.width))x\(Int(size.height))"
        if let cached = cgPathCache[key] {
            return cached
        }

        let fontSize: CGFloat = 256

        // Use bundled Noto Sans Ethiopic — a sans-serif with uniform stroke width
        // and clean outlines, much better for tracing than the system Kefa (slab-serif).
        let ctFont = CTFontCreateWithName("NotoSansEthiopic-Regular" as CFString, fontSize, nil)

        // Get glyph for the character
        var chars = Array(character.utf16)
        var glyphs = [CGGlyph](repeating: 0, count: chars.count)
        guard CTFontGetGlyphsForCharacters(ctFont, &chars, &glyphs, chars.count),
            glyphs[0] != 0
        else {
            let empty = CGMutablePath()
            cgPathCache[key] = empty
            return empty
        }

        guard let rawPath = CTFontCreatePathForGlyph(ctFont, glyphs[0], nil) else {
            let empty = CGMutablePath()
            cgPathCache[key] = empty
            return empty
        }

        // Normalize the path to fit within the target size with padding
        let padding: CGFloat = 10
        let targetRect = CGRect(
            x: padding,
            y: padding,
            width: size.width - padding * 2,
            height: size.height - padding * 2
        )

        let boundingBox = rawPath.boundingBox
        guard !boundingBox.isEmpty, boundingBox.width > 0, boundingBox.height > 0 else {
            let empty = CGMutablePath()
            cgPathCache[key] = empty
            return empty
        }

        // Calculate scale to fit the glyph within the target rect (uniform scale)
        let scaleX = targetRect.width / boundingBox.width
        let scaleY = targetRect.height / boundingBox.height
        let scale = min(scaleX, scaleY)

        // Center the scaled glyph in the target rect
        let scaledWidth = boundingBox.width * scale
        let scaledHeight = boundingBox.height * scale
        let centerOffsetX = targetRect.minX + (targetRect.width - scaledWidth) / 2
        let centerOffsetY = targetRect.minY + (targetRect.height - scaledHeight) / 2

        // CoreText glyphs have Y-axis going up (origin at baseline, bottom-left).
        // SwiftUI has Y-axis going down. We flip by scaling Y by -1 and translating.
        var transform = CGAffineTransform.identity
        // Step 1: Move glyph origin to (0,0)
        transform = transform.translatedBy(x: -boundingBox.minX, y: -boundingBox.minY)
        // Step 2: Scale (with Y flip)
        transform = CGAffineTransform(scaleX: scale, y: -scale).concatenating(
            CGAffineTransform(translationX: 0, y: scaledHeight)
        ).concatenating(
            CGAffineTransform(translationX: centerOffsetX, y: centerOffsetY)
        ).concatenating(
            CGAffineTransform(translationX: -boundingBox.minX * scale, y: boundingBox.minY * scale)
        )

        // Simpler approach: translate to origin, scale with Y-flip, then position
        transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: centerOffsetX, y: centerOffsetY + scaledHeight)
        transform = transform.scaledBy(x: scale, y: -scale)
        transform = transform.translatedBy(x: -boundingBox.minX, y: -boundingBox.minY)

        guard let normalizedPath = rawPath.copy(using: &transform) else {
            let empty = CGMutablePath()
            cgPathCache[key] = empty
            return empty
        }

        cgPathCache[key] = normalizedPath
        return normalizedPath
    }

    // MARK: - Glyph Stroke Width Estimation

    /// Estimates the font's intrinsic stroke width for a character at the given size.
    /// Renders to a small bitmap, measures filled area vs. path perimeter, returns
    /// `area / (perimeter / 2)` as an estimate. Cached per character+size.
    func glyphStrokeWidth(for character: String, size: CGSize) -> CGFloat {
        let key = "\(character)-\(Int(size.width))x\(Int(size.height))"
        if let cached = strokeWidthCache[key] {
            return cached
        }

        let cgPath = extractCGPath(for: character, size: size)
        guard !cgPath.boundingBox.isEmpty else {
            strokeWidthCache[key] = 0
            return 0
        }

        // Render to a small bitmap to count filled pixels
        let bitmapSize = 64
        let scaleX = CGFloat(bitmapSize) / size.width
        let scaleY = CGFloat(bitmapSize) / size.height

        guard
            let ctx = CGContext(
                data: nil,
                width: bitmapSize,
                height: bitmapSize,
                bitsPerComponent: 8,
                bytesPerRow: bitmapSize,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            )
        else {
            strokeWidthCache[key] = 0
            return 0
        }

        ctx.setFillColor(gray: 1.0, alpha: 1.0)
        ctx.scaleBy(x: scaleX, y: scaleY)
        ctx.addPath(cgPath)
        ctx.fillPath()

        // Count filled pixels
        guard let data = ctx.data else {
            strokeWidthCache[key] = 0
            return 0
        }
        let pixels = data.bindMemory(to: UInt8.self, capacity: bitmapSize * bitmapSize)
        var filledCount = 0
        for i in 0..<(bitmapSize * bitmapSize) {
            if pixels[i] > 127 { filledCount += 1 }
        }

        // Convert pixel area back to original coordinate space
        let pixelArea = CGFloat(filledCount)
        let area = pixelArea / (scaleX * scaleY)

        // Sum path segment lengths (perimeter)
        let perimeter = Self.pathPerimeter(cgPath)

        guard perimeter > 0 else {
            strokeWidthCache[key] = 0
            return 0
        }

        let width = area / (perimeter / 2)
        strokeWidthCache[key] = width
        return width
    }

    /// Walks a CGPath's elements, approximating total perimeter length.
    /// Cubic bezier segments are sampled at 10 intervals for chord-length approximation.
    private static func pathPerimeter(_ path: CGPath) -> CGFloat {
        var length: CGFloat = 0
        var currentPoint = CGPoint.zero
        var movePoint = CGPoint.zero

        path.applyWithBlock { elementPtr in
            let element = elementPtr.pointee
            switch element.type {
            case .moveToPoint:
                currentPoint = element.points[0]
                movePoint = currentPoint

            case .addLineToPoint:
                let to = element.points[0]
                length += hypot(to.x - currentPoint.x, to.y - currentPoint.y)
                currentPoint = to

            case .addQuadCurveToPoint:
                let cp = element.points[0]
                let to = element.points[1]
                length += quadBezierLength(from: currentPoint, cp: cp, to: to)
                currentPoint = to

            case .addCurveToPoint:
                let cp1 = element.points[0]
                let cp2 = element.points[1]
                let to = element.points[2]
                length += cubicBezierLength(from: currentPoint, cp1: cp1, cp2: cp2, to: to)
                currentPoint = to

            case .closeSubpath:
                length += hypot(movePoint.x - currentPoint.x, movePoint.y - currentPoint.y)
                currentPoint = movePoint

            @unknown default:
                break
            }
        }
        return length
    }

    private static func cubicBezierLength(from p0: CGPoint, cp1: CGPoint, cp2: CGPoint, to p3: CGPoint) -> CGFloat {
        let steps = 10
        var length: CGFloat = 0
        var prev = p0
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let mt = 1 - t
            let x = mt * mt * mt * p0.x + 3 * mt * mt * t * cp1.x + 3 * mt * t * t * cp2.x + t * t * t * p3.x
            let y = mt * mt * mt * p0.y + 3 * mt * mt * t * cp1.y + 3 * mt * t * t * cp2.y + t * t * t * p3.y
            let pt = CGPoint(x: x, y: y)
            length += hypot(pt.x - prev.x, pt.y - prev.y)
            prev = pt
        }
        return length
    }

    private static func quadBezierLength(from p0: CGPoint, cp: CGPoint, to p2: CGPoint) -> CGFloat {
        let steps = 10
        var length: CGFloat = 0
        var prev = p0
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let mt = 1 - t
            let x = mt * mt * p0.x + 2 * mt * t * cp.x + t * t * p2.x
            let y = mt * mt * p0.y + 2 * mt * t * cp.y + t * t * p2.y
            let pt = CGPoint(x: x, y: y)
            length += hypot(pt.x - prev.x, pt.y - prev.y)
            prev = pt
        }
        return length
    }
}
