import CoreGraphics
import Foundation
import Observation

/// Gesture-driven state machine for guided stroke-by-stroke tracing.
///
/// The engine is fully synchronous: touch handlers receive explicit timestamps
/// and all timing-based visuals (rollback animation, snap pause, hint playback)
/// are owned by the view layer, which reports back via
/// `rollbackAnimationFinished()`, `strokeSnapFinished()`, and
/// `hintPlaybackFinished()`. This keeps every transition deterministic and
/// unit-testable.
@MainActor
@Observable
final class TraceEngine {

    enum StrokePhase: Equatable {
        /// Hint loop runs; a touch must land near the active stroke's start.
        case waitingForStart
        /// Finger down, advancing arc-length progress along the stroke.
        case tracing
        /// View animates the partial fill back to zero after a miss.
        case rollingBack
        /// View auto-demonstrates the active stroke after repeated misses.
        case playingHint
        /// Brief snap state before advancing to the next stroke.
        case strokeComplete
        /// All strokes traced.
        case characterComplete
    }

    enum EngineEvent: Equatable {
        case strokeStarted(index: Int)
        case strokeCompleted(index: Int)
        case miss(index: Int, count: Int)
        case hintAutoPlayed(index: Int)
        case characterCompleted(TraceAttemptStats)
    }

    struct TraceAttemptStats: Equatable {
        var misses: Int = 0
        var hintsAutoPlayed: Int = 0
        var duration: TimeInterval = 0
    }

    // MARK: - Rendering state

    private(set) var strokes: [TraceableStroke] = []
    private(set) var activeStrokeIndex = 0
    private(set) var phase: StrokePhase = .waitingForStart
    /// Active stroke fill 0...1, quantized to 1/128 steps so repeated frames
    /// hit StrokeRevealRegion's progress short-circuit.
    private(set) var displayProgress: CGFloat = 0
    /// Projected point under the finger while tracing.
    private(set) var fingerSnapPoint: CGPoint?
    private(set) var missCountForActiveStroke = 0
    private(set) var tuning: TraceTuning = .standard

    var onEvent: ((EngineEvent) -> Void)?

    var activeStroke: TraceableStroke? {
        strokes.indices.contains(activeStrokeIndex) ? strokes[activeStrokeIndex] : nil
    }

    // MARK: - Private state

    private static let quantizationSteps: CGFloat = 128

    private var currentArc: CGFloat = 0
    private var outsideSince: TimeInterval?
    private var totalMisses = 0
    private var totalHintsAutoPlayed = 0
    private var firstTouchTime: TimeInterval?
    private var lastTouchTime: TimeInterval = 0

    // MARK: - Configuration

    func configure(
        strokes: [RecordedStroke],
        canvasSize: CGSize,
        glyphStrokeWidth: CGFloat,
        recordingGlyphScale: Double,
        tuning: TraceTuning = .standard
    ) {
        self.tuning = tuning
        self.strokes = TraceGeometry.traceableStrokes(
            from: strokes,
            canvasSize: canvasSize,
            glyphStrokeWidth: glyphStrokeWidth,
            recordingGlyphScale: recordingGlyphScale,
            tuning: tuning
        )
        reset()
    }

    func reset() {
        activeStrokeIndex = 0
        phase = .waitingForStart
        displayProgress = 0
        fingerSnapPoint = nil
        missCountForActiveStroke = 0
        currentArc = 0
        outsideSince = nil
        totalMisses = 0
        totalHintsAutoPlayed = 0
        firstTouchTime = nil
        lastTouchTime = 0
    }

    // MARK: - Gesture input (canvas coordinates)

    func touchBegan(at point: CGPoint, time: TimeInterval) {
        guard phase == .waitingForStart, let stroke = activeStroke else { return }

        if firstTouchTime == nil { firstTouchTime = time }
        lastTouchTime = time

        let startRadius = stroke.corridorRadius * tuning.startRadiusFactor
        guard distance(point, stroke.startPoint) <= startRadius else { return }

        if stroke.isDot {
            completeActiveStroke()
            return
        }

        currentArc = 0
        outsideSince = nil
        displayProgress = 0
        fingerSnapPoint = stroke.startPoint
        phase = .tracing
        emit(.strokeStarted(index: activeStrokeIndex))
    }

    func touchMoved(to point: CGPoint, time: TimeInterval) {
        guard phase == .tracing, let stroke = activeStroke else { return }
        lastTouchTime = time

        let lowerArc = currentArc - tuning.backwardSlackFraction * stroke.totalLength
        let upperArc = currentArc + max(
            tuning.forwardWindowFactor * stroke.corridorRadius,
            tuning.forwardWindowLengthFraction * stroke.totalLength
        )

        guard
            let projection = TraceGeometry.project(point, onto: stroke, lowerArc: lowerArc, upperArc: upperArc),
            projection.distance <= stroke.corridorRadius
        else {
            registerOutsideCorridor(at: time)
            return
        }

        outsideSince = nil
        if projection.arcLength > currentArc {
            currentArc = projection.arcLength
        }
        displayProgress = quantize(currentArc / stroke.totalLength)
        fingerSnapPoint = projection.point

        if currentArc / stroke.totalLength >= 0.995 {
            completeActiveStroke()
        }
    }

    func touchEnded(at point: CGPoint, time: TimeInterval) {
        guard phase == .tracing, let stroke = activeStroke else { return }
        lastTouchTime = time

        let threshold = stroke.totalLength < tuning.shortStrokeLength
            ? tuning.shortStrokeCompletionProgress
            : tuning.completionProgress
        let progress = stroke.totalLength > .ulpOfOne ? currentArc / stroke.totalLength : 1
        let nearEnd = distance(point, stroke.endPoint) <= stroke.corridorRadius * tuning.endRadiusFactor

        if progress >= threshold && nearEnd {
            completeActiveStroke()
        } else {
            registerMiss()
        }
    }

    // MARK: - View callbacks

    /// The canvas finished animating the partial fill back to zero.
    func rollbackAnimationFinished() {
        guard phase == .rollingBack else { return }
        currentArc = 0
        displayProgress = 0
        fingerSnapPoint = nil

        if missCountForActiveStroke >= tuning.missesBeforeAutoHint {
            missCountForActiveStroke = 0
            totalHintsAutoPlayed += 1
            phase = .playingHint
            emit(.hintAutoPlayed(index: activeStrokeIndex))
        } else {
            phase = .waitingForStart
        }
    }

    /// The canvas finished the brief snap presentation of a completed stroke.
    func strokeSnapFinished() {
        guard phase == .strokeComplete else { return }

        if activeStrokeIndex < strokes.count - 1 {
            activeStrokeIndex += 1
            currentArc = 0
            displayProgress = 0
            fingerSnapPoint = nil
            missCountForActiveStroke = 0
            outsideSince = nil
            phase = .waitingForStart
        } else {
            phase = .characterComplete
            let duration = firstTouchTime.map { lastTouchTime - $0 } ?? 0
            emit(.characterCompleted(TraceAttemptStats(
                misses: totalMisses,
                hintsAutoPlayed: totalHintsAutoPlayed,
                duration: duration
            )))
        }
    }

    /// Manual hint replay; does not count toward auto-hint stats.
    func requestHint() {
        guard phase == .waitingForStart else { return }
        phase = .playingHint
    }

    /// The canvas finished demonstrating the active stroke.
    func hintPlaybackFinished() {
        guard phase == .playingHint else { return }
        phase = .waitingForStart
    }

    // MARK: - Private

    private func registerOutsideCorridor(at time: TimeInterval) {
        if let since = outsideSince {
            if time - since > tuning.deviationGrace {
                registerMiss()
            }
        } else {
            outsideSince = time
        }
    }

    private func registerMiss() {
        missCountForActiveStroke += 1
        totalMisses += 1
        outsideSince = nil
        phase = .rollingBack
        emit(.miss(index: activeStrokeIndex, count: missCountForActiveStroke))
    }

    private func completeActiveStroke() {
        guard let stroke = activeStroke else { return }
        currentArc = stroke.totalLength
        displayProgress = 1
        fingerSnapPoint = nil
        outsideSince = nil
        phase = .strokeComplete
        emit(.strokeCompleted(index: activeStrokeIndex))
    }

    private func quantize(_ progress: CGFloat) -> CGFloat {
        let clamped = min(max(progress, 0), 1)
        return (clamped * Self.quantizationSteps).rounded() / Self.quantizationSteps
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    private func emit(_ event: EngineEvent) {
        onEvent?(event)
    }
}
