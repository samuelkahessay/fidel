import SwiftUI
import PencilKit

/// Admin tool for recording stroke data for each Fidel character.
/// Iterates all 238 characters; draw naturally and strokes are auto-separated by PencilKit.
struct StrokeRecorderView: View {
    @State private var viewModel = StrokeRecorderViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let character = viewModel.currentCharacter {
                    progressBar
                    characterInfoSection(character)
                    canvasSection(character)
                    strokeCountIndicator
                    actionButtons
                } else {
                    Text("No characters loaded")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
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
            DrawingCanvasView(drawing: $viewModel.userDrawing)
                .frame(width: size, height: size)

            // Glyph-reveal overlay — shows filled glyph masked by drawn strokes
            Canvas { context, canvasSize in
                let glyphPath = PathExtractor.shared.extractPath(
                    for: character.character,
                    size: canvasSize
                )

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
                        maskContext.stroke(maskPath, with: .color(.white), style: StrokeStyle(lineWidth: 55, lineCap: .round, lineJoin: .round))
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

    // MARK: - Stroke Count

    private var strokeCountIndicator: some View {
        Text(viewModel.strokeCount == 0
            ? "Draw the character above"
            : "\(viewModel.strokeCount) stroke\(viewModel.strokeCount == 1 ? "" : "s")")
            .font(.subheadline)
            .foregroundColor(viewModel.strokeCount == 0 ? .secondary : .primary)
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
