import SwiftUI
import PencilKit

struct TracingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = TracingViewModel()

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            if viewModel.showCompletion {
                completionView
            } else if let character = viewModel.currentCharacter {
                progressHeader
                characterInfo(character)
                mainContent(character)
                actionButtons
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Character Tracing")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            let progressRepo = ProgressRepository(modelContext: modelContext)
            viewModel.configure(progressRepository: progressRepo)
            viewModel.startSession()
        }
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        HStack {
            Text(viewModel.progress)
                .font(AppTheme.Typography.headline)
                .foregroundColor(.primary)

            Spacer()

            ProgressRing(
                progress: viewModel.progressFraction,
                lineWidth: 4,
                size: 36
            )
        }
        .padding(.horizontal, AppTheme.Spacing.xs)
    }

    // MARK: - Character Info

    private func characterInfo(_ character: FidelCharacter) -> some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Text(character.character)
                .font(AppTheme.Typography.amharic(size: 56))
                .foregroundColor(.indigo)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text(character.romanization)
                    .font(AppTheme.Typography.title3)
                    .foregroundColor(.primary)
                Text(character.consonant)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .glassCard()
    }

    // MARK: - Main Content Area

    @ViewBuilder
    private func mainContent(_ character: FidelCharacter) -> some View {
        switch viewModel.phase {
        case .watching:
            watchingPhase(character)
        case .drawing:
            drawingPhase(character)
        case .reviewing:
            reviewingPhase(character)
        }
    }

    private func watchingPhase(_ character: FidelCharacter) -> some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Text("Watch the stroke pattern")
                .font(AppTheme.Typography.subheadline)
                .foregroundColor(.secondary)

            StrokeAnimationView(
                character: character.character,
                size: CGSize(width: 280, height: 280),
                characterId: character.id
            )
            .frame(width: 300, height: 300)
            .glassCard()
        }
    }

    private func drawingPhase(_ character: FidelCharacter) -> some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Text("Trace the character")
                .font(AppTheme.Typography.subheadline)
                .foregroundColor(.secondary)

            ZStack {
                // Reference filled guide — clean sans-serif shape to trace over
                PathExtractor.shared.extractPath(
                    for: character.character,
                    size: CGSize(width: 280, height: 280)
                )
                .fill(Color.indigo.opacity(0.12))
                .frame(width: 280, height: 280)

                // Drawing canvas on top
                DrawingCanvasView(drawing: $viewModel.userDrawing)
                    .frame(width: 300, height: 300)
            }
            .frame(width: 300, height: 300)
            .glassCard()

            if viewModel.needsRetry {
                retryPrompt
            }
        }
    }

    private func reviewingPhase(_ character: FidelCharacter) -> some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Text("How did you do?")
                .font(AppTheme.Typography.headline)
                .foregroundColor(.primary)

            HStack(spacing: AppTheme.Spacing.xl) {
                // Reference
                VStack(spacing: AppTheme.Spacing.xs) {
                    Text("Reference")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(.secondary)

                    PathExtractor.shared.extractPath(
                        for: character.character,
                        size: CGSize(width: 120, height: 120)
                    )
                    .fill(Color.indigo.opacity(0.3))
                    .overlay(
                        PathExtractor.shared.extractPath(
                            for: character.character,
                            size: CGSize(width: 120, height: 120)
                        )
                        .stroke(Color.indigo, lineWidth: 1.5)
                    )
                    .frame(width: 130, height: 130)
                    .glassCard(padding: AppTheme.Spacing.xs)
                }

                // User's drawing
                VStack(spacing: AppTheme.Spacing.xs) {
                    Text("Your drawing")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(.secondary)

                    DrawingThumbnailView(drawing: viewModel.userDrawing, size: CGSize(width: 130, height: 130))
                        .frame(width: 130, height: 130)
                        .glassCard(padding: AppTheme.Spacing.xs)
                }
            }

            starRating
        }
    }

    // MARK: - Star Rating

    private var starRating: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Text("Rate your attempt")
                .font(AppTheme.Typography.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: AppTheme.Spacing.lg) {
                ForEach(1...3, id: \.self) { stars in
                    Button {
                        withAnimation(AppTheme.Animation.standard) {
                            viewModel.submitRating(stars: stars)
                        }
                    } label: {
                        VStack(spacing: AppTheme.Spacing.xxs) {
                            HStack(spacing: 2) {
                                ForEach(0..<stars, id: \.self) { _ in
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.yellow)
                                        .font(.body)
                                }
                            }
                            Text(starLabel(stars))
                                .font(AppTheme.Typography.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, AppTheme.Spacing.sm)
                        .padding(.vertical, AppTheme.Spacing.xs)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                                .fill(.ultraThinMaterial)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func starLabel(_ stars: Int) -> String {
        switch stars {
        case 1: return "Hard"
        case 2: return "OK"
        case 3: return "Easy"
        default: return ""
        }
    }

    // MARK: - Retry Prompt

    private var retryPrompt: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Text("Try to follow the outline more closely")
                .font(AppTheme.Typography.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: AppTheme.Spacing.md) {
                Button {
                    withAnimation(AppTheme.Animation.standard) {
                        viewModel.retryDrawing()
                    }
                } label: {
                    Label("Try Again", systemImage: "arrow.counterclockwise")
                        .font(AppTheme.Typography.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, AppTheme.Spacing.lg)
                        .padding(.vertical, AppTheme.Spacing.sm)
                        .background(
                            Capsule().fill(.indigo)
                        )
                }

                Button {
                    withAnimation(AppTheme.Animation.standard) {
                        viewModel.skipCharacter()
                    }
                } label: {
                    Text("Skip")
                        .font(AppTheme.Typography.headline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, AppTheme.Spacing.lg)
                        .padding(.vertical, AppTheme.Spacing.sm)
                        .background(
                            Capsule().fill(Color.primary.opacity(0.06))
                        )
                }
            }
        }
        .glassCard()
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        if !viewModel.needsRetry {
            switch viewModel.phase {
            case .watching:
                Button {
                    withAnimation(AppTheme.Animation.standard) {
                        viewModel.finishWatching()
                    }
                } label: {
                    Label("Start Drawing", systemImage: "pencil.tip")
                        .font(AppTheme.Typography.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppTheme.Spacing.sm)
                        .background(
                            Capsule().fill(.indigo)
                        )
                }
                .padding(.horizontal, AppTheme.Spacing.md)

            case .drawing:
                HStack(spacing: AppTheme.Spacing.md) {
                    Button {
                        viewModel.clearCanvas()
                    } label: {
                        Label("Clear", systemImage: "trash")
                            .font(AppTheme.Typography.headline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppTheme.Spacing.sm)
                            .background(
                                Capsule().fill(Color.primary.opacity(0.06))
                            )
                    }

                    Button {
                        withAnimation(AppTheme.Animation.standard) {
                            viewModel.evaluateDrawing()
                        }
                    } label: {
                        Label("Done", systemImage: "checkmark")
                            .font(AppTheme.Typography.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppTheme.Spacing.sm)
                            .background(
                                Capsule().fill(.indigo)
                            )
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)

            case .reviewing:
                EmptyView()
            }
        }
    }

    // MARK: - Completion View

    private var completionView: some View {
        VStack(spacing: AppTheme.Spacing.xl) {
            AnimatedCheckmark()

            Text("Session Complete!")
                .font(AppTheme.Typography.title)
                .foregroundColor(.primary)

            HStack(spacing: AppTheme.Spacing.xxl) {
                VStack(spacing: AppTheme.Spacing.xxs) {
                    Text("\(viewModel.completedCount)")
                        .font(.system(size: 52, weight: .bold))
                        .foregroundColor(AppTheme.primaryColor)
                    Text("Traced")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(.secondary)
                }

                VStack(spacing: AppTheme.Spacing.xxs) {
                    Text("\(viewModel.skippedCount)")
                        .font(.system(size: 52, weight: .bold))
                        .foregroundColor(.secondary)
                    Text("Skipped")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(.secondary)
                }
            }

            XPBadge(xp: viewModel.earnedXP())
        }
        .glassCard()
    }
}

// MARK: - Drawing Thumbnail

/// Renders a PKDrawing as an image for the review comparison.
private struct DrawingThumbnailView: View {
    let drawing: PKDrawing
    let size: CGSize

    var body: some View {
        Image(uiImage: drawing.image(
            from: CGRect(origin: .zero, size: size),
            scale: 1.0
        ))
        .resizable()
        .aspectRatio(contentMode: .fit)
    }
}

#Preview {
    NavigationStack {
        TracingView()
    }
    .modelContainer(for: [
        UserProgress.self,
        FlashcardProgress.self
    ], inMemory: true)
}
