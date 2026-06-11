import SwiftUI

/// Interactive stroke-by-stroke tracing canvas.
///
/// Renders the ghost glyph, fills completed strokes, fills the active stroke
/// live as the finger advances (reusing the per-stroke reveal masks from
/// `StrokeRegionBuilder`), and overlays guidance: a numbered start dot, a
/// dashed centerline, and a looping stroke-demonstration hint.
///
/// All timing-based visuals (hint loop, rollback animation, snap pause) run
/// here in `.task(id:)` blocks keyed to the engine phase, reporting back to
/// the engine when they finish.
struct GuidedTracingCanvas: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let character: String
    let characterId: String
    let size: CGSize
    var guideLevel: GuideLevel = .full
    var fillColor: Color = AppTheme.practiceColor
    let engine: TraceEngine

    enum GuideLevel {
        case full
        case faint
    }

    @State private var hintProgress: CGFloat?
    @State private var rollbackProgress: CGFloat?
    @State private var startDotPulsing = false

    private var strokeData: CharacterStrokeData? {
        StrokeDataRepository.shared.getStrokeData(for: characterId)
    }

    private var ghostOpacity: Double {
        guideLevel == .full ? 0.14 : 0.06
    }

    private var showsGuidance: Bool {
        guard engine.phase == .waitingForStart || engine.phase == .playingHint else { return false }
        if guideLevel == .full { return true }
        return engine.missCountForActiveStroke > 0 || hintProgress != nil
    }

    var body: some View {
        let glyphPath = PathExtractor.shared.extractPath(for: character, size: size)
        let glyphCGPath = PathExtractor.shared.extractCGPath(for: character, size: size)
        let strokes = strokeData?.strokes ?? []
        let glyphStrokeWidth = PathExtractor.shared.glyphStrokeWidth(for: character, size: size)
        let revealResult = StrokeRegionBuilder.shared.regions(
            characterKey: characterId,
            glyphPath: glyphCGPath,
            strokes: strokes,
            canvasSize: size,
            glyphStrokeWidth: glyphStrokeWidth,
            recordingGlyphScale: TracingSessionViewModel.recordingGlyphScale
        )
        let regions = revealResult.regions

        ZStack {
            // Ghost glyph as the always-visible target shape.
            glyphPath.fill(fillColor.opacity(ghostOpacity))

            // Completed strokes + live partial fill of the active stroke.
            // Once the whole character is traced, drop the masks: ownership
            // regions can leave a few unclaimed pixels ("dust"), and the
            // unmasked fill guarantees a clean completed glyph.
            if engine.phase == .characterComplete {
                glyphPath.fill(fillColor)
            } else {
                glyphPath.fill(fillColor)
                    .mask {
                        Canvas { context, canvasSize in
                            for (index, region) in regions.enumerated() {
                                let progress = fillProgress(for: index)
                                guard progress > 0 else { continue }
                                let image = progress >= 1 ? region.regionImage : region.image(for: progress)
                                context.draw(
                                    Image(decorative: image, scale: 1),
                                    in: CGRect(origin: .zero, size: canvasSize)
                                )
                            }
                        }
                    }
            }

            // Hint demonstration of the active stroke.
            if let hintProgress, let region = activeRegion(in: regions), let stroke = engine.activeStroke {
                glyphPath.fill(fillColor.opacity(engine.phase == .playingHint ? 0.85 : 0.5))
                    .mask {
                        Canvas { context, canvasSize in
                            context.draw(
                                Image(decorative: region.image(for: hintProgress), scale: 1),
                                in: CGRect(origin: .zero, size: canvasSize)
                            )
                        }
                    }

                Circle()
                    .fill(fillColor.opacity(0.85))
                    .frame(width: 9, height: 9)
                    .position(TraceGeometry.point(at: hintProgress * stroke.totalLength, on: stroke))
                    .allowsHitTesting(false)
            }

            // Guidance overlay: dashed centerline + numbered start dot.
            if showsGuidance, let region = activeRegion(in: regions), let stroke = engine.activeStroke {
                region.smoothedPath
                    .stroke(
                        fillColor.opacity(0.35),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 6])
                    )
                    .allowsHitTesting(false)

                startDot(for: stroke)

                if reduceMotion {
                    directionChevron(for: stroke)
                }
            }

            // Snap point under the finger while tracing.
            if let snapPoint = engine.fingerSnapPoint, engine.phase == .tracing {
                Circle()
                    .fill(fillColor)
                    .frame(width: 11, height: 11)
                    .overlay {
                        Circle()
                            .stroke(fillColor.opacity(0.35), lineWidth: 6)
                    }
                    .position(snapPoint)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())
        .gesture(traceGesture)
        .task(id: visualTaskKey) {
            await runPhaseVisuals()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityValue("\(Int((engine.displayProgress * 100).rounded())) percent traced")
        .accessibilityAction(named: "Play demonstration") {
            engine.requestHint()
        }
        .accessibilityAction(named: "Mark stroke complete") {
            engine.accessibilityCompleteActiveStroke()
        }
    }

    // MARK: - Stroke fill

    private func fillProgress(for index: Int) -> CGFloat {
        if index < engine.activeStrokeIndex { return 1 }
        guard index == engine.activeStrokeIndex else { return 0 }

        if hintProgress != nil && engine.phase != .tracing { return 0 }
        if let rollbackProgress { return rollbackProgress }
        return engine.displayProgress
    }

    private func activeRegion(in regions: [StrokeRevealRegion]) -> StrokeRevealRegion? {
        regions.indices.contains(engine.activeStrokeIndex) ? regions[engine.activeStrokeIndex] : nil
    }

    // MARK: - Guidance pieces

    private func startDot(for stroke: TraceableStroke) -> some View {
        ZStack {
            Circle()
                .fill(fillColor)
            Text("\(stroke.index + 1)")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.onAccentColor)
        }
        .frame(width: 28, height: 28)
        .scaleEffect(startDotPulsing && !reduceMotion ? 1.15 : 1.0)
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.7).repeatForever(autoreverses: true),
            value: startDotPulsing
        )
        .position(stroke.startPoint)
        .allowsHitTesting(false)
        .onAppear { startDotPulsing = true }
        .onDisappear { startDotPulsing = false }
    }

    private func directionChevron(for stroke: TraceableStroke) -> some View {
        let tangent = TraceGeometry.tangent(at: 0, on: stroke)
        let angle = Angle(radians: atan2(tangent.dy, tangent.dx))
        let offsetDistance: CGFloat = 24

        return Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(fillColor)
            .rotationEffect(angle)
            .position(
                x: stroke.startPoint.x + tangent.dx * offsetDistance,
                y: stroke.startPoint.y + tangent.dy * offsetDistance
            )
            .allowsHitTesting(false)
    }

    // MARK: - Gesture

    private var traceGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                let time = value.time.timeIntervalSinceReferenceDate
                if engine.phase == .waitingForStart {
                    // Allows a drag that slides into the start circle to begin
                    // the stroke, not just an initial touch on it.
                    engine.touchBegan(at: value.location, time: time)
                } else {
                    engine.touchMoved(to: value.location, time: time)
                }
            }
            .onEnded { value in
                engine.touchEnded(at: value.location, time: value.time.timeIntervalSinceReferenceDate)
            }
    }

    // MARK: - Phase-driven visuals

    private struct VisualTaskKey: Hashable {
        let phase: TraceEngine.StrokePhase
        let strokeIndex: Int
        let characterId: String
    }

    private var visualTaskKey: VisualTaskKey {
        VisualTaskKey(phase: engine.phase, strokeIndex: engine.activeStrokeIndex, characterId: characterId)
    }

    private func runPhaseVisuals() async {
        switch engine.phase {
        case .waitingForStart:
            hintProgress = nil
            rollbackProgress = nil
            guard !reduceMotion else { return }
            if guideLevel == .faint && engine.missCountForActiveStroke == 0 {
                try? await Task.sleep(for: .seconds(engine.tuning.hesitationHintDelay))
                guard !Task.isCancelled else { return }
            }
            await loopHint()

        case .playingHint:
            if reduceMotion {
                hintProgress = 1
                try? await Task.sleep(for: .seconds(0.8))
                hintProgress = nil
                guard !Task.isCancelled else { return }
                engine.hintPlaybackFinished()
            } else {
                await playHintPass()
                hintProgress = nil
                guard !Task.isCancelled else { return }
                engine.hintPlaybackFinished()
            }

        case .rollingBack:
            if reduceMotion {
                rollbackProgress = nil
                engine.rollbackAnimationFinished()
            } else {
                await animateRollback()
                guard !Task.isCancelled else { return }
                rollbackProgress = nil
                engine.rollbackAnimationFinished()
            }

        case .strokeComplete:
            hintProgress = nil
            rollbackProgress = nil
            try? await Task.sleep(for: .seconds(0.15))
            guard !Task.isCancelled else { return }
            engine.strokeSnapFinished()

        case .tracing, .characterComplete:
            hintProgress = nil
            rollbackProgress = nil
        }
    }

    private var hintPassDuration: TimeInterval {
        guard let stroke = engine.activeStroke else { return 0.8 }
        let speedBased = stroke.totalLength / (size.width * 0.9)
        return min(max(TimeInterval(speedBased), 0.6), 1.6)
    }

    private func loopHint() async {
        while !Task.isCancelled {
            await playHintPass()
            hintProgress = nil
            try? await Task.sleep(for: .seconds(0.5))
        }
        hintProgress = nil
    }

    private func playHintPass() async {
        let duration = hintPassDuration
        let interval: TimeInterval = 1.0 / 60.0
        let increment = CGFloat(interval / duration)
        var progress: CGFloat = 0

        while progress < 1, !Task.isCancelled {
            try? await Task.sleep(for: .seconds(interval))
            progress = min(progress + increment, 1)
            hintProgress = progress
        }
    }

    private func animateRollback() async {
        var progress = engine.displayProgress
        rollbackProgress = progress
        let duration = max(engine.tuning.rollbackDuration, 0.01)
        let interval: TimeInterval = 1.0 / 60.0
        let decrement = progress * CGFloat(interval / duration)

        while progress > 0, !Task.isCancelled {
            try? await Task.sleep(for: .seconds(interval))
            progress = max(progress - decrement, 0)
            rollbackProgress = progress
        }
    }

    // MARK: - Accessibility

    private var accessibilityDescription: String {
        let total = engine.strokes.count
        guard total > 0 else { return "Tracing canvas for \(character)" }
        return "Trace stroke \(engine.activeStrokeIndex + 1) of \(total) for \(character)"
    }
}
