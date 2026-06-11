import CoreGraphics
import Foundation

/// Tunable constants for the guided trace interaction.
/// Centralized so forgiveness can be adjusted during QA without touching engine logic.
struct TraceTuning {
    /// Corridor radius = clamp(max(penWidth·canvasW, glyphStrokeWidth) × factor, min, maxRatio·canvasW).
    var corridorFactor: CGFloat = 2.4
    var minCorridorRadius: CGFloat = 26
    var maxCorridorRadiusRatio: CGFloat = 0.16
    /// Strokes shorter than this fraction of the canvas width get extra corridor forgiveness.
    var smallStrokeLengthRatio: CGFloat = 0.15
    var smallStrokeCorridorBoost: CGFloat = 1.3
    /// Touch must begin within corridorRadius × startRadiusFactor of the stroke start.
    var startRadiusFactor: CGFloat = 1.6
    /// Lift must land within corridorRadius × endRadiusFactor of the stroke end.
    var endRadiusFactor: CGFloat = 1.8
    /// Lifting at or beyond this progress completes the stroke.
    var completionProgress: CGFloat = 0.88
    var shortStrokeCompletionProgress: CGFloat = 0.78
    /// Strokes shorter than this (points) use the short-stroke completion threshold.
    var shortStrokeLength: CGFloat = 60
    /// Strokes shorter than this (points) complete on a single tap near them.
    var dotLengthThreshold: CGFloat = 18
    /// Fraction of total arc length tolerated when the finger slides backward.
    var backwardSlackFraction: CGFloat = 0.05
    /// Forward arc look-ahead = max(factor × corridorRadius, lengthFraction × totalLength).
    var forwardWindowFactor: CGFloat = 2.5
    var forwardWindowLengthFraction: CGFloat = 0.08
    /// Continuous time outside the corridor before a miss is registered.
    var deviationGrace: TimeInterval = 0.12
    var missesBeforeAutoHint: Int = 2
    /// Visual timings consumed by the canvas layer, not the engine.
    var rollbackDuration: TimeInterval = 0.25
    var hesitationHintDelay: TimeInterval = 4.0

    static let standard = TraceTuning()

    /// Slightly tighter corridor and later auto-hints for the faint-guide level.
    static func level2() -> TraceTuning {
        var tuning = TraceTuning()
        tuning.corridorFactor = 2.0
        tuning.missesBeforeAutoHint = 3
        return tuning
    }
}

/// Canvas-space, arc-length-parameterized stroke ready for trace validation.
struct TraceableStroke {
    let index: Int
    /// Smoothed and flattened centerline in canvas coordinates.
    let polyline: [CGPoint]
    /// cumulative[i] = arc length at polyline[i]; cumulative[0] == 0.
    let cumulative: [CGFloat]
    let totalLength: CGFloat
    let startPoint: CGPoint
    let endPoint: CGPoint
    let corridorRadius: CGFloat
    /// Marks (diacritics) shorter than the dot threshold complete on a tap.
    let isDot: Bool
}

/// Pure geometry for the guided trace engine: stroke flattening, windowed
/// nearest-point projection, and arc-length interpolation.
enum TraceGeometry {

    struct Projection {
        let arcLength: CGFloat
        let distance: CGFloat
        let point: CGPoint
    }

    /// Distance band within which projection candidates count as ties;
    /// ties prefer the larger arc so progress biases forward through self-crossings.
    private static let tieTolerance: CGFloat = 0.5

    // MARK: - Stroke preparation

    /// Remaps recorded points out of recording space, smooths them with the same
    /// Catmull-Rom spline used for rendering, flattens to a dense polyline, and
    /// precomputes cumulative arc lengths.
    static func traceableStrokes(
        from strokes: [RecordedStroke],
        canvasSize: CGSize,
        glyphStrokeWidth: CGFloat,
        recordingGlyphScale: Double,
        tuning: TraceTuning
    ) -> [TraceableStroke] {
        strokes.enumerated().compactMap { index, stroke in
            let remapped = remap(points: stroke.points, recordingGlyphScale: recordingGlyphScale)
            let smoothed = StrokeSmoother.smoothCGPath(from: remapped, canvasSize: canvasSize)
            let polyline = flattenedPoints(from: smoothed)
            guard let first = polyline.first else { return nil }

            var cumulative: [CGFloat] = [0]
            cumulative.reserveCapacity(polyline.count)
            for i in 1..<polyline.count {
                let previous = polyline[i - 1]
                let current = polyline[i]
                cumulative.append(cumulative[i - 1] + hypot(current.x - previous.x, current.y - previous.y))
            }
            let totalLength = cumulative.last ?? 0

            let penWidthPoints = CGFloat(stroke.penWidth) * canvasSize.width
            var corridorBase = max(penWidthPoints, glyphStrokeWidth) * tuning.corridorFactor
            if totalLength < tuning.smallStrokeLengthRatio * canvasSize.width {
                corridorBase *= tuning.smallStrokeCorridorBoost
            }
            let corridorRadius = min(
                max(corridorBase, tuning.minCorridorRadius),
                canvasSize.width * tuning.maxCorridorRadiusRatio
            )

            return TraceableStroke(
                index: index,
                polyline: polyline,
                cumulative: cumulative,
                totalLength: totalLength,
                startPoint: first,
                endPoint: polyline.last ?? first,
                corridorRadius: corridorRadius,
                isDot: totalLength < tuning.dotLengthThreshold
            )
        }
    }

    // MARK: - Projection

    /// Nearest projection of `point` onto the polyline restricted to the arc
    /// window [lowerArc, upperArc]. Long segments are clipped to the window so
    /// the returned arc never escapes it. Returns nil when the window selects
    /// no usable geometry.
    static func project(
        _ point: CGPoint,
        onto stroke: TraceableStroke,
        lowerArc: CGFloat,
        upperArc: CGFloat
    ) -> Projection? {
        guard stroke.polyline.count > 1 else { return nil }

        var best: Projection?
        var bestDistance = CGFloat.greatestFiniteMagnitude

        for i in 0..<(stroke.polyline.count - 1) {
            let arcStart = stroke.cumulative[i]
            let arcEnd = stroke.cumulative[i + 1]
            guard arcEnd >= lowerArc, arcStart <= upperArc else { continue }

            let length = arcEnd - arcStart
            guard length > .ulpOfOne else { continue }

            let tMin = max(0, (lowerArc - arcStart) / length)
            let tMax = min(1, (upperArc - arcStart) / length)
            guard tMin <= tMax else { continue }

            let a = stroke.polyline[i]
            let b = stroke.polyline[i + 1]
            let deltaX = b.x - a.x
            let deltaY = b.y - a.y
            let raw = ((point.x - a.x) * deltaX + (point.y - a.y) * deltaY) / (length * length)
            let t = min(max(raw, tMin), tMax)

            let projected = CGPoint(x: a.x + t * deltaX, y: a.y + t * deltaY)
            let distance = hypot(point.x - projected.x, point.y - projected.y)
            let arc = arcStart + t * length

            if distance < bestDistance - tieTolerance {
                best = Projection(arcLength: arc, distance: distance, point: projected)
                bestDistance = distance
            } else if distance <= bestDistance + tieTolerance {
                bestDistance = min(bestDistance, distance)
                if arc > (best?.arcLength ?? -.greatestFiniteMagnitude) {
                    best = Projection(arcLength: arc, distance: distance, point: projected)
                }
            }
        }

        return best
    }

    /// Point at arc length `arcLength` along the stroke (clamped to its range).
    static func point(at arcLength: CGFloat, on stroke: TraceableStroke) -> CGPoint {
        guard stroke.polyline.count > 1 else { return stroke.startPoint }
        let clamped = min(max(arcLength, 0), stroke.totalLength)

        for i in 1..<stroke.polyline.count where stroke.cumulative[i] >= clamped {
            let arcStart = stroke.cumulative[i - 1]
            let length = stroke.cumulative[i] - arcStart
            guard length > .ulpOfOne else { continue }
            let t = (clamped - arcStart) / length
            let a = stroke.polyline[i - 1]
            let b = stroke.polyline[i]
            return CGPoint(x: a.x + t * (b.x - a.x), y: a.y + t * (b.y - a.y))
        }

        return stroke.endPoint
    }

    /// Unit tangent at arc length `arcLength` (direction of the containing segment).
    static func tangent(at arcLength: CGFloat, on stroke: TraceableStroke) -> CGVector {
        guard stroke.polyline.count > 1 else { return CGVector(dx: 1, dy: 0) }
        let clamped = min(max(arcLength, 0), stroke.totalLength)

        var segmentIndex = stroke.polyline.count - 2
        for i in 1..<stroke.polyline.count where stroke.cumulative[i] >= clamped {
            segmentIndex = i - 1
            break
        }

        let a = stroke.polyline[segmentIndex]
        let b = stroke.polyline[segmentIndex + 1]
        let length = hypot(b.x - a.x, b.y - a.y)
        guard length > .ulpOfOne else { return CGVector(dx: 1, dy: 0) }
        return CGVector(dx: (b.x - a.x) / length, dy: (b.y - a.y) / length)
    }

    // MARK: - Flattening

    /// Flattens a smoothed stroke path to a polyline using the same sampling
    /// and decimation as StrokeRegionBuilder's projection segments (48 cubic /
    /// 28 quad steps, then ~2pt decimation) so trace progress aligns with the
    /// reveal masks at the same cost profile.
    private static func flattenedPoints(from path: CGPath) -> [CGPoint] {
        let cubicSteps = 48
        let quadSteps = 28

        var points: [CGPoint] = []
        var currentPoint = CGPoint.zero
        var movePoint = CGPoint.zero

        path.applyWithBlock { elementPointer in
            let element = elementPointer.pointee
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

        return StrokeRegionBuilder.decimate(deduplicated, minSpacing: 2.0)
    }

    private static func quadPoint(start: CGPoint, control: CGPoint, end: CGPoint, t: CGFloat) -> CGPoint {
        let oneMinusT = 1 - t
        return CGPoint(
            x: oneMinusT * oneMinusT * start.x + 2 * oneMinusT * t * control.x + t * t * end.x,
            y: oneMinusT * oneMinusT * start.y + 2 * oneMinusT * t * control.y + t * t * end.y
        )
    }

    private static func cubicPoint(
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

    private static func remap(points: [StrokePoint], recordingGlyphScale: Double) -> [StrokePoint] {
        guard abs(recordingGlyphScale - 1.0) > .ulpOfOne else { return points }
        let offset = (1.0 - recordingGlyphScale) / 2.0
        return points.map { point in
            StrokePoint(
                x: (point.x - offset) / recordingGlyphScale,
                y: (point.y - offset) / recordingGlyphScale
            )
        }
    }
}
