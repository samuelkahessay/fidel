import SwiftUI
import PencilKit

/// Admin tool for recording stroke data for each Fidel character.
/// Iterates all 238 characters; draw naturally and strokes are auto-separated by PencilKit.
struct StrokeRecorderView: View {
    @State private var viewModel = StrokeRecorderViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let horizontalSize = geometry.size.width - 32
                let verticalSize = geometry.size.height - 260
                let canvasSize = min(max(min(horizontalSize, verticalSize), 320), 820)
                ScrollView {
                    VStack(spacing: 12) {
                        if let character = viewModel.currentCharacter {
                            progressBar
                            characterInfoSection(character)
                            canvasSection(character)
                            coverageIndicator
                            penWidthSlider
                            strokeDataInfo
                            actionButtons
                        } else {
                            Text("No characters loaded")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                }
                .onAppear { viewModel.canvasSize = canvasSize }
                .onChange(of: canvasSize) { _, newSize in viewModel.canvasSize = newSize }
            }
            .navigationTitle("Stroke Recorder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(
                        item: viewModel.exportURL,
                        preview: SharePreview("Stroke Data", icon: "square.and.arrow.up")
                    )
                }
            }
            .onAppear { viewModel.load() }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        VStack(spacing: 4) {
            ProgressView(
                value: Double(viewModel.currentIndex),
                total: Double(max(viewModel.totalCount, 1))
            )
            .tint(.indigo)

            HStack {
                Text("\(viewModel.currentIndex + 1) of \(viewModel.totalCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(viewModel.recordedIds.count) recorded")
                    .font(.caption.bold())
                    .foregroundColor(.indigo)
            }
        }
    }

    // MARK: - Character Info

    private func characterInfoSection(_ character: FidelCharacter) -> some View {
        HStack(spacing: 12) {
            Text(character.character)
                .font(AppTheme.Typography.amharic(size: 44))

            VStack(alignment: .leading, spacing: 2) {
                Text(character.romanization)
                    .font(.headline)
                Text("\(character.consonant) — order \(character.vowelOrder)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if viewModel.hasData {
                Label("Recorded", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Canvas

    private func canvasSection(_ character: FidelCharacter) -> some View {
        let size = viewModel.canvasSize

        return ZStack {
            // Drawing canvas — captures touches with faint indigo ink
            DrawingCanvasView(drawing: $viewModel.userDrawing, penWidth: viewModel.penWidth)
                .frame(width: size, height: size)

            // Glyph-reveal overlay — shows filled glyph masked by drawn strokes
            Canvas { context, canvasSize in
                // Generate glyph at reduced size, then offset to center in canvas
                let glyphDim = min(canvasSize.width, canvasSize.height) * viewModel.glyphScale
                let dx = (canvasSize.width - glyphDim) / 2
                let dy = (canvasSize.height - glyphDim) / 2
                let glyphPath = PathExtractor.shared.extractPath(
                    for: character.character,
                    size: CGSize(width: glyphDim, height: glyphDim)
                ).applying(CGAffineTransform(translationX: dx, y: dy))

                // Faint glyph outline for reference
                context.stroke(glyphPath, with: .color(.indigo.opacity(0.08)), lineWidth: 1)

                // Build a mask from all committed PKStrokes
                if !viewModel.userDrawing.strokes.isEmpty {
                    var maskPath = Path()
                    for pkStroke in viewModel.userDrawing.strokes {
                        maskPath.addPath(pathFromPKStroke(pkStroke, in: canvasSize))
                    }

                    // Draw the filled glyph, clipped to the stroke mask
                    context.clipToLayer { maskContext in
                        maskContext.stroke(maskPath, with: .color(.white), style: StrokeStyle(lineWidth: viewModel.maskLineWidth, lineCap: .round, lineJoin: .round))
                    }
                    context.fill(glyphPath, with: .color(.indigo))
                }
            }
            .frame(width: size, height: size)
            .allowsHitTesting(false)
        }
        .frame(width: size, height: size)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.indigo.opacity(0.3), lineWidth: 1)
        )
    }

    /// Convert a PKStroke to a SwiftUI Path using its interpolated points.
    private func pathFromPKStroke(_ pkStroke: PKStroke, in canvasSize: CGSize) -> Path {
        var path = Path()
        let strokePath = pkStroke.path
        guard strokePath.count > 0 else { return path }

        path.move(to: strokePath.interpolatedLocation(at: 0))
        let step: CGFloat = 1.0
        var dist: CGFloat = step
        while dist < CGFloat(strokePath.count - 1) {
            path.addLine(to: strokePath.interpolatedLocation(at: dist))
            dist += step
        }
        path.addLine(to: strokePath.interpolatedLocation(at: CGFloat(strokePath.count - 1)))
        return path
    }

    // MARK: - Coverage Indicator

    private var coverageIndicator: some View {
        HStack(spacing: 8) {
            let pct = Int(viewModel.fillCoverage * 100)
            let color = coverageColor

            ProgressView(value: viewModel.fillCoverage)
                .tint(color)

            Text("\(pct)%")
                .font(.headline.monospacedDigit().bold())
                .foregroundColor(color)
                .frame(width: 50, alignment: .trailing)
        }
    }

    private var coverageColor: Color {
        switch viewModel.fillCoverage {
        case 0.95...: return .green
        case 0.80...: return .orange
        default: return .red
        }
    }

    // MARK: - Pen Width Slider

    private var penWidthSlider: some View {
        HStack(spacing: 8) {
            // Thin line preview
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.indigo)
                .frame(width: 20, height: 2)

            Slider(value: $viewModel.penWidth, in: 8...180, step: 1)
                .tint(.indigo)

            // Thick line preview
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.indigo)
                .frame(width: 20, height: min(max(viewModel.penWidth / 5, 6), 20))

            Text("\(Int(viewModel.penWidth))/\(Int(viewModel.maskLineWidth))")
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
                .frame(width: 68, alignment: .trailing)
        }
    }

    // MARK: - Stroke Data Info

    private var strokeDataInfo: some View {
        VStack(spacing: 4) {
            if viewModel.strokeCount == 0 {
                Text("Draw the character above")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                // Per-stroke point counts
                HStack(spacing: 6) {
                    ForEach(Array(viewModel.strokePointCounts.enumerated()), id: \.offset) { index, count in
                        Text("S\(index + 1): \(count)pts")
                            .font(.caption2.monospacedDigit())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.indigo.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
                .foregroundColor(.indigo)
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button {
                    viewModel.clearCanvas()
                } label: {
                    Label("Clear", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    viewModel.undoLastStroke()
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.strokeCount == 0)
            }

            HStack(spacing: 12) {
                Button {
                    viewModel.skip()
                } label: {
                    Text("Skip")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    viewModel.saveAndNext()
                } label: {
                    Label("Save & Next", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .disabled(viewModel.strokeCount == 0)
            }
        }
    }
}

#if DEBUG
#Preview {
    StrokeRecorderView()
}
#endif
