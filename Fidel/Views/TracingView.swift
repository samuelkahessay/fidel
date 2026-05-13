import SwiftUI
import PencilKit

struct TracingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = TracingViewModel()
    @State private var replayToken = 0

    var body: some View {
        ZStack {
            AppTheme.groupedBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    if viewModel.showCompletion {
                        completionView
                    } else if let character = viewModel.currentCharacter {
                        progressHeader
                        characterInfo(character)
                        mainContent(character)
                    }
                }
                .padding(AppTheme.Spacing.md)
                .padding(.bottom, bottomContentPadding)
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .fidelTabBarHidden()
        .safeAreaInset(edge: .bottom) {
            if !viewModel.showCompletion, viewModel.currentCharacter != nil {
                bottomControls
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.top, AppTheme.Spacing.sm)
                    .padding(.bottom, AppTheme.Spacing.xs)
                    .background(.ultraThinMaterial)
            }
        }
        .navigationTitle("Character Tracing")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            let progressRepo = ProgressRepository(modelContext: modelContext)
            viewModel.configure(progressRepository: progressRepo)
            viewModel.startSession()
        }
    }

    private var bottomContentPadding: CGFloat {
        if viewModel.showCompletion { return AppTheme.Spacing.lg }
        return viewModel.needsRetry ? 150 : 86
    }

    @ViewBuilder
    private var bottomControls: some View {
        if viewModel.needsRetry {
            retryPrompt
        } else {
            actionButtons
        }
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        HStack {
            Text(viewModel.progress)
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.inkColor)

            Spacer()

            AccessibleProgressRing(
                progress: viewModel.progressFraction,
                lineWidth: 4,
                size: 36,
                label: "Tracing session progress",
                valueText: viewModel.progress
            )
        }
        .padding(.horizontal, AppTheme.Spacing.xs)
    }

    // MARK: - Character Info

    private func characterInfo(_ character: FidelCharacter) -> some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Text(character.character)
                .font(AppTheme.Typography.amharic(size: 56))
                .foregroundStyle(AppTheme.practiceColor)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text(character.romanization)
                    .font(AppTheme.Typography.title3)
                    .foregroundStyle(AppTheme.inkColor)
                Text(character.consonant)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.inkSecondaryColor)
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
        VStack(spacing: AppTheme.Spacing.md) {
            HStack {
                Text("Watch the stroke order")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.inkColor)

                Spacer()

                Button {
                    replayToken += 1
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.headline)
                        .foregroundStyle(AppTheme.practiceColor)
                        .frame(width: 36, height: 36)
                        .background(AppTheme.practiceColor.opacity(0.10), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Replay stroke order")
            }

            AdaptivePracticeCanvas(
                idealSize: TracingLayout.canvasSize,
                onSizeChange: viewModel.updateCanvasSize
            ) { canvasSize in
                StrokeAnimationView(
                    character: character.character,
                    size: canvasSize,
                    characterId: character.id
                )
                .id("\(character.id)-\(replayToken)-\(Int(canvasSize.width))")
                .frame(width: canvasSize.width, height: canvasSize.height)
                .background(AdaptiveCardBackground())
                .accessibilityLabel("Animated stroke order for \(character.character)")
            }
        }
    }

    private func drawingPhase(_ character: FidelCharacter) -> some View {
        VStack(spacing: AppTheme.Spacing.md) {
            HStack {
                Text("Trace the character")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.inkColor)
                Spacer()
                Text(viewModel.hasDrawing ? "Ready" : "Draw first")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(viewModel.hasDrawing ? AppTheme.primaryColor : AppTheme.inkSecondaryColor)
                    .padding(.horizontal, AppTheme.Spacing.sm)
                    .padding(.vertical, AppTheme.Spacing.xxs)
                    .background(
                        Capsule().fill((viewModel.hasDrawing ? AppTheme.primaryColor : AppTheme.inkColor).opacity(0.08))
                    )
            }

            AdaptivePracticeCanvas(
                idealSize: TracingLayout.canvasSize,
                onSizeChange: viewModel.updateCanvasSize
            ) { canvasSize in
                let guidePath = PathExtractor.shared.extractPath(
                    for: character.character,
                    size: canvasSize
                )

                ZStack {
                    guidePath
                        .fill(AppTheme.practiceColor.opacity(0.10))

                    guidePath
                        .stroke(AppTheme.practiceColor.opacity(0.22), lineWidth: 1.5)

                    DrawingCanvasView(drawing: $viewModel.userDrawing)
                        .frame(width: canvasSize.width, height: canvasSize.height)
                        .accessibilityLabel("Tracing canvas for \(character.character)")
                        .accessibilityHint("Draw over the guide, then use Check")
                }
                .frame(width: canvasSize.width, height: canvasSize.height)
                .background(AdaptiveCardBackground())
            }

        }
    }

    private func reviewingPhase(_ character: FidelCharacter) -> some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Text("How did you do?")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.inkColor)

            Text(viewModel.reviewMessage)
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(AppTheme.inkSecondaryColor)

            HStack(spacing: AppTheme.Spacing.md) {
                VStack(spacing: AppTheme.Spacing.xs) {
                    Text("Reference")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.inkSecondaryColor)

                    let referencePath = PathExtractor.shared.extractPath(
                        for: character.character,
                        size: TracingLayout.reviewThumbnailSize
                    )
                    referencePath
                        .fill(AppTheme.practiceColor.opacity(0.20))
                        .overlay(referencePath.stroke(AppTheme.practiceColor.opacity(0.55), lineWidth: 1.5))
                        .frame(width: TracingLayout.reviewThumbnailSize.width, height: TracingLayout.reviewThumbnailSize.height)
                    .glassCard(padding: AppTheme.Spacing.xs)
                    .accessibilityLabel("Reference drawing")
                }

                VStack(spacing: AppTheme.Spacing.xs) {
                    Text("Your drawing")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.inkSecondaryColor)

                    DrawingThumbnailView(
                        drawing: viewModel.userDrawing,
                        sourceCanvasSize: viewModel.canvasSize,
                        outputSize: TracingLayout.reviewThumbnailSize
                    )
                        .frame(width: TracingLayout.reviewThumbnailSize.width, height: TracingLayout.reviewThumbnailSize.height)
                        .glassCard(padding: AppTheme.Spacing.xs)
                        .accessibilityLabel("Your drawing")
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
                .foregroundStyle(AppTheme.inkSecondaryColor)

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
                                        .foregroundStyle(AppTheme.goldColor)
                                        .font(.body)
                                }
                            }
                            Text(starLabel(stars))
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.inkSecondaryColor)
                        }
                        .padding(.horizontal, AppTheme.Spacing.sm)
                        .padding(.vertical, AppTheme.Spacing.xs)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                                .fill(.ultraThinMaterial)
                        )
                    }
                    .buttonStyle(.plain)
                    .frame(minWidth: 68, minHeight: 44)
                    .accessibilityLabel(starLabel(stars))
                    .accessibilityHint("Rates this tracing attempt \(stars) out of 3")
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
            Text(viewModel.retryMessage)
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(AppTheme.inkColor)
                .multilineTextAlignment(.center)

            HStack(spacing: AppTheme.Spacing.md) {
                Button {
                    withAnimation(AppTheme.Animation.standard) {
                        viewModel.retryDrawing()
                    }
                } label: {
                    Label("Try Again", systemImage: "arrow.counterclockwise")
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(AppTheme.onAccentColor)
                        .padding(.horizontal, AppTheme.Spacing.lg)
                        .padding(.vertical, AppTheme.Spacing.sm)
                        .background(
                            Capsule().fill(AppTheme.practiceColor)
                        )
                }

                Button {
                    withAnimation(AppTheme.Animation.standard) {
                        viewModel.skipCharacter()
                    }
                } label: {
                    Label("Skip", systemImage: "forward.fill")
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(AppTheme.inkSecondaryColor)
                        .padding(.horizontal, AppTheme.Spacing.lg)
                        .padding(.vertical, AppTheme.Spacing.sm)
                        .background(
                            Capsule().fill(AppTheme.surfaceColor)
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
                        .foregroundStyle(AppTheme.onAccentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppTheme.Spacing.sm)
                        .background(
                            Capsule().fill(AppTheme.practiceColor)
                        )
                }

            case .drawing:
                HStack(spacing: AppTheme.Spacing.md) {
                    Button {
                        viewModel.clearCanvas()
                    } label: {
                        Label("Clear", systemImage: "trash")
                            .font(AppTheme.Typography.headline)
                            .foregroundStyle(AppTheme.inkSecondaryColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppTheme.Spacing.sm)
                            .background(
                                Capsule().fill(AppTheme.surfaceColor)
                            )
                    }
                    .disabled(!viewModel.hasDrawing)
                    .opacity(viewModel.hasDrawing ? 1 : 0.55)

                    Button {
                        withAnimation(AppTheme.Animation.standard) {
                            viewModel.evaluateDrawing()
                        }
                    } label: {
                        Label("Check", systemImage: "checkmark")
                            .font(AppTheme.Typography.headline)
                            .foregroundStyle(AppTheme.onAccentColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppTheme.Spacing.sm)
                            .background(
                                Capsule().fill(AppTheme.practiceColor.opacity(viewModel.hasDrawing ? 1 : 0.45))
                            )
                    }
                    .disabled(!viewModel.hasDrawing)
                }

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
                .foregroundStyle(AppTheme.inkColor)

            HStack(spacing: AppTheme.Spacing.xxl) {
                VStack(spacing: AppTheme.Spacing.xxs) {
                    Text("\(viewModel.completedCount)")
                        .font(.system(size: 52, weight: .bold))
                        .foregroundStyle(AppTheme.primaryColor)
                    Text("Traced")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.inkSecondaryColor)
                }

                VStack(spacing: AppTheme.Spacing.xxs) {
                    Text("\(viewModel.skippedCount)")
                        .font(.system(size: 52, weight: .bold))
                        .foregroundStyle(AppTheme.inkSecondaryColor)
                    Text("Skipped")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.inkSecondaryColor)
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
    let sourceCanvasSize: CGSize
    let outputSize: CGSize

    var body: some View {
        Image(uiImage: TracingDrawingRenderer.thumbnail(
            from: drawing,
            sourceCanvasSize: sourceCanvasSize,
            outputSize: outputSize
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
