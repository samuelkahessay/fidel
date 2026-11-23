import SwiftUI

/// Animated character demonstration that reveals a Fidel character.
/// - **Stroke mode**: If recorded stroke data exists, replays strokes sequentially
///   using thick stroke paths as a mask over the filled glyph shape.
///   Per-stroke pen width, proportional timing, Catmull-Rom smoothing, and a
///   moving pen-tip indicator produce CJK-quality animation.
/// - **Fallback mode**: Top-to-bottom mask wipe (original behavior).
struct StrokeAnimationView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let character: String
    let size: CGSize
    var characterId: String? = nil
    var maxLoops = 2
    var totalDuration: CGFloat = 2.0
    /// The revealed (bright) ink color. Defaults to the legacy plum; the tracing
    /// flow passes the ink-slate color for a bright-on-dark demo.
    var inkColor: Color = AppTheme.practiceColor
    /// The faint backdrop glyph shown before/under the reveal.
    var ghostColor: Color = AppTheme.practiceColor.opacity(0.08)
    /// Called once after the final loop completes (or shortly after the static
    /// reveal under Reduce Motion).
    var onFinished: (() -> Void)? = nil

    @State private var animationProgress: CGFloat = 0
    @State private var loopCount = 0

    /// The glyph occupied 58% of the canvas (centered) during recording.
    /// Strokes must be remapped from recording space to full-glyph space.
    private let recordingGlyphScale: Double = 0.58

    private var strokeData: CharacterStrokeData? {
        guard let id = characterId else { return nil }
        return StrokeDataRepository.shared.getStrokeData(for: id)
    }

    /// Remaps a point from recording canvas coords (where glyph was 58% centered)
    /// to playback coords (where glyph fills the full view).
    private func remapPoints(_ points: [StrokePoint]) -> [StrokePoint] {
        let offset = (1.0 - recordingGlyphScale) / 2.0
        return points.map { p in
            StrokePoint(
                x: (p.x - offset) / recordingGlyphScale,
                y: (p.y - offset) / recordingGlyphScale
            )
        }
    }

    var body: some View {
        if let data = strokeData, !data.strokes.isEmpty {
            strokeReplayView(data)
        } else {
            maskFallbackView
        }
    }

    // MARK: - Stroke Replay Mode

    private func strokeReplayView(_ data: CharacterStrokeData) -> some View {
        let glyphPath = PathExtractor.shared.extractPath(for: character, size: size)
        let glyphCGPath = PathExtractor.shared.extractCGPath(for: character, size: size)
        let proportions = strokeProportions(data.strokes)
        let glyphStrokeW = PathExtractor.shared.glyphStrokeWidth(for: character, size: size)
        let revealResult = StrokeRegionBuilder.shared.regions(
            characterKey: characterId ?? character,
            glyphPath: glyphCGPath,
            strokes: data.strokes,
            canvasSize: size,
            glyphStrokeWidth: glyphStrokeW,
            recordingGlyphScale: recordingGlyphScale
        )
        let revealRegions = revealResult.regions
        let debugOverlay = selectedDebugImage(
            from: revealResult.debugArtifacts,
            unclaimedImage: revealResult.unclaimedImage
        )

        return ZStack {
            // Faint outline always visible as guide
            glyphPath.fill(ghostColor)

            // Filled glyph masked by per-pixel arc-length reveal. Once the
            // animation completes, show the plain glyph fill instead: stroke
            // ownership masks can leave a few unclaimed pixels ("dust"), and
            // the unmasked fill guarantees a clean final frame.
            if animationProgress >= 1 {
                glyphPath.fill(inkColor)
            } else {
                glyphPath.fill(inkColor)
                    .mask {
                        Canvas { context, canvasSize in
                            for (index, region) in revealRegions.enumerated() {
                                let strokeProgress = progressForStroke(
                                    index: index,
                                    proportions: proportions
                                )
                                guard strokeProgress > 0 else { continue }

                                let image =
                                    debugShowInstantOwnedRegions
                                    ? region.regionImage
                                    : region.image(for: strokeProgress)
                                let revealed = Image(decorative: image, scale: 1)
                                context.draw(revealed, in: CGRect(origin: .zero, size: canvasSize))
                            }
                        }
                    }
            }

            if let debugOverlay {
                Image(decorative: debugOverlay, scale: 1)
                    .resizable()
                    .frame(width: size.width, height: size.height)
                    .opacity(0.62)
                    .allowsHitTesting(false)
            }

            // Pen-tip indicator
            penTipOverlay(data: data, proportions: proportions)
        }
        .frame(width: size.width, height: size.height)
        .task(id: characterId) { await runAnimationLoop() }
    }

    // MARK: - Pen-Tip Indicator

    @ViewBuilder
    private func penTipOverlay(data: CharacterStrokeData, proportions: [CGFloat]) -> some View {
        if let tip = activeTipPosition(data: data, proportions: proportions) {
            Circle()
                .fill(inkColor.opacity(0.85))
                .frame(width: 8, height: 8)
                .scaleEffect(reduceMotion ? 1 : pulseScale)
                .position(tip)
                .allowsHitTesting(false)
        }
    }

    /// Subtle scale pulse for the pen-tip dot.
    private var pulseScale: CGFloat {
        // Oscillate between 0.8 and 1.2 based on progress
        let phase = animationProgress * 12  // ~6 full cycles over animation
        return 1.0 + 0.2 * sin(phase * .pi)
    }

    /// Returns the current tip position of the actively-animating stroke, or nil if at rest.
    private func activeTipPosition(data: CharacterStrokeData, proportions: [CGFloat]) -> CGPoint? {
        for (index, stroke) in data.strokes.enumerated() {
            let sp = progressForStroke(index: index, proportions: proportions)
            // This stroke is actively animating (partially drawn, not yet complete)
            if sp > 0 && sp < 1 {
                return StrokeSmoother.interpolatePosition(
                    in: remapPoints(stroke.points),
                    at: sp,
                    canvasSize: size
                )
            }
        }
        return nil
    }

    // MARK: - Proportional Stroke Timing

    /// Computes cumulative proportion boundaries from stroke point counts.
    /// A stroke with more points gets a proportionally larger animation window.
    private func strokeProportions(_ strokes: [RecordedStroke]) -> [CGFloat] {
        let counts = strokes.map { CGFloat($0.points.count) }
        let total = counts.reduce(0, +)
        guard total > 0 else { return Array(repeating: 0, count: strokes.count) }

        var cumulative: [CGFloat] = []
        var running: CGFloat = 0
        for count in counts {
            running += count / total
            cumulative.append(running)
        }
        return cumulative
    }

    /// Maps global `animationProgress` (0...1) to a per-stroke progress (0...1)
    /// using proportional timing based on point counts.
    private func progressForStroke(index: Int, proportions: [CGFloat]) -> CGFloat {
        guard !proportions.isEmpty else { return 0 }
        let strokeEnd = proportions[index]
        let strokeStart = index > 0 ? proportions[index - 1] : 0
        let window = strokeEnd - strokeStart
        guard window > 0 else { return 0 }
        return min(max((animationProgress - strokeStart) / window, 0), 1)
    }

    // MARK: - Mask Fallback Mode

    private var maskFallbackView: some View {
        let path = PathExtractor.shared.extractPath(for: character, size: size)

        return ZStack {
            path.fill(ghostColor)

            path.fill(inkColor)
                .mask(alignment: .top) {
                    Rectangle()
                        .frame(height: size.height * animationProgress)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
        }
        .frame(width: size.width, height: size.height)
        .task(id: characterId) { await runAnimationLoop() }
    }

    // MARK: - Task-Based Animation Loop

    private func runAnimationLoop() async {
        animationProgress = 0
        loopCount = 0

        if reduceMotion {
            animationProgress = 1
            try? await Task.sleep(for: .seconds(0.8))
            if Task.isCancelled { return }
            onFinished?()
            return
        }

        let interval: CGFloat = 1.0 / 60.0  // ~60fps
        let increment = interval / totalDuration

        for loop in 0..<maxLoops {
            animationProgress = 0
            loopCount = loop

            while animationProgress < 1.0 {
                try? await Task.sleep(for: .seconds(interval))
                if Task.isCancelled { return }
                animationProgress = min(animationProgress + increment, 1.0)
            }

            // Pause between loops
            if loop < maxLoops - 1 {
                try? await Task.sleep(for: .seconds(0.8))
                if Task.isCancelled { return }
            }
        }

        try? await Task.sleep(for: .seconds(0.35))
        if Task.isCancelled { return }
        onFinished?()
    }

    private var debugShowInstantOwnedRegions: Bool {
        ProcessInfo.processInfo.arguments.contains("-stroke-debug-instant-owned")
    }

    private func selectedDebugImage(
        from artifacts: StrokeRevealDebugArtifacts?,
        unclaimedImage: CGImage?
    ) -> CGImage? {
        guard let artifacts else {
            if ProcessInfo.processInfo.arguments.contains("-stroke-debug-show-unclaimed") {
                return unclaimedImage
            }
            return nil
        }

        if ProcessInfo.processInfo.arguments.contains("-stroke-debug-show-boundary"),
            let boundary = artifacts.ownershipBoundaryImage
        {
            return boundary
        }

        if ProcessInfo.processInfo.arguments.contains("-stroke-debug-show-disputed"),
            let disputed = artifacts.disputedPixelsImage
        {
            return disputed
        }

        if ProcessInfo.processInfo.arguments.contains("-stroke-debug-show-unclaimed"),
            let unclaimedImage
        {
            return unclaimedImage
        }

        if let heatmapIndex = debugIndexArgument("-stroke-debug-heatmap-index"),
            artifacts.progressHeatmaps.indices.contains(heatmapIndex)
        {
            return artifacts.progressHeatmaps[heatmapIndex]
        }

        if let ownedIndex = debugIndexArgument("-stroke-debug-owned-index"),
            artifacts.ownedImages.indices.contains(ownedIndex)
        {
            return artifacts.ownedImages[ownedIndex]
        }

        return nil
    }

    private func debugIndexArgument(_ flag: String) -> Int? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: flag), index + 1 < args.count else {
            return nil
        }

        guard let oneBased = Int(args[index + 1]), oneBased > 0 else {
            return nil
        }

        return oneBased - 1
    }
}
