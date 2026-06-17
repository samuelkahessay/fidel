import SwiftUI
import SwiftData

struct JourneyView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = JourneyViewModel()

    private var progressRepository: ProgressRepository {
        ProgressRepository(modelContext: modelContext)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    FidelScreenHeader(
                        title: "Learn",
                        amharicTitle: "መማር",
                        subtitle: "A guided path from letters and sounds into everyday Amharic."
                    )
                    stageScroller
                    stageHeader
                    nextStageCriteria
                    activitiesSection
                    lockedStagesSection
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.top, AppTheme.Spacing.md)
                .padding(.bottom, AppTheme.Spacing.lg)
            }
            .background(FidelPaperBackground())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $viewModel.showFidelChart) {
                FidelView(embedded: true)
            }
            .navigationDestination(item: $viewModel.selectedLesson) { lesson in
                LessonDetailView(lesson: lesson)
            }
            .navigationDestination(item: $viewModel.selectedConversation) { conversation in
                ConversationDetailView(conversation: conversation)
            }
            .navigationDestination(item: $viewModel.selectedPracticeMode) { mode in
                switch mode {
                case .flashcards:
                    FlashcardView()
                case .quiz:
                    QuizView()
                case .pronunciation:
                    PronunciationPracticeView()
                case .sentenceBuilder:
                    SentenceBuilderView()
                case .wordOrder:
                    WordOrderView()
                case .matchPairs:
                    MatchPairsView()
                case .speedDrill:
                    SpeedDrillView()
                case .tracing:
                    TracingSessionView()
                }
            }
            .sheet(item: $viewModel.tappedLockedStage) { stage in
                LockedStageSheet(stage: stage, progressRepository: progressRepository)
            }
            .fullScreenCover(isPresented: $viewModel.showStageAdvancement) {
                if let stage = viewModel.advancedToStage {
                    StageAdvancementView(stage: stage) {
                        viewModel.showStageAdvancement = false
                    }
                }
            }
            .onAppear {
                configureViewModel()
            }
        }
    }

    private func configureViewModel() {
        let progressRepo = progressRepository
        _ = progressRepo.ensureUserProgress()
        let stageManager = StageManager(progressRepository: progressRepo)
        viewModel.configure(stageManager: stageManager, progressRepository: progressRepo)
        viewModel.checkAdvancement()
    }

    // MARK: - Stage Header

    private var stageScroller: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppTheme.Spacing.md) {
                ForEach(LearningStage.allCases) { stage in
                    Button {
                        handleStageTap(stage)
                    } label: {
                        StagePathTile(
                            stage: stage,
                            isCurrent: stage == viewModel.currentStage,
                            isLocked: viewModel.lockedStages.contains(stage)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!viewModel.lockedStages.contains(stage) && stage != viewModel.currentStage)
                }
            }
            .padding(.horizontal, 1)
        }
    }

    private var stageHeader: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            HStack {
                Image(systemName: viewModel.currentStage.icon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AppTheme.onAccentColor)
                    .frame(width: 52, height: 52)
                    .background(viewModel.currentStage.color, in: RoundedRectangle(cornerRadius: 17, style: .continuous))

                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                    Text(viewModel.currentStage.displayName)
                        .font(AppTheme.Typography.title3)
                        .foregroundStyle(AppTheme.inkColor)
                    Text(viewModel.currentStage.amharicTitle)
                        .font(AppTheme.Typography.amharicDisplay(size: 22, relativeTo: .title2))
                        .foregroundStyle(viewModel.currentStage.color)
                }

                Spacer()

                AccessibleProgressRing(
                    progress: viewModel.progressToNextStage,
                    lineWidth: 4,
                    size: 44,
                    label: "Progress to next stage",
                    valueText: "\(Int((viewModel.progressToNextStage * 100).rounded())) percent"
                )
            }

            Text(viewModel.currentStage.stageDescription)
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(AppTheme.inkSecondaryColor)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fidelDesignCard(padding: AppTheme.Spacing.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(viewModel.currentStage.displayName), \(viewModel.currentStage.stageDescription)")
        .accessibilityValue("\(Int((viewModel.progressToNextStage * 100).rounded())) percent to next stage")
    }

    // MARK: - Next Stage Criteria

    @ViewBuilder
    private var nextStageCriteria: some View {
        if let criteria = viewModel.stageManager?.criteriaForNextStage(),
           !criteria.isEmpty {
            let progress = progressRepository.getUserProgress()
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                FidelSectionLabel(title: "Next stage")

                ForEach(criteria) { criterion in
                    let fraction = progress.map { criterion.progressFraction($0) } ?? 0
                    let isMet = progress.map { criterion.evaluate($0) } ?? false
                    HStack(spacing: AppTheme.Spacing.sm) {
                        Image(systemName: isMet ? "checkmark.circle.fill" : criterion.icon)
                            .foregroundStyle(isMet ? AppTheme.successColor : .secondary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                            Text(criterion.description)
                                .font(AppTheme.Typography.subheadline)
                                .foregroundStyle(isMet ? AppTheme.successColor : AppTheme.inkColor)

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(AppTheme.hairlineColor)
                                        .frame(height: 6)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(isMet ? AppTheme.successColor : viewModel.currentStage.color)
                                        .frame(width: geo.size.width * fraction, height: 6)
                                }
                            }
                            .frame(height: 6)
                            .accessibilityLabel(criterion.description)
                            .accessibilityValue("\(Int((fraction * 100).rounded())) percent")
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityValue(isMet ? "Complete" : "\(Int((fraction * 100).rounded())) percent")
                }
            }
            .fidelDesignCard()
        }
    }

    // MARK: - Activities

    private var activitiesSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            FidelSectionLabel(title: "Unit path")

            ForEach(viewModel.activities) { activity in
                LearningCardButton(
                    accessibilityLabel: "\(activity.title). \(activity.subtitle)",
                    accessibilityHint: "Opens this learning activity"
                ) {
                    handleActivityTap(activity)
                } content: {
                    ActivityCard(activity: activity)
                }
            }
        }
    }

    private func handleActivityTap(_ activity: JourneyActivity) {
        viewModel.selectActivity(activity)
    }

    private func handleStageTap(_ stage: LearningStage) {
        if viewModel.lockedStages.contains(stage) {
            viewModel.tappedLockedStage = stage
        } else if stage == viewModel.currentStage {
            viewModel.selectCurrentStagePrimaryActivity()
        }
    }

    // MARK: - Locked Stages

    @ViewBuilder
    private var lockedStagesSection: some View {
        if !viewModel.lockedStages.isEmpty {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                ForEach(viewModel.lockedStages) { stage in
                    LearningCardButton(
                        accessibilityLabel: "\(stage.displayName). Locked. \(stage.stageDescription)",
                        accessibilityHint: "Shows the requirements to unlock this stage"
                    ) {
                        viewModel.tappedLockedStage = stage
                    } content: {
                        LockedStageCard(stage: stage)
                    }
                }
            }
        }
    }
}

private struct StagePathTile: View {
    let stage: LearningStage
    let isCurrent: Bool
    let isLocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack {
                Image(systemName: isLocked ? "lock.fill" : stage.icon)
                    .font(.headline)
                    .foregroundStyle(isCurrent ? onStageAccent : stage.color)
                    .frame(width: 34, height: 34)
                    .background(
                        isCurrent ? stage.color : stage.color.opacity(0.12),
                        in: Circle()
                    )

                Spacer()

                Text(String(format: "%02d", stage.rawValue + 1))
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.mutedInkColor)
            }

            Text(stage.displayName)
                .font(AppTheme.Typography.subheadline.weight(.semibold))
                .foregroundStyle(isLocked ? AppTheme.mutedInkColor : AppTheme.inkColor)
                .lineLimit(2)
                .frame(width: 126, alignment: .leading)

            Text(stage.amharicTitle)
                .font(AppTheme.Typography.amharicDisplay(size: 18, relativeTo: .headline))
                .foregroundStyle(isLocked ? AppTheme.mutedInkColor : stage.color)
                .lineLimit(1)
        }
        .padding(AppTheme.Spacing.md)
        .frame(width: 160, height: 138, alignment: .topLeading)
        .background(
            isCurrent ? AppTheme.cardColor : AppTheme.paperAccentColor,
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(isCurrent ? stage.color.opacity(0.35) : AppTheme.hairlineColor, lineWidth: 1)
        )
    }

    private var onStageAccent: Color {
        stage == .buildingSentences ? AppTheme.onGoldColor : AppTheme.onAccentColor
    }
}

// MARK: - Activity Card

struct ActivityCard: View {
    let activity: JourneyActivity

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(activity.isCompleted ? AppTheme.eucalyptusColor : activity.color.opacity(0.12))
                    .frame(width: 48, height: 48)

                if activity.isCompleted {
                    Image(systemName: "checkmark")
                        .foregroundStyle(AppTheme.onAccentColor)
                        .font(.body.bold())
                } else {
                    Image(systemName: activity.icon)
                        .foregroundStyle(activity.color)
                        .font(.title3)
                }
            }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text(activity.title)
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.inkColor)

                Text(activity.subtitle)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.inkSecondaryColor)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(AppTheme.mutedInkColor)
        }
        .fidelDesignCard(padding: AppTheme.Spacing.md, cornerRadius: 20)
        .contentShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large))
    }
}

// MARK: - Locked Stage Card

struct LockedStageCard: View {
    let stage: LearningStage

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.inkColor.opacity(0.06))
                    .frame(width: 48, height: 48)

                Image(systemName: "lock.fill")
                    .foregroundStyle(AppTheme.inkSecondaryColor)
                    .font(.title3)
            }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text(stage.displayName)
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.inkSecondaryColor)

                Text(stage.stageDescription)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.mutedInkColor)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundStyle(AppTheme.mutedInkColor)
        }
        .fidelDesignCard(padding: AppTheme.Spacing.md, cornerRadius: 20, background: AppTheme.paperAccentColor)
        .opacity(0.6)
        .contentShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large))
    }
}

// MARK: - Locked Stage Sheet

struct LockedStageSheet: View {
    @Environment(\.dismiss) private var dismiss
    let stage: LearningStage
    let progressRepository: ProgressRepositoryProtocol

    var body: some View {
        NavigationStack {
            VStack(spacing: AppTheme.Spacing.xl) {
                Image(systemName: stage.icon)
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [stage.color, stage.color.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(spacing: AppTheme.Spacing.xs) {
                    Text(stage.displayName)
                        .font(AppTheme.Typography.title2)
                    Text(stage.amharicTitle)
                        .font(AppTheme.Typography.amharic(size: 20))
                        .foregroundStyle(stage.color)
                }

                Text(stage.stageDescription)
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(AppTheme.inkSecondaryColor)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    Text("Requirements")
                        .font(AppTheme.Typography.headline)

                    let criteria = LearningStage.criteria(for: stage)
                    if let progress = progressRepository.getUserProgress() {
                        ForEach(criteria) { criterion in
                            let fraction = criterion.progressFraction(progress)
                            let isMet = criterion.evaluate(progress)
                            HStack(spacing: AppTheme.Spacing.sm) {
                                Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isMet ? AppTheme.successColor : .secondary)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(criterion.description)
                                        .font(AppTheme.Typography.subheadline)

                                    ProgressView(value: fraction)
                                        .tint(isMet ? AppTheme.successColor : stage.color)
                                        .accessibilityLabel(criterion.description)
                                        .accessibilityValue("\(Int((fraction * 100).rounded())) percent")
                                }
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityValue(isMet ? "Complete" : "\(Int((fraction * 100).rounded())) percent")
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard()

                Spacer()
            }
            .padding(AppTheme.Spacing.xl)
            .navigationTitle("Locked Stage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Stage Advancement View

struct StageAdvancementView: View {
    let stage: LearningStage
    let onDismiss: () -> Void

    @State private var animateIn = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: AppTheme.Spacing.xl) {
                Spacer()

                Image(systemName: stage.icon)
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [stage.color, AppTheme.secondaryColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(animateIn ? 1.0 : 0.3)
                    .opacity(animateIn ? 1.0 : 0)

                VStack(spacing: AppTheme.Spacing.sm) {
                    Text("Stage Unlocked!")
                        .font(AppTheme.Typography.largeTitle)
                        .foregroundStyle(AppTheme.onAccentColor)

                    Text(stage.displayName)
                        .font(AppTheme.Typography.title2)
                        .foregroundStyle(stage.color)

                    Text(stage.amharicTitle)
                        .font(AppTheme.Typography.amharic(size: 28))
                        .foregroundStyle(AppTheme.secondaryColor)
                }
                .opacity(animateIn ? 1.0 : 0)

                Text("እንኳን ደስ ያለህ!")
                    .font(AppTheme.Typography.amharic(size: 24))
                    .foregroundStyle(AppTheme.onAccentColor.opacity(0.82))
                    .opacity(animateIn ? 1.0 : 0)

                Spacer()

                Button("Continue") {
                    onDismiss()
                }
                .primaryGlassButton()
                .padding(.horizontal, AppTheme.Spacing.xl)
                .opacity(animateIn ? 1.0 : 0)

                Spacer()
                    .frame(height: 40)
            }
        }
        .onAppear {
            withAnimation(AppTheme.Animation.gentle) {
                animateIn = true
            }
        }
    }
}

#Preview {
    JourneyView()
        .modelContainer(for: [
            UserProgress.self,
            FlashcardProgress.self,
            SelamConversation.self,
            SelamMessage.self
        ], inMemory: true)
}
