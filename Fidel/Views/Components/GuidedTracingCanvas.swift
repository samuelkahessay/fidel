import SwiftUI

/// Interactive stroke-by-stroke tracing canvas (dark "ink slate").
///
/// Renders the glyph as an engraved channel, fills completed strokes, shows the
/// user's raw ink live while tracing, then on release animates that ink settling
/// onto the exemplar (the "magnet") while the clean fill fades in. Overlays
/// guidance: a writing grid, a directional start arrow, an end arrowhead, a
/// bright dashed guide path, and a looping stroke-demonstration hint.
///
/// All timing-based visuals (hint loop, magnet snap, snap pause) run here in
/// `.task(id:)` blocks keyed to the engine phase, reporting back to the engine
/// when they finish.
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
    /// Drives the magnet snap (0 → 1): the user's raw ink morphs onto the
    /// exemplar while the clean fill fades in. nil when not snapping.
    @State private var snapT: CGFloat?
    /// The user's raw finger trail for the active stroke, shown live while
    /// tracing and then animated onto the exemplar on release.
    @State private var userInkPoints: [CGPoint] = []
    @State private var startDotPulsing = false

    private var strokeData: CharacterStrokeData? {
        StrokeDataRepository.shared.getStrokeData(for: characterId)
    }

    /// Strength of the engraved channel. Full guide shows it confidently; the
    /// faint level dims it so difficulty comes from reduced scaffolding, not a
    /// tighter input target.
    private var channelOpacity: Double {
        guideLevel == .full ? 1.0 : 0.45
    }

    /// Minimum visual channel width so thin Noto limbs still read as a
    /// fillable engraved trough on the simplest (earliest) characters.
    private var minChannelWidth: CGFloat {
        max(PathExtractor.shared.glyphStrokeWidth(for: character, size: size), 10)
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
            // Faint writing grid behind everything for spatial reference.
            crosshairGrid

            // Engraved channel: the whole glyph rendered as a recessed dark
            // trough the bright ink fills. The fill + a min-width stroke
            // guarantees a fillable body even for thin limbs; a lighter edge
            // stroke makes it read as engraved rather than printed. Replaces
            // the old faint ghost.
            glyphPath.fill(AppTheme.traceChannelColor.opacity(channelOpacity))
            glyphPath.stroke(
                AppTheme.traceChannelColor.opacity(channelOpacity),
                style: StrokeStyle(lineWidth: minChannelWidth, lineCap: .round, lineJoin: .round)
            )
            glyphPath.stroke(
                AppTheme.traceChannelEdgeColor.opacity(channelOpacity * 0.9),
                style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round)
            )

            // Cue the next stroke by brightening its channel slightly, before
            // the learner starts tracing it.
            if engine.phase == .waitingForStart || engine.phase == .playingHint,
                let region = activeRegion(in: regions)
            {
                glyphPath.fill(AppTheme.traceGuideColor.opacity(0.16))
                    .mask {
                        Canvas { context, canvasSize in
                            context.draw(
                                Image(decorative: region.regionImage, scale: 1),
                                in: CGRect(origin: .zero, size: canvasSize)
                            )
                        }
                    }
            }

            // Completed strokes: clean bright fill (full reveal). Once the whole
            // character is traced, drop the masks: ownership regions can leave a
            // few unclaimed pixels ("dust"), and the unmasked fill guarantees a
            // clean completed glyph.
            if engine.phase == .characterComplete {
                glyphPath.fill(fillColor)
            } else {
                glyphPath.fill(fillColor)
                    .mask {
                        Canvas { context, canvasSize in
                            for (index, region) in regions.enumerated() where index < engine.activeStrokeIndex {
                                context.draw(
                                    Image(decorative: region.regionImage, scale: 1),
                                    in: CGRect(origin: .zero, size: canvasSize)
                                )
                            }
                        }
                    }

                // Active stroke clean fill: instant (dots / in-corridor finish /
                // accessibility) shows it solid; the magnet snap fades it in as
                // the raw ink settles onto it.
                if let region = activeRegion(in: regions) {
                    let cleanOpacity: Double =
                        engine.phase == .strokeComplete
                        ? 1
                        : (engine.phase == .snapping ? Double(snapT ?? 0) : 0)
                    if cleanOpacity > 0 {
                        glyphPath.fill(fillColor)
                            .mask {
                                Canvas { context, canvasSize in
                                    context.draw(
                                        Image(decorative: region.regionImage, scale: 1),
                                        in: CGRect(origin: .zero, size: canvasSize)
                                    )
                                }
                            }
                            .opacity(cleanOpacity)
                    }
                }

                // The user's raw ink for the active stroke: shown live while
                // tracing, then morphed onto the exemplar (and faded) during the
                // magnet snap — the "your line aligns to the guide" delight.
                if userInkPoints.count > 1, let stroke = engine.activeStroke {
                    if engine.phase == .tracing {
                        rawInkPath(userInkPoints)
                            .stroke(
                                fillColor.opacity(0.92),
                                style: StrokeStyle(lineWidth: inkStrokeWidth, lineCap: .round, lineJoin: .round)
                            )
                            .allowsHitTesting(false)
                    } else if engine.phase == .snapping, let t = snapT {
                        morphedInkPath(from: userInkPoints, to: stroke, t: t)
                            .stroke(
                                fillColor.opacity(0.92 * (1 - Double(t))),
                                style: StrokeStyle(lineWidth: inkStrokeWidth, lineCap: .round, lineJoin: .round)
                            )
                            .allowsHitTesting(false)
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

            // Guidance overlay: bright dashed guide path, a directional start
            // arrow, and an end arrowhead — always showing where to begin, which
            // way to go, and where the stroke finishes.
            if showsGuidance, let region = activeRegion(in: regions), let stroke = engine.activeStroke {
                region.smoothedPath
                    .stroke(
                        AppTheme.traceGuideColor.opacity(0.55),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [7, 7])
                    )
                    .allowsHitTesting(false)

                endArrowhead(for: stroke)
                startDot(for: stroke)
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
        .accessibilityValue("\(Int((max(engine.displayProgress, snapT ?? 0) * 100).rounded())) percent traced")
        .accessibilityAction(named: "Play demonstration") {
            engine.requestHint()
        }
        .accessibilityAction(named: "Mark stroke complete") {
            engine.accessibilityCompleteActiveStroke()
        }
    }

    // MARK: - Raw ink + magnet morph

    /// Width of the user's ink / morph stroke — a touch under the channel so it
    /// reads as ink laid into the trough.
    private var inkStrokeWidth: CGFloat {
        max(minChannelWidth * 0.72, 7)
    }

    /// A polyline path through the user's raw finger points.
    private func rawInkPath(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        return path
    }

    /// The magnet: the user's resampled trail linearly interpolated toward the
    /// exemplar centerline by `t` (0 = raw ink, 1 = clean exemplar). Both are
    /// resampled by arc length from the start, which they share (the start gate
    /// keeps the first point near the stroke's start), so the morph reads as the
    /// line "settling" onto the guide.
    private func morphedInkPath(from userPoints: [CGPoint], to stroke: TraceableStroke, t: CGFloat) -> Path {
        let count = 48
        let a = resample(userPoints, to: count)
        let b = resample(stroke.polyline, to: count)
        guard a.count == count, b.count == count else { return rawInkPath(userPoints) }

        var path = Path()
        let lerped = (0..<count).map { i in
            CGPoint(x: a[i].x + (b[i].x - a[i].x) * t, y: a[i].y + (b[i].y - a[i].y) * t)
        }
        path.move(to: lerped[0])
        for i in 1..<count { path.addLine(to: lerped[i]) }
        return path
    }

    /// Resamples a polyline to `count` points evenly spaced by arc length.
    private func resample(_ points: [CGPoint], to count: Int) -> [CGPoint] {
        guard points.count > 1, count > 1 else { return points }
        var cumulative: [CGFloat] = [0]
        for i in 1..<points.count {
            cumulative.append(cumulative[i - 1] + hypot(points[i].x - points[i - 1].x, points[i].y - points[i - 1].y))
        }
        let total = cumulative.last ?? 0
        guard total > 0 else { return Array(repeating: points[0], count: count) }

        var result: [CGPoint] = []
        result.reserveCapacity(count)
        for k in 0..<count {
            let target = total * CGFloat(k) / CGFloat(count - 1)
            var i = 1
            while i < points.count && cumulative[i] < target { i += 1 }
            if i >= points.count {
                result.append(points[points.count - 1])
                continue
            }
            let segment = cumulative[i] - cumulative[i - 1]
            let f = segment > .ulpOfOne ? (target - cumulative[i - 1]) / segment : 0
            result.append(
                CGPoint(
                    x: points[i - 1].x + (points[i].x - points[i - 1].x) * f,
                    y: points[i - 1].y + (points[i].y - points[i - 1].y) * f
                ))
        }
        return result
    }

    private func activeRegion(in regions: [StrokeRevealRegion]) -> StrokeRevealRegion? {
        regions.indices.contains(engine.activeStrokeIndex) ? regions[engine.activeStrokeIndex] : nil
    }

    // MARK: - Guidance pieces

    /// Faint dashed writing grid (vertical + horizontal centerlines) for spatial
    /// reference, like a simplified 米字格.
    private var crosshairGrid: some View {
        Path { path in
            path.move(to: CGPoint(x: size.width / 2, y: 0))
            path.addLine(to: CGPoint(x: size.width / 2, y: size.height))
            path.move(to: CGPoint(x: 0, y: size.height / 2))
            path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
        }
        .stroke(AppTheme.traceGridColor.opacity(0.55), style: StrokeStyle(lineWidth: 1, dash: [5, 8]))
        .allowsHitTesting(false)
    }

    /// Start indicator: a filled accent disc with a white arrow pointing in the
    /// stroke's direction — tells you where to begin AND which way to go.
    private func startDot(for stroke: TraceableStroke) -> some View {
        let tangent = TraceGeometry.tangent(at: 0, on: stroke)
        let angle = Angle(radians: atan2(tangent.dy, tangent.dx))
        return ZStack {
            Circle()
                .fill(AppTheme.traceGuideColor)
            Image(systemName: "arrow.right")
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(AppTheme.traceSlateColor)
                .rotationEffect(angle)
        }
        .frame(width: 30, height: 30)
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

    /// An arrowhead at the stroke's end, marking where the stroke finishes.
    private func endArrowhead(for stroke: TraceableStroke) -> some View {
        let tangent = TraceGeometry.tangent(at: stroke.totalLength, on: stroke)
        let angle = Angle(radians: atan2(tangent.dy, tangent.dx))
        return Image(systemName: "arrowtriangle.right.fill")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(AppTheme.traceGuideColor)
            .rotationEffect(angle)
            .position(stroke.endPoint)
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
                    userInkPoints = [value.location]
                    engine.touchBegan(at: value.location, time: time)
                } else if engine.phase == .tracing {
                    userInkPoints.append(value.location)
                    engine.touchMoved(to: value.location, time: time)
                }
            }
            .onEnded { value in
                if engine.phase == .tracing {
                    userInkPoints.append(value.location)
                }
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
            snapT = nil
            userInkPoints = []
            guard !reduceMotion else { return }
            if guideLevel == .faint && engine.missCountForActiveStroke == 0 {
                try? await Task.sleep(for: .seconds(engine.tuning.hesitationHintDelay))
                guard !Task.isCancelled else { return }
            }
            await loopHint()

        case .playingHint:
            userInkPoints = []
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

        case .snapping:
            // The magnet: animate the user's ink settling onto the exemplar
            // while the clean fill fades in, then commit.
            if reduceMotion {
                snapT = 1
            } else {
                await animateMagnetSnap()
            }
            guard !Task.isCancelled else { return }
            // Commit first (the stroke becomes a completed full fill), then clear
            // the snap state — coalesced into one render, so no gap.
            engine.strokeMagnetSnapFinished()
            snapT = nil
            userInkPoints = []

        case .strokeComplete:
            hintProgress = nil
            snapT = nil
            try? await Task.sleep(for: .seconds(0.15))
            guard !Task.isCancelled else { return }
            engine.strokeSnapFinished()

        case .tracing:
            hintProgress = nil
            snapT = nil

        case .characterComplete:
            hintProgress = nil
            snapT = nil
            userInkPoints = []
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

    /// Drives the magnet snap: `snapT` 0 → 1 with an ease-out so the user's ink
    /// glides onto the exemplar and the clean fill settles in. A deterministic
    /// frame loop (not a spring) keeps the per-frame cost predictable.
    private func animateMagnetSnap() async {
        let duration = max(engine.tuning.snapDuration, 0.01)
        let interval: TimeInterval = 1.0 / 60.0
        let steps = max(Int((duration / interval).rounded()), 1)

        snapT = 0
        for step in 1...steps {
            try? await Task.sleep(for: .seconds(interval))
            guard !Task.isCancelled else { return }
            let raw = CGFloat(step) / CGFloat(steps)
            snapT = 1 - pow(1 - raw, 3)  // ease-out cubic
        }
        snapT = 1
    }

    // MARK: - Accessibility

    private var accessibilityDescription: String {
        let total = engine.strokes.count
        guard total > 0 else { return "Tracing canvas for \(character)" }
        return "Trace stroke \(engine.activeStrokeIndex + 1) of \(total) for \(character)"
    }
}
