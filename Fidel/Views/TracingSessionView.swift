import SwiftData
import SwiftUI
import SyncKit

/// Guided character writing practice: watch the stroke order once, then trace
/// the character stroke by stroke with live ink, gentle misses, and an
/// auto-advancing celebration. Replaces the old watch/draw/review flow.
struct TracingSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncEngine.self) private var sync
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
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
            let progressRepo = ProgressRepository(modelContext: modelContext, onMutation: { sync.markPending($0) })
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

            Text(levelLabel(item.level))
                .font(AppTheme.Typography.caption2.weight(.semibold))
                .foregroundStyle(AppTheme.practiceColor)
                .padding(.horizontal, AppTheme.Spacing.xs)
                .padding(.vertical, AppTheme.Spacing.xxs)
                .background(
                    Capsule().fill(AppTheme.practiceColor.opacity(0.10))
                )
                .accessibilityLabel("Practice level: \(levelLabel(item.level))")

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

    private func levelLabel(_ level: Int) -> String {
        switch level {
        case 1: return "Guided"
        case 2: return "Faint guide"
        default: return "From memory"
        }
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
                        inkColor: AppTheme.traceInkColor,
                        ghostColor: AppTheme.traceChannelColor,
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

                case .tracing:
                    GuidedTracingCanvas(
                        character: item.character.character,
                        characterId: item.character.id,
                        size: canvasSize,
                        guideLevel: item.level >= 2 && !viewModel.usedGuideAssist ? .faint : .full,
                        fillColor: AppTheme.traceInkColor,
                        engine: viewModel.engine
                    )

                case .memoryDrawing:
                    memoryCanvas(item, canvasSize: canvasSize)

                case .celebrating:
                    celebrationCanvas(item, canvasSize: canvasSize)
                }
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
            .background(TraceSlateBackground())
            .scaleEffect(viewModel.itemPhase == .celebrating && !reduceMotion ? 1.05 : 1.0)
            .animation(reduceMotion ? nil : AppTheme.Animation.standard, value: viewModel.itemPhase)
        }
        .task(id: celebrationTaskKey) {
            guard viewModel.itemPhase == .celebrating else { return }
            // Prewarm the next character's reveal regions while the success
            // state is on screen, then auto-advance after a brief pause so
            // the learner doesn't have to tap Continue on every character.
            viewModel.prewarmNextCharacter()
            let pause: Duration = reduceMotion ? .seconds(1.6) : .milliseconds(900)
            try? await Task.sleep(for: pause)
            guard !Task.isCancelled, viewModel.itemPhase == .celebrating else { return }
            if UIAccessibility.isVoiceOverRunning { return }  // VoiceOver advances via the button
            viewModel.advanceAfterCelebration()
        }
    }

    private var celebrationTaskKey: String {
        "\(viewModel.currentIndex)-\(viewModel.itemPhase == .celebrating)"
    }

    /// Level 3: blank canvas, no ghost. The learner writes from memory and
    /// the shape evaluator checks the result.
    private func memoryCanvas(_ item: TracingSessionViewModel.SessionItem, canvasSize: CGSize) -> some View {
        ZStack {
            Text("Write \(item.character.romanization) from memory")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.traceInkColor.opacity(0.55))
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, AppTheme.Spacing.sm)
                .opacity(viewModel.hasMemoryDrawing ? 0 : 1)

            DrawingCanvasView(
                drawing: $viewModel.userDrawing,
                inkColor: AppTheme.traceInkUIColor
            )
            .frame(width: canvasSize.width, height: canvasSize.height)
            .accessibilityLabel("Writing canvas for \(item.character.character)")
            .accessibilityHint("Write the character from memory, then use Check")
        }
    }

    /// Completed character: clean filled glyph with a sparkle burst; for the
    /// memory level, the learner's own writing is overlaid for comparison.
    private func celebrationCanvas(_ item: TracingSessionViewModel.SessionItem, canvasSize: CGSize) -> some View {
        let glyphPath = PathExtractor.shared.extractPath(for: item.character.character, size: canvasSize)

        return ZStack {
            glyphPath.fill(AppTheme.successColor)

            if item.level >= 3, viewModel.hasMemoryDrawing {
                Image(
                    uiImage: TracingDrawingRenderer.thumbnail(
                        from: viewModel.userDrawing,
                        sourceCanvasSize: viewModel.canvasSize,
                        outputSize: canvasSize
                    )
                )
                .resizable()
                .scaledToFit()
                .opacity(0.4)
            }

            TraceCelebrationView(size: canvasSize)
        }
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
            .primaryGlassButton(fullWidth: true)

        case .tracing:
            HStack {
                Spacer()
                skipButton
                Spacer()
            }

        case .memoryDrawing:
            VStack(spacing: AppTheme.Spacing.sm) {
                if viewModel.memoryRetryReason != nil {
                    Text(viewModel.memoryRetryMessage)
                        .font(AppTheme.Typography.subheadline)
                        .foregroundStyle(AppTheme.inkColor)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: AppTheme.Spacing.md) {
                    Button {
                        viewModel.clearMemoryDrawing()
                    } label: {
                        Label("Clear", systemImage: "trash")
                    }
                    .secondaryGlassButton(fullWidth: true)
                    .disabled(!viewModel.hasMemoryDrawing)
                    .opacity(viewModel.hasMemoryDrawing ? 1 : 0.55)

                    Button {
                        withAnimation(AppTheme.Animation.standard) {
                            viewModel.evaluateMemoryDrawing()
                        }
                    } label: {
                        Label("Check", systemImage: "checkmark")
                    }
                    .primaryGlassButton(fullWidth: true)
                    .disabled(!viewModel.hasMemoryDrawing)
                    .opacity(viewModel.hasMemoryDrawing ? 1 : 0.7)
                }

                HStack(spacing: AppTheme.Spacing.xl) {
                    Button {
                        withAnimation(AppTheme.Animation.standard) {
                            viewModel.showGuideAssist()
                        }
                    } label: {
                        Label("Show guide", systemImage: "eye")
                            .font(AppTheme.Typography.subheadline)
                            .foregroundStyle(AppTheme.practiceColor)
                    }
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
                    .accessibilityHint("Switches to guided tracing for this character")

                    skipButton
                }
            }

        case .celebrating:
            Button {
                withAnimation(reduceMotion ? nil : AppTheme.Animation.standard) {
                    viewModel.advanceAfterCelebration()
                }
            } label: {
                let isLast = viewModel.currentIndex >= viewModel.items.count - 1
                Label(isLast ? "Finish" : "Continue", systemImage: isLast ? "checkmark" : "arrow.right")
            }
            .primaryGlassButton(fullWidth: true)
            .accessibilityHint("Goes to the next character")
        }
    }

    private var skipButton: some View {
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
        .accessibilityHint("Skips this character")
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

            VStack(spacing: AppTheme.Spacing.sm) {
                // The adaptive session keeps composing fresh batches from live
                // mastery, so let learners stay in the loop toward the 50-char
                // goal instead of popping out after every 8 characters.
                if case .standard = plan {
                    Button {
                        withAnimation(AppTheme.Animation.standard) {
                            viewModel.startSession(plan: plan)
                        }
                    } label: {
                        Label("Keep practicing", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .primaryGlassButton(fullWidth: true)
                }

                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .frame(maxWidth: .infinity)
                }
                .secondaryGlassButton(fullWidth: true)
            }
            .padding(.top, AppTheme.Spacing.xs)
        }
        .glassCard()
    }
}

#Preview {
    NavigationStack {
        TracingSessionView()
    }
    .modelContainer(
        for: [
            UserProgress.self,
            FlashcardProgress.self,
            CharacterTraceMastery.self,
        ], inMemory: true)
}
