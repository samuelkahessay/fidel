import SwiftUI

/// Animated character demonstration that reveals a Fidel character.
/// - **Stroke mode**: If recorded stroke data exists, replays strokes sequentially
///   using thick stroke paths as a mask over the filled glyph shape.
/// - **Fallback mode**: Top-to-bottom mask wipe (original behavior).
struct StrokeAnimationView: View {
    let character: String
    let size: CGSize
    var characterId: String? = nil

    @State private var animationProgress: CGFloat = 0
    @State private var loopCount = 0
    @State private var timer: Timer?
    private let maxLoops = 2
    private let totalDuration: CGFloat = 2.0

    private var strokeData: CharacterStrokeData? {
        guard let id = characterId else { return nil }
        return StrokeDataRepository.shared.getStrokeData(for: id)
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

        return ZStack {
            // Faint outline always visible as guide
            glyphPath.fill(Color.indigo.opacity(0.08))

            // Filled glyph masked by thick animated stroke paths
            glyphPath.fill(Color.indigo)
                .mask {
                    Canvas { context, canvasSize in
                        for (index, stroke) in data.strokes.enumerated() {
                            let strokeProgress = progressForStroke(index: index, total: data.strokes.count)
                            guard strokeProgress > 0 else { continue }

                            var path = Path()
                            guard let first = stroke.points.first else { continue }

                            path.move(to: CGPoint(
                                x: first.x * canvasSize.width,
                                y: first.y * canvasSize.height
                            ))

                            for point in stroke.points.dropFirst() {
                                path.addLine(to: CGPoint(
                                    x: point.x * canvasSize.width,
                                    y: point.y * canvasSize.height
                                ))
                            }

                            let trimmed = path.trimmedPath(from: 0, to: strokeProgress)
                            context.stroke(
                                trimmed,
                                with: .color(.white),
                                style: StrokeStyle(lineWidth: 55, lineCap: .round, lineJoin: .round)
                            )
                        }
                    }
                }
        }
        .frame(width: size.width, height: size.height)
        .onAppear { startAnimation() }
        .onDisappear { stopTimer() }
    }

    /// Maps global animationProgress (0...1) to a per-stroke progress (0...1).
    /// Each stroke gets an equal time window; they play sequentially.
    private func progressForStroke(index: Int, total: Int) -> CGFloat {
        guard total > 0 else { return 0 }
        let window = 1.0 / CGFloat(total)
        let strokeStart = CGFloat(index) * window
        return min(max((animationProgress - strokeStart) / window, 0), 1)
    }

    // MARK: - Mask Fallback Mode

    private var maskFallbackView: some View {
        let path = PathExtractor.shared.extractPath(for: character, size: size)

        return ZStack {
            path.fill(Color.indigo.opacity(0.08))

            path.fill(Color.indigo)
                .mask(alignment: .top) {
                    Rectangle()
                        .frame(height: size.height * animationProgress)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
        }
        .frame(width: size.width, height: size.height)
        .onAppear { startAnimation() }
        .onDisappear { stopTimer() }
    }

    // MARK: - Timer-Based Animation Loop

    private func startAnimation() {
        animationProgress = 0
        loopCount = 0
        runLoop()
    }

    private func runLoop() {
        guard loopCount < maxLoops else { return }
        stopTimer()

        animationProgress = 0
        let interval: CGFloat = 1.0 / 60.0 // ~60fps
        let increment = interval / totalDuration

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { t in
            animationProgress += increment
            if animationProgress >= 1.0 {
                animationProgress = 1.0
                t.invalidate()

                // Pause, then start next loop or stop
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    loopCount += 1
                    if loopCount < maxLoops {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            runLoop()
                        }
                    }
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - StrokePath Shape

/// Converts a `RecordedStroke` (normalized 0...1 coordinates) into a SwiftUI `Path`
/// scaled to the given target size.
struct StrokePath: Shape {
    let stroke: RecordedStroke
    let size: CGSize

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = stroke.points.first else { return path }

        path.move(to: CGPoint(
            x: first.x * Double(size.width),
            y: first.y * Double(size.height)
        ))

        for point in stroke.points.dropFirst() {
            path.addLine(to: CGPoint(
                x: point.x * Double(size.width),
                y: point.y * Double(size.height)
            ))
        }

        return path
    }
}
