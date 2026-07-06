import SwiftUI
import SwiftData
import SyncKit

struct JourneyView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncEngine.self) private var sync
    @State private var viewModel = JourneyViewModel()

    private var progressRepository: ProgressRepository {
        ProgressRepository(modelContext: modelContext, onMutation: { sync.markPending($0) })
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
                    recommendedHeroSection
                    openPathSection
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
                case .cloze:
                    ClozeView()
                case .grammar:
                    GrammarExplainerView()
                case .reading:
                    ReadingView()
                case .matchPairs:
                    MatchPairsView()
                case .speedDrill:
                    SpeedDrillView()
                case .tracing:
                    TracingSessionView()
                }
            }
            .onAppear {
                configureViewModel()
            }
            // A tracing session / lesson / quiz is a navigationDestination push;
            // popping back does NOT re-fire .onAppear, so re-evaluate progress
            // (and refresh the mastery rings) whenever a navigation binding clears.
            .onChange(of: viewModel.selectedPracticeMode) { _, value in
                if value == nil { refreshAfterReturn() }
            }
            .onChange(of: viewModel.selectedLesson) { _, value in
                if value == nil { refreshAfterReturn() }
            }
            .onChange(of: viewModel.selectedConversation) { _, value in
                if value == nil { refreshAfterReturn() }
            }
            .onChange(of: viewModel.showFidelChart) { _, value in
                if value == false { refreshAfterReturn() }
            }
        }
    }

    private func refreshAfterReturn() {
        viewModel.refresh()
    }

    private func configureViewModel() {
        let progressRepo = progressRepository
        _ = progressRepo.ensureUserProgress()
        let stageManager = StageManager(progressRepository: progressRepo)
        viewModel.configure(stageManager: stageManager, progressRepository: progressRepo, modelContext: modelContext)
    }

    // MARK: - Recommended Hero

    @ViewBuilder
    private var recommendedHeroSection: some View {
        if let session = viewModel.recommendedSession {
            RecommendedHeroCard(session: session) {
                viewModel.performHeroAction(session.heroAction)
            }
        }
    }

    // MARK: - Open Path

    private var openPathSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
            ForEach(viewModel.pathSections) { section in
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    pathSectionHeader(section)

                    if section.items.isEmpty {
                        // Script & Sounds leads the path but owns no lessons — its
                        // content is Fidel tracing/chart, surfaced here as an entry.
                        scriptIntroCard
                    } else {
                        ForEach(section.items) { item in
                            pathLessonRow(item)
                        }
                    }
                }
            }
        }
    }

    private func pathSectionHeader(_ section: JourneyPathSection) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.sm) {
            Text(section.title)
                .font(AppTheme.Typography.title3)
                .foregroundStyle(AppTheme.inkColor)
            Text(section.amharicTitle)
                .font(AppTheme.Typography.amharicDisplay(size: 18, relativeTo: .headline))
                .foregroundStyle(AppTheme.terracottaColor)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .accessibilityLabel("\(section.title), \(section.amharicTitle)")
    }

    private func pathLessonRow(_ item: JourneyLessonItem) -> some View {
        LearningCardButton(
            accessibilityLabel: pathAccessibilityLabel(item),
            accessibilityHint: "Opens this lesson"
        ) {
            viewModel.selectedLesson = item.lesson
        } content: {
            PathLessonCard(item: item)
        }
    }

    private var scriptIntroCard: some View {
        LearningCardButton(
            accessibilityLabel: "Practice Fidel. Trace characters and explore the chart.",
            accessibilityHint: "Opens Fidel practice"
        ) {
            viewModel.performHeroAction(.practiceTracing)
        } content: {
            ScriptIntroCard()
        }
    }

    private func pathAccessibilityLabel(_ item: JourneyLessonItem) -> String {
        var label = "\(item.lesson.title). \(item.masteryTier.label)"
        if item.isCompleted {
            label += ". Completed"
        }
        label += ". \(Int((item.masteryFraction * 100).rounded())) percent mastery"
        return label
    }
}

// MARK: - Recommended Hero Card

private struct RecommendedHeroCard: View {
    let session: RecommendedSession
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text(session.eyebrow.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(AppTheme.onAccentColor)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text(session.title)
                    .font(AppTheme.Typography.title3)
                    .foregroundStyle(AppTheme.onAccentColor)
                    .fixedSize(horizontal: false, vertical: true)

                if !session.detail.isEmpty {
                    Text(session.detail)
                        .font(AppTheme.Typography.subheadline)
                        .foregroundStyle(AppTheme.onAccentColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button(action: action) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Text("Start")
                    Image(systemName: "arrow.right")
                }
                .frame(maxWidth: .infinity)
            }
            .primaryGlassButton(fullWidth: true)
            .accessibilityLabel("Start")
            .accessibilityHint("Starts your recommended session")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fidelDesignCard(padding: AppTheme.Spacing.lg, background: AppTheme.terracottaDeepColor)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Open Path Cards

/// A single always-open lesson on the path. Never disabled; the mastery ring and
/// tier are display-only. In-progress lessons get a subtle accent border; a
/// not-yet-started (`.new`) lesson shows a "Start" affordance.
private struct PathLessonCard: View {
    let item: JourneyLessonItem

    private var isInProgress: Bool {
        item.masteryFraction > 0 && item.masteryFraction < 1
    }

    private var percentText: String {
        "\(Int((item.masteryFraction * 100).rounded())) percent"
    }

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            AccessibleProgressRing(
                progress: item.masteryFraction,
                lineWidth: 5,
                size: 46,
                label: "\(item.lesson.title) mastery",
                valueText: percentText
            )
            .overlay {
                if item.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppTheme.successColor)
                }
            }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text(item.lesson.title)
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.inkColor)

                Text(item.lesson.description)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.inkSecondaryColor)
                    .lineLimit(2)

                MasteryPill(tier: item.masteryTier)
                    .padding(.top, 2)
            }

            Spacer(minLength: AppTheme.Spacing.sm)

            trailingAffordance
        }
        .fidelDesignCard(
            padding: AppTheme.Spacing.md,
            cornerRadius: 20,
            borderColor: isInProgress ? AppTheme.terracottaColor.opacity(0.55) : AppTheme.hairlineColor
        )
    }

    @ViewBuilder
    private var trailingAffordance: some View {
        if item.masteryTier == .new {
            HStack(spacing: 4) {
                Text("Start")
                Image(systemName: "arrow.right")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.onAccentColor)
            .padding(.horizontal, AppTheme.Spacing.sm)
            .padding(.vertical, AppTheme.Spacing.xs)
            .background(Capsule().fill(AppTheme.terracottaColor))
        } else {
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(AppTheme.mutedInkColor)
        }
    }
}

/// Display-only tier badge (e.g. "Familiar"). Not interactive, so it is a plain
/// styled label rather than a `GlassChip`, which would nest a button in the card.
private struct MasteryPill: View {
    let tier: MasteryTier

    private var color: Color {
        switch tier {
        case .new: return AppTheme.mutedInkColor
        case .started: return AppTheme.terracottaColor
        case .familiar: return AppTheme.infoColor
        case .proficient: return AppTheme.plumColor
        case .mastered: return AppTheme.successColor
        }
    }

    var body: some View {
        Text(tier.label)
            .font(.caption2.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, AppTheme.Spacing.xs)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.14)))
    }
}

/// Entry card for the lesson-less Script & Sounds section, routing into Fidel
/// tracing practice.
private struct ScriptIntroCard: View {
    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(AppTheme.practiceColor.opacity(0.12))
                    .frame(width: 46, height: 46)
                Image(systemName: "scribble.variable")
                    .foregroundStyle(AppTheme.practiceColor)
                    .font(.title3)
            }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text("Practice Fidel")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.inkColor)
                Text("Trace characters to learn them — adapts to what you know")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.inkSecondaryColor)
                    .lineLimit(2)
            }

            Spacer(minLength: AppTheme.Spacing.sm)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(AppTheme.mutedInkColor)
        }
        .fidelDesignCard(padding: AppTheme.Spacing.md, cornerRadius: 20)
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
