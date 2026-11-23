import CoreGraphics
import Foundation
import Observation

/// Gesture-driven state machine for guided stroke-by-stroke tracing.
///
/// The engine is fully synchronous: touch handlers receive explicit timestamps
/// and all timing-based visuals (magnet snap-fill, snap pause, hint playback)
/// are owned by the view layer, which reports back via
/// `strokeMagnetSnapFinished()`, `strokeSnapFinished()`, and
/// `hintPlaybackFinished()`. This keeps every transition deterministic and
/// unit-testable.
@MainActor
@Observable
final class TraceEngine {

    enum StrokePhase: Equatable, Hashable {
        /// Hint loop runs; a touch must land near the active stroke's start.
        case waitingForStart
        /// Finger down, advancing arc-length progress along the stroke.
        case tracing
        /// Release accepted: the canvas animates the bright fill forward from
        /// the captured partial progress up to 1.0 (the "magnet" snap).
        case snapping
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
        var accessibilityCompletions: Int = 0
    }

    // MARK: - Rendering state

    private(set) var strokes: [TraceableStroke] = []
    private(set) var activeStrokeIndex = 0
    private(set) var phase: StrokePhase = .waitingForStart
    /// Active stroke fill 0...1, quantized to 1/128 steps so repeated frames
    /// hit StrokeRevealRegion's progress short-circuit.
    private(set) var displayProgress: CGFloat = 0
    /// The partial progress captured at release; the canvas animates the bright
    /// fill from here to 1.0 during `.snapping` (the magnet snap).
    private(set) var snapStartProgress: CGFloat = 0
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
    private var totalAccessibilityCompletions = 0
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
        snapStartProgress = 0
        fingerSnapPoint = nil
        missCountForActiveStroke = 0
        currentArc = 0
        outsideSince = nil
        totalMisses = 0
        totalHintsAutoPlayed = 0
        totalAccessibilityCompletions = 0
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
        let upperArc =
            currentArc
            + max(
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

    /// Release: the magnet decision. If the finger covered enough of the stroke
    /// in-corridor (coverage is the earned bar; the wide corridor is the
    /// forgiveness), snap-complete by animating the bright fill the rest of the
    /// way. Otherwise it's a give-up — reset cleanly for another attempt.
    func touchEnded(at point: CGPoint, time: TimeInterval) {
        guard phase == .tracing, let stroke = activeStroke else { return }
        lastTouchTime = time

        let threshold =
            stroke.totalLength < tuning.shortStrokeLength
            ? tuning.shortStrokeCompletionProgress
            : tuning.magnetCompletionFraction
        let progress = stroke.totalLength > .ulpOfOne ? currentArc / stroke.totalLength : 1
        // The magnet pulls the remaining tail, so the lift may land well short
        // of the true end and still snap — but not so far it grabs a neighbour.
        let nearEnd = distance(point, stroke.endPoint) <= stroke.corridorRadius * tuning.magnetEndRadiusFactor

        if progress >= threshold && (nearEnd || progress >= 0.95) {
            magnetSnapToComplete()
        } else {
            registerGiveUp()
        }
    }

    // MARK: - View callbacks

    /// The canvas finished animating the magnet snap-fill up to 1.0. The
    /// completion event (and its haptic) fires here — when the ink lands — not
    /// at the start of the snap, so it stays in sync with the visual.
    func strokeMagnetSnapFinished() {
        guard phase == .snapping else { return }
        displayProgress = 1
        emit(.strokeCompleted(index: activeStrokeIndex))
        advanceAfterStrokeFinished()
    }

    /// The canvas finished the brief snap presentation of a completed stroke
    /// (instant-complete path: dots, in-corridor 0.995, accessibility).
    func strokeSnapFinished() {
        guard phase == .strokeComplete else { return }
        advanceAfterStrokeFinished()
    }

    /// Advance to the next stroke or emit character completion. Shared by both
    /// the instant (`.strokeComplete`) and magnet (`.snapping`) finishers.
    private func advanceAfterStrokeFinished() {
        if activeStrokeIndex < strokes.count - 1 {
            activeStrokeIndex += 1
            currentArc = 0
            displayProgress = 0
            snapStartProgress = 0
            fingerSnapPoint = nil
            missCountForActiveStroke = 0
            outsideSince = nil
            phase = .waitingForStart
        } else {
            phase = .characterComplete
            let duration = firstTouchTime.map { lastTouchTime - $0 } ?? 0
            emit(
                .characterCompleted(
                    TraceAttemptStats(
                        misses: totalMisses,
                        hintsAutoPlayed: totalHintsAutoPlayed,
                        duration: duration,
                        accessibilityCompletions: totalAccessibilityCompletions
                    )))
        }
    }

    /// Manual hint replay; does not count toward auto-hint stats.
    func requestHint() {
        guard phase == .waitingForStart else { return }
        phase = .playingHint
    }

    /// VoiceOver action: completes the active stroke without tracing.
    /// Counted in stats so the attempt scores a fixed, promotion-reachable value.
    func accessibilityCompleteActiveStroke() {
        guard phase == .waitingForStart || phase == .tracing, activeStroke != nil else { return }
        totalAccessibilityCompletions += 1
        completeActiveStroke()
    }

    /// The canvas finished demonstrating the active stroke.
    func hintPlaybackFinished() {
        guard phase == .playingHint else { return }
        phase = .waitingForStart
    }

    // MARK: - Private

    /// Finger strayed outside the corridor: pause advancement and remember when
    /// (for hint-nudge timing). Progress is PRESERVED — straying never erases,
    /// it just waits for the finger to come back. Never a miss.
    private func registerOutsideCorridor(at time: TimeInterval) {
        if outsideSince == nil { outsideSince = time }
    }

    /// Release without enough coverage: a genuine give-up. Reset the partial
    /// fill cleanly (no rollback animation) and either wait for another attempt
    /// or auto-play the hint after repeated give-ups. Still emits `.miss` so
    /// scoring/haptics are preserved.
    private func registerGiveUp() {
        missCountForActiveStroke += 1
        totalMisses += 1
        currentArc = 0
        displayProgress = 0
        snapStartProgress = 0
        fingerSnapPoint = nil
        outsideSince = nil
        emit(.miss(index: activeStrokeIndex, count: missCountForActiveStroke))

        if missCountForActiveStroke >= tuning.missesBeforeAutoHint {
            missCountForActiveStroke = 0
            totalHintsAutoPlayed += 1
            phase = .playingHint
            emit(.hintAutoPlayed(index: activeStrokeIndex))
        } else {
            phase = .waitingForStart
        }
    }

    /// The magnet: accept the loose drag and hand off to the canvas to animate
    /// the bright fill forward from the captured partial progress to 1.0. The
    /// canvas reports back via `strokeMagnetSnapFinished()`.
    private func magnetSnapToComplete() {
        guard let stroke = activeStroke else { return }
        snapStartProgress = displayProgress
        currentArc = stroke.totalLength
        fingerSnapPoint = nil
        outsideSince = nil
        phase = .snapping
        // `.strokeCompleted` is emitted from `strokeMagnetSnapFinished()` when
        // the snap animation lands, keeping the haptic synced to the visual.
    }

    /// Instant completion (dots, in-corridor 0.995 fast-path, accessibility):
    /// jump straight to a filled stroke with the brief snap pause.
    private func completeActiveStroke() {
        guard let stroke = activeStroke else { return }
        currentArc = stroke.totalLength
        displayProgress = 1
        snapStartProgress = 1
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
