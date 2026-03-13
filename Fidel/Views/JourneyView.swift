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
            ScrollView {
                VStack(spacing: AppTheme.Spacing.xl) {
                    stageHeader
                    nextStageCriteria
                    activitiesSection
                    lockedStagesSection
                }
                .padding(AppTheme.Spacing.md)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Journey")
            .sheet(isPresented: $viewModel.showFidelChart) {
                FidelView()
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
                case .speedDrill:
                    SpeedDrillView()
                case .tracing:
                    TracingView()
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
    }

    // MARK: - Stage Header

    private var stageHeader: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            HStack {
                Image(systemName: viewModel.currentStage.icon)
                    .font(.title2)
                    .foregroundStyle(viewModel.currentStage.color)

                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                    Text(viewModel.currentStage.displayName)
                        .font(AppTheme.Typography.title3)
                        .foregroundStyle(.primary)
                    Text(viewModel.currentStage.amharicTitle)
                        .font(AppTheme.Typography.amharic(size: 18))
                        .foregroundStyle(viewModel.currentStage.color)
                }

                Spacer()

                ProgressRing(
                    progress: viewModel.progressToNextStage,
                    lineWidth: 4,
                    size: 44
                )
            }

            Text(viewModel.currentStage.stageDescription)
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .tintedGlassCard(tint: viewModel.currentStage.color, tintOpacity: 0.06)
    }

    // MARK: - Next Stage Criteria

    @ViewBuilder
    private var nextStageCriteria: some View {
        if let criteria = viewModel.stageManager?.criteriaForNextStage(),
           !criteria.isEmpty {
            let progress = progressRepository.getUserProgress()
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text("Next Stage")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(.primary)

                ForEach(criteria) { criterion in
                    let fraction = progress.map { criterion.progressFraction($0) } ?? 0
                    let isMet = progress.map { criterion.evaluate($0) } ?? false
                    HStack(spacing: AppTheme.Spacing.sm) {
                        Image(systemName: isMet ? "checkmark.circle.fill" : criterion.icon)
                            .foregroundStyle(isMet ? .green : .secondary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                            Text(criterion.description)
                                .font(AppTheme.Typography.subheadline)
                                .foregroundStyle(isMet ? .green : .primary)

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.primary.opacity(0.08))
                                        .frame(height: 6)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(isMet ? Color.green : viewModel.currentStage.color)
                                        .frame(width: geo.size.width * fraction, height: 6)
                                }
                            }
                            .frame(height: 6)
                        }
                    }
                }
            }
            .glassCard()
        }
    }

    // MARK: - Activities

    private var activitiesSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("Activities")
                .font(AppTheme.Typography.title2)
                .foregroundStyle(.primary)

            ForEach(viewModel.activities) { activity in
                Button { handleActivityTap(activity) } label: {
                    ActivityCard(activity: activity)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func handleActivityTap(_ activity: JourneyActivity) {
        switch activity.type {
        case .fidel:
            viewModel.showFidelChart = true
        case .lesson(let id):
            let lessons = LessonRepository.shared.getLessons()
            viewModel.selectedLesson = lessons.first(where: { $0.id == id })
        case .practiceMode(let mode):
            viewModel.selectedPracticeMode = mode
        case .conversation(let id):
            let conversations = LessonRepository.shared.getConversations()
            viewModel.selectedConversation = conversations.first(where: { $0.id == id })
        }
    }

    // MARK: - Locked Stages

    @ViewBuilder
    private var lockedStagesSection: some View {
        if !viewModel.lockedStages.isEmpty {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                ForEach(viewModel.lockedStages) { stage in
                    Button { viewModel.tappedLockedStage = stage } label: {
                        LockedStageCard(stage: stage)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Activity Card

struct ActivityCard: View {
    let activity: JourneyActivity

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(activity.isCompleted ? AppTheme.primaryColor : activity.color.opacity(0.12))
                    .frame(width: 48, height: 48)

                if activity.isCompleted {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.white)
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
                    .foregroundStyle(.primary)

                Text(activity.subtitle)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .glassCard()
    }
}

// MARK: - Locked Stage Card

struct LockedStageCard: View {
    let stage: LearningStage

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 48, height: 48)

                Image(systemName: "lock.fill")
                    .foregroundStyle(.secondary)
                    .font(.title3)
            }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text(stage.displayName)
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(.secondary)

                Text(stage.stageDescription)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary.opacity(0.7))
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .glassCard()
        .opacity(0.6)
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
                    .foregroundStyle(.secondary)
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
                                    .foregroundStyle(isMet ? .green : .secondary)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(criterion.description)
                                        .font(AppTheme.Typography.subheadline)

                                    ProgressView(value: fraction)
                                        .tint(isMet ? .green : stage.color)
                                }
                            }
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
                        .foregroundStyle(.white)

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
                    .foregroundStyle(.white.opacity(0.8))
                    .opacity(animateIn ? 1.0 : 0)

                Spacer()

                Button("Continue") {
                    onDismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, AppTheme.Spacing.xl)
                .opacity(animateIn ? 1.0 : 0)

                Spacer()
                    .frame(height: 40)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
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
