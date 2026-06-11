import CoreGraphics
import XCTest
@testable import Fidel___Learn_Amharic

/// Unit tests for the guided tracing engine using synthetic strokes.
/// All strokes use recordingGlyphScale 1.0 so normalized points map directly
/// to canvas coordinates (no 0.58 recording remap).
@MainActor
final class TraceEngineTests: XCTestCase {

    private let canvasSize = CGSize(width: 300, height: 300)
    private let glyphStrokeWidth: CGFloat = 10

    /// Horizontal stroke from (30,150) to (270,150): 240pt long.
    private func horizontalStroke(penWidth: Double = 0.05) -> RecordedStroke {
        RecordedStroke(
            points: [StrokePoint(x: 0.1, y: 0.5), StrokePoint(x: 0.9, y: 0.5)],
            penWidth: penWidth
        )
    }

    /// Vertical stroke from (150,30) to (150,270): 240pt long.
    private func verticalStroke(penWidth: Double = 0.05) -> RecordedStroke {
        RecordedStroke(
            points: [StrokePoint(x: 0.5, y: 0.1), StrokePoint(x: 0.5, y: 0.9)],
            penWidth: penWidth
        )
    }

    /// Tiny mark shorter than the dot threshold (6pt long).
    private func dotStroke() -> RecordedStroke {
        RecordedStroke(
            points: [StrokePoint(x: 0.5, y: 0.5), StrokePoint(x: 0.52, y: 0.5)],
            penWidth: 0.05
        )
    }

    private func makeEngine(
        strokes: [RecordedStroke],
        tuning: TraceTuning = .standard
    ) -> (TraceEngine, EventRecorder) {
        let engine = TraceEngine()
        let recorder = EventRecorder()
        engine.onEvent = { recorder.events.append($0) }
        engine.configure(
            strokes: strokes,
            canvasSize: canvasSize,
            glyphStrokeWidth: glyphStrokeWidth,
            recordingGlyphScale: 1.0,
            tuning: tuning
        )
        return (engine, recorder)
    }

    private final class EventRecorder {
        var events: [TraceEngine.EngineEvent] = []
    }

    // MARK: - TraceGeometry

    func testTraceableStrokeComputesArcLengthAndEndpoints() {
        let strokes = TraceGeometry.traceableStrokes(
            from: [horizontalStroke()],
            canvasSize: canvasSize,
            glyphStrokeWidth: glyphStrokeWidth,
            recordingGlyphScale: 1.0,
            tuning: .standard
        )

        XCTAssertEqual(strokes.count, 1)
        let stroke = strokes[0]
        XCTAssertEqual(stroke.totalLength, 240, accuracy: 2)
        XCTAssertEqual(stroke.startPoint.x, 30, accuracy: 1)
        XCTAssertEqual(stroke.startPoint.y, 150, accuracy: 1)
        XCTAssertEqual(stroke.endPoint.x, 270, accuracy: 1)
        XCTAssertFalse(stroke.isDot)
        XCTAssertGreaterThanOrEqual(stroke.corridorRadius, TraceTuning.standard.minCorridorRadius)
        XCTAssertLessThanOrEqual(stroke.corridorRadius, canvasSize.width * TraceTuning.standard.maxCorridorRadiusRatio)
    }

    func testPointAtArcLengthInterpolatesAlongStroke() {
        let stroke = TraceGeometry.traceableStrokes(
            from: [horizontalStroke()],
            canvasSize: canvasSize,
            glyphStrokeWidth: glyphStrokeWidth,
            recordingGlyphScale: 1.0,
            tuning: .standard
        )[0]

        let midpoint = TraceGeometry.point(at: 120, on: stroke)
        XCTAssertEqual(midpoint.x, 150, accuracy: 2)
        XCTAssertEqual(midpoint.y, 150, accuracy: 2)
    }

    func testWindowedProjectionRespectsArcWindowOnSelfCrossingStroke() {
        // Path goes right, then loops back crossing itself near the center.
        let crossing = RecordedStroke(
            points: [
                StrokePoint(x: 0.1, y: 0.5),
                StrokePoint(x: 0.9, y: 0.5),
                StrokePoint(x: 0.5, y: 0.1),
                StrokePoint(x: 0.5, y: 0.9)
            ],
            penWidth: 0.05
        )
        let stroke = TraceGeometry.traceableStrokes(
            from: [crossing],
            canvasSize: canvasSize,
            glyphStrokeWidth: glyphStrokeWidth,
            recordingGlyphScale: 1.0,
            tuning: .standard
        )[0]

        // Take a point that is exactly on the early portion of the path.
        let earlyArc: CGFloat = 100
        let probe = TraceGeometry.point(at: earlyArc, on: stroke)

        // With an early window the projection must land near the early arc,
        // not jump to a later pass through the same area.
        let early = TraceGeometry.project(probe, onto: stroke, lowerArc: 0, upperArc: 180)
        XCTAssertNotNil(early)
        XCTAssertEqual(early!.arcLength, earlyArc, accuracy: 10)
        XCTAssertEqual(early!.distance, 0, accuracy: 2)

        // With a window restricted to the late path, the same probe point must
        // project somewhere inside that late window instead.
        let lateLower = stroke.totalLength * 0.6
        let late = TraceGeometry.project(probe, onto: stroke, lowerArc: lateLower, upperArc: stroke.totalLength)
        XCTAssertNotNil(late)
        XCTAssertGreaterThanOrEqual(late!.arcLength, lateLower - 1)
    }

    func testDotStrokeIsFlaggedAsDot() {
        let stroke = TraceGeometry.traceableStrokes(
            from: [dotStroke()],
            canvasSize: canvasSize,
            glyphStrokeWidth: glyphStrokeWidth,
            recordingGlyphScale: 1.0,
            tuning: .standard
        )[0]

        XCTAssertTrue(stroke.isDot)
    }

    // MARK: - Start gate

    func testTouchFarFromStartIsIgnored() {
        let (engine, recorder) = makeEngine(strokes: [horizontalStroke()])

        engine.touchBegan(at: CGPoint(x: 250, y: 280), time: 0)

        XCTAssertEqual(engine.phase, .waitingForStart)
        XCTAssertTrue(recorder.events.isEmpty)
    }

    func testTouchNearStartBeginsTracing() {
        let (engine, recorder) = makeEngine(strokes: [horizontalStroke()])

        engine.touchBegan(at: CGPoint(x: 32, y: 152), time: 0)

        XCTAssertEqual(engine.phase, .tracing)
        XCTAssertEqual(recorder.events, [.strokeStarted(index: 0)])
    }

    // MARK: - Progress

    func testProgressAdvancesMonotonicallyAndIgnoresBackwardWiggle() {
        let (engine, _) = makeEngine(strokes: [horizontalStroke()])

        engine.touchBegan(at: CGPoint(x: 30, y: 150), time: 0)
        engine.touchMoved(to: CGPoint(x: 100, y: 150), time: 0.1)
        engine.touchMoved(to: CGPoint(x: 150, y: 150), time: 0.2)

        XCTAssertEqual(engine.displayProgress, 0.5, accuracy: 0.02)
        let progressAtMid = engine.displayProgress

        // Backward wiggle must not regress published progress.
        engine.touchMoved(to: CGPoint(x: 140, y: 150), time: 0.3)
        XCTAssertEqual(engine.displayProgress, progressAtMid)
    }

    func testDisplayProgressIsQuantized() {
        let (engine, _) = makeEngine(strokes: [horizontalStroke()])

        engine.touchBegan(at: CGPoint(x: 30, y: 150), time: 0)
        engine.touchMoved(to: CGPoint(x: 100, y: 150), time: 0.1)

        let steps = engine.displayProgress * 128
        XCTAssertEqual(steps, steps.rounded(), accuracy: 0.000001)
    }

    func testLargeJumpIsLimitedByForwardWindow() {
        let (engine, _) = makeEngine(strokes: [horizontalStroke()])

        engine.touchBegan(at: CGPoint(x: 30, y: 150), time: 0)
        // Jumping straight to the end should not advance past the look-ahead window.
        engine.touchMoved(to: CGPoint(x: 270, y: 150), time: 0.1)

        XCTAssertLessThan(engine.displayProgress, 0.6)
    }

    // MARK: - Misses

    func testDeviationBeyondCorridorTriggersMissAfterGrace() {
        let (engine, recorder) = makeEngine(strokes: [horizontalStroke()])

        engine.touchBegan(at: CGPoint(x: 30, y: 150), time: 0)
        engine.touchMoved(to: CGPoint(x: 100, y: 150), time: 0.1)
        // Far outside the corridor, held past the grace interval.
        engine.touchMoved(to: CGPoint(x: 100, y: 280), time: 0.2)
        engine.touchMoved(to: CGPoint(x: 100, y: 280), time: 0.5)

        XCTAssertEqual(engine.phase, .rollingBack)
        XCTAssertTrue(recorder.events.contains(.miss(index: 0, count: 1)))

        engine.rollbackAnimationFinished()
        XCTAssertEqual(engine.phase, .waitingForStart)
        XCTAssertEqual(engine.displayProgress, 0)
    }

    func testEarlyLiftTriggersMiss() {
        let (engine, recorder) = makeEngine(strokes: [horizontalStroke()])

        engine.touchBegan(at: CGPoint(x: 30, y: 150), time: 0)
        engine.touchMoved(to: CGPoint(x: 100, y: 150), time: 0.1)
        engine.touchMoved(to: CGPoint(x: 150, y: 150), time: 0.2)
        engine.touchEnded(at: CGPoint(x: 150, y: 150), time: 0.3)

        XCTAssertEqual(engine.phase, .rollingBack)
        XCTAssertTrue(recorder.events.contains(.miss(index: 0, count: 1)))
    }

    func testSecondMissAutoPlaysHint() {
        let (engine, recorder) = makeEngine(strokes: [horizontalStroke()])

        for attempt in 1...2 {
            engine.touchBegan(at: CGPoint(x: 30, y: 150), time: TimeInterval(attempt))
            engine.touchEnded(at: CGPoint(x: 35, y: 150), time: TimeInterval(attempt) + 0.1)
            XCTAssertEqual(engine.phase, .rollingBack)
            engine.rollbackAnimationFinished()
        }

        XCTAssertEqual(engine.phase, .playingHint)
        XCTAssertTrue(recorder.events.contains(.hintAutoPlayed(index: 0)))

        engine.hintPlaybackFinished()
        XCTAssertEqual(engine.phase, .waitingForStart)
    }

    func testTouchesDuringHintAreIgnored() {
        let (engine, recorder) = makeEngine(strokes: [horizontalStroke()])

        for attempt in 1...2 {
            engine.touchBegan(at: CGPoint(x: 30, y: 150), time: TimeInterval(attempt))
            engine.touchEnded(at: CGPoint(x: 35, y: 150), time: TimeInterval(attempt) + 0.1)
            engine.rollbackAnimationFinished()
        }
        XCTAssertEqual(engine.phase, .playingHint)

        let eventCount = recorder.events.count
        engine.touchBegan(at: CGPoint(x: 30, y: 150), time: 10)

        XCTAssertEqual(engine.phase, .playingHint)
        XCTAssertEqual(recorder.events.count, eventCount)
    }

    // MARK: - Completion

    func testLiftNearEndCompletesStroke() {
        let (engine, recorder) = makeEngine(strokes: [horizontalStroke()])

        engine.touchBegan(at: CGPoint(x: 30, y: 150), time: 0)
        engine.touchMoved(to: CGPoint(x: 100, y: 150), time: 0.1)
        engine.touchMoved(to: CGPoint(x: 150, y: 150), time: 0.2)
        engine.touchMoved(to: CGPoint(x: 210, y: 150), time: 0.3)
        engine.touchMoved(to: CGPoint(x: 265, y: 150), time: 0.4)
        engine.touchEnded(at: CGPoint(x: 265, y: 150), time: 0.5)

        XCTAssertEqual(engine.phase, .strokeComplete)
        XCTAssertEqual(engine.displayProgress, 1)
        XCTAssertTrue(recorder.events.contains(.strokeCompleted(index: 0)))
    }

    func testDotStrokeCompletesOnTap() {
        let (engine, recorder) = makeEngine(strokes: [dotStroke()])

        engine.touchBegan(at: CGPoint(x: 152, y: 152), time: 0)

        XCTAssertEqual(engine.phase, .strokeComplete)
        XCTAssertTrue(recorder.events.contains(.strokeCompleted(index: 0)))
    }

    func testSnapFinishedAdvancesToNextStroke() {
        let (engine, _) = makeEngine(strokes: [horizontalStroke(), verticalStroke()])

        completeHorizontalStroke(engine)
        XCTAssertEqual(engine.phase, .strokeComplete)

        engine.strokeSnapFinished()

        XCTAssertEqual(engine.activeStrokeIndex, 1)
        XCTAssertEqual(engine.phase, .waitingForStart)
        XCTAssertEqual(engine.displayProgress, 0)
        XCTAssertEqual(engine.missCountForActiveStroke, 0)
    }

    func testCharacterCompletesAfterLastStroke() {
        let (engine, recorder) = makeEngine(strokes: [horizontalStroke()])

        engine.touchBegan(at: CGPoint(x: 30, y: 150), time: 0)
        engine.touchEnded(at: CGPoint(x: 35, y: 150), time: 0.1)
        engine.rollbackAnimationFinished()

        completeHorizontalStroke(engine, startTime: 1)
        engine.strokeSnapFinished()

        XCTAssertEqual(engine.phase, .characterComplete)
        guard case .characterCompleted(let stats)? = recorder.events.last else {
            return XCTFail("Expected characterCompleted event, got \(String(describing: recorder.events.last))")
        }
        XCTAssertEqual(stats.misses, 1)
        XCTAssertEqual(stats.hintsAutoPlayed, 0)
    }

    private func completeHorizontalStroke(_ engine: TraceEngine, startTime: TimeInterval = 0) {
        engine.touchBegan(at: CGPoint(x: 30, y: 150), time: startTime)
        engine.touchMoved(to: CGPoint(x: 100, y: 150), time: startTime + 0.1)
        engine.touchMoved(to: CGPoint(x: 150, y: 150), time: startTime + 0.2)
        engine.touchMoved(to: CGPoint(x: 210, y: 150), time: startTime + 0.3)
        engine.touchMoved(to: CGPoint(x: 265, y: 150), time: startTime + 0.4)
        engine.touchEnded(at: CGPoint(x: 265, y: 150), time: startTime + 0.5)
    }
}
