import SwiftUI

/// Guided character writing practice: watch the stroke order once, then trace
/// the character stroke by stroke with live ink, gentle misses, and an
/// auto-advancing celebration. Replaces the old watch/draw/review flow.
struct TracingSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel = TracingSessionViewModel()
    @State private var replayToken = 0

    var plan: TraceSessionPlan = .standard

    var body: some View {
        ZStack {
            AppTheme.groupedBackground.ignoresSafeArea()

            if viewModel.showCompletion {
                ScrollView {
                    completionView
                        .padding(AppTheme.Spacing.md)
                }
            } else if let item = viewModel.currentItem {
                VStack(spacing: AppTheme.Spacing.md) {
                    progressHeader
                    characterCard(item)
                    canvasArea(item)
                    Spacer(minLength: 0)
                    footer(item)
                }
                .padding(AppTheme.Spacing.md)
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .fidelTabBarHidden()
        .navigationTitle("Character Tracing")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            let progressRepo = ProgressRepository(modelContext: modelContext)
            viewModel.configure(progressRepository: progressRepo)
            viewModel.startSession(plan: plan)
        }
    }

    // MARK: - Header

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

    private func characterCard(_ item: TracingSessionViewModel.SessionItem) -> some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Text(item.character.character)
                .font(AppTheme.Typography.amharic(size: 44))
                .foregroundStyle(AppTheme.practiceColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.character.romanization)
                    .font(AppTheme.Typography.title3)
                    .foregroundStyle(AppTheme.inkColor)
                Text(item.character.consonant)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.inkSecondaryColor)
            }

            Spacer()

            if viewModel.itemPhase == .tracing {
                Button {
                    replayToken += 1
                    viewModel.rewatchDemo()
                } label: {
                    Image(systemName: "play.circle")
                        .font(.title3)
                        .foregroundStyle(AppTheme.practiceColor)
                        .frame(width: 36, height: 36)
                        .background(AppTheme.practiceColor.opacity(0.10), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Watch the stroke order again")
            }
        }
        .glassCard(padding: AppTheme.Spacing.sm)
    }

    // MARK: - Canvas

    @ViewBuilder
    private func canvasArea(_ item: TracingSessionViewModel.SessionItem) -> some View {
        AdaptivePracticeCanvas(
            idealSize: TracingLayout.canvasSize,
            onSizeChange: viewModel.updateCanvasSize
        ) { canvasSize in
            ZStack {
                switch viewModel.itemPhase {
                case .watching:
                    StrokeAnimationView(
                        character: item.character.character,
                        size: canvasSize,
                        characterId: item.character.id,
                        maxLoops: 1,
                        onFinished: {
                            withAnimation(AppTheme.Animation.standard) {
                                viewModel.finishWatching()
                            }
                        }
                    )
                    .id("\(item.character.id)-\(replayToken)-\(Int(canvasSize.width))")
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(AppTheme.Animation.standard) {
                            viewModel.finishWatching()
                        }
                    }
                    .accessibilityLabel("Animated stroke order for \(item.character.character)")
                    .accessibilityHint("Double tap to skip ahead and start tracing")

                case .tracing, .celebrating:
                    GuidedTracingCanvas(
                        character: item.character.character,
                        characterId: item.character.id,
                        size: canvasSize,
                        guideLevel: item.level >= 2 ? .faint : .full,
                        fillColor: viewModel.itemPhase == .celebrating
                            ? AppTheme.successColor
                            : AppTheme.practiceColor,
                        engine: viewModel.engine
                    )
                    .allowsHitTesting(viewModel.itemPhase == .tracing)
                }
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
            .background(AdaptiveCardBackground())
            .scaleEffect(viewModel.itemPhase == .celebrating && !reduceMotion ? 1.05 : 1.0)
            .animation(reduceMotion ? nil : AppTheme.Animation.standard, value: viewModel.itemPhase)
        }
        .task(id: celebrationTaskKey) {
            guard viewModel.itemPhase == .celebrating else { return }
            try? await Task.sleep(for: .seconds(0.75))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : AppTheme.Animation.standard) {
                viewModel.advanceAfterCelebration()
            }
        }
    }

    private var celebrationTaskKey: String {
        "\(viewModel.currentIndex)-\(viewModel.itemPhase == .celebrating)"
    }

    // MARK: - Footer

    @ViewBuilder
    private func footer(_ item: TracingSessionViewModel.SessionItem) -> some View {
        switch viewModel.itemPhase {
        case .watching:
            Button {
                withAnimation(AppTheme.Animation.standard) {
                    viewModel.finishWatching()
                }
            } label: {
                Label("Trace it", systemImage: "pencil.tip")
            }
            .buttonStyle(PrimaryButtonStyle(isFullWidth: true))

        case .tracing:
            HStack {
                Spacer()
                Button {
                    withAnimation(AppTheme.Animation.standard) {
                        viewModel.skipCharacter()
                    }
                } label: {
                    Label("Skip", systemImage: "forward.fill")
                        .font(AppTheme.Typography.subheadline)
                        .foregroundStyle(AppTheme.inkSecondaryColor)
                }
                .buttonStyle(.plain)
                .frame(minHeight: 44)
                .accessibilityHint("Skips this character without tracing it")
                Spacer()
            }

        case .celebrating:
            // Keeps the footer height stable while celebrating.
            Color.clear.frame(height: 44)
        }
    }

    // MARK: - Completion

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

                if viewModel.skippedCount > 0 {
                    VStack(spacing: AppTheme.Spacing.xxs) {
                        Text("\(viewModel.skippedCount)")
                            .font(.system(size: 52, weight: .bold))
                            .foregroundStyle(AppTheme.inkSecondaryColor)
                        Text("Skipped")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.inkSecondaryColor)
                    }
                }
            }

            XPBadge(xp: viewModel.sessionXP)
        }
        .glassCard()
    }
}

#Preview {
    NavigationStack {
        TracingSessionView()
    }
    .modelContainer(for: [
        UserProgress.self,
        FlashcardProgress.self
    ], inMemory: true)
}
