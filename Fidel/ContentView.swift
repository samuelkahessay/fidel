import SwiftData
import SwiftUI

private enum AppTab: String, CaseIterable, Identifiable {
    case today
    case learn
    case practice
    case selam
    case you

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "Today"
        case .learn: return "Learn"
        case .practice: return "Practice"
        case .selam: return "Selam"
        case .you: return "You"
        }
    }

    var icon: String {
        switch self {
        case .today: return "sun.max"
        case .learn: return "map"
        case .practice: return "square.stack.3d.up"
        case .selam: return "bubble.left.and.bubble.right"
        case .you: return "person.crop.circle"
        }
    }
}

private enum FidelRoute: Identifiable, Hashable {
    case fidelGrid
    case reference
    case conversationList
    case conversation(Int)
    case lesson(Int)
    case practice(PracticeMode)

    var id: String {
        switch self {
        case .fidelGrid: return "fidel-grid"
        case .reference: return "reference"
        case .conversationList: return "conversation-list"
        case .conversation(let id): return "conversation-\(id)"
        case .lesson(let id): return "lesson-\(id)"
        case .practice(let mode): return "practice-\(mode.rawValue)"
        }
    }
}

private struct AppNavigationActions {
    var selectTab: (AppTab) -> Void
    var openRoute: (FidelRoute) -> Void
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .today
    @State private var activeRoute: FidelRoute?

    var body: some View {
        VStack(spacing: 0) {
            selectedContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 0) {
                RootTabBar(selectedTab: $selectedTab)
                    .padding(.horizontal, AppTheme.Spacing.lg)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
            }
        }
        .background(FidelPaperBackground())
        .sheet(item: $activeRoute) { route in
            routeDestination(route)
        }
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedTab {
        case .today:
            TodayView(actions: navigationActions)
        case .learn:
            JourneyView()
        case .practice:
            PracticeHubView()
        case .selam:
            SelamView(embedded: false)
        case .you:
            ProgressDashboardView()
        }
    }

    private var navigationActions: AppNavigationActions {
        AppNavigationActions(
            selectTab: { tab in
                selectedTab = tab
            },
            openRoute: { route in
                activeRoute = route
            }
        )
    }

    @ViewBuilder
    private func routeDestination(_ route: FidelRoute) -> some View {
        switch route {
        case .fidelGrid:
            FidelView()
        case .reference:
            ReferenceView(embedded: false)
        case .conversationList:
            ConversationPickerView { conversation in
                activeRoute = .conversation(conversation.id)
            }
        case .conversation(let conversationId):
            if let conversation = LessonRepository.shared.getConversation(by: conversationId) {
                NavigationStack {
                    ConversationDetailView(conversation: conversation)
                }
            } else {
                MissingRouteView(title: "Conversation unavailable")
            }
        case .lesson(let lessonId):
            if let lesson = LessonRepository.shared.getLesson(by: lessonId) {
                NavigationStack {
                    LessonDetailView(lesson: lesson)
                }
            } else {
                MissingRouteView(title: "Lesson unavailable")
            }
        case .practice(let mode):
            NavigationStack {
                PracticeModeDestination(mode: mode)
            }
        }
    }
}

private struct TodayView: View {
    @Environment(\.modelContext) private var modelContext

    let actions: AppNavigationActions

    @State private var progress: UserProgress?
    @State private var dailyGoalXP = 20

    private let lessonRepository = LessonRepository.shared
    private let settingsStore = AppSettingsStore()

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    FidelScreenHeader(
                        title: "Today",
                        amharicTitle: "ዛሬ",
                        subtitle: "A calm path through Fidel, words, practice, and conversation."
                    )

                    dailyFocusCard
                    quickActions
                    todayPhraseCard
                    localProgressCard
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.top, AppTheme.Spacing.md)
                .padding(.bottom, 110)
            }
            .background(FidelPaperBackground())
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            refreshProgress()
        }
        .onAppear {
            refreshProgress()
        }
    }

    private var dailyFocusCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    Text(nextActionTitle)
                        .font(AppTheme.Typography.title2)
                        .foregroundStyle(AppTheme.inkColor)

                    Text(nextActionSubtitle)
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.inkSecondaryColor)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                DailyGoalRing(
                    progress: dailyGoalProgress,
                    value: progress?.todayXP ?? 0,
                    goal: dailyGoalXP
                )
            }

            Button {
                actions.openRoute(nextRoute)
            } label: {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: nextActionIcon)
                    Text("Continue")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.onAccentColor)
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.md)
                .background(AppTheme.terracottaColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)

            FidelProgressBar(
                value: dailyGoalProgress,
                color: AppTheme.goldColor,
                trackColor: AppTheme.goldColor.opacity(0.18),
                height: 8
            )
        }
        .fidelDesignCard(padding: AppTheme.Spacing.lg)
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            FidelSectionLabel(title: "Quick paths")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.md) {
                    FidelQuickActionTile(
                        title: "Fidel grid",
                        subtitle: "Letters and tracing",
                        icon: "character.book.closed",
                        tint: AppTheme.terracottaColor,
                        textColor: AppTheme.onAccentColor,
                        subtitleColor: AppTheme.onAccentColor.opacity(0.78)
                    ) {
                        actions.openRoute(.fidelGrid)
                    }
                    .frame(width: 154)

                    FidelQuickActionTile(
                        title: "Practice",
                        subtitle: "Flashcards and drills",
                        icon: "rectangle.stack",
                        tint: AppTheme.eucalyptusColor,
                        textColor: AppTheme.onAccentColor,
                        subtitleColor: AppTheme.onAccentColor.opacity(0.78)
                    ) {
                        actions.selectTab(.practice)
                    }
                    .frame(width: 154)

                    FidelQuickActionTile(
                        title: "Converse",
                        subtitle: "Guided phrases",
                        icon: "text.bubble",
                        tint: AppTheme.plumColor,
                        textColor: AppTheme.onAccentColor,
                        subtitleColor: AppTheme.onAccentColor.opacity(0.78)
                    ) {
                        if let firstConversation = lessonRepository.getConversations().first {
                            actions.openRoute(.conversation(firstConversation.id))
                        } else {
                            actions.openRoute(.conversationList)
                        }
                    }
                    .frame(width: 154)

                    FidelQuickActionTile(
                        title: "Selam",
                        subtitle: "Tutor chat",
                        icon: "sparkles",
                        tint: AppTheme.goldColor,
                        textColor: AppTheme.onGoldColor,
                        subtitleColor: AppTheme.onGoldColor.opacity(0.72)
                    ) {
                        actions.selectTab(.selam)
                    }
                    .frame(width: 154)

                    FidelQuickActionTile(
                        title: "Reference",
                        subtitle: "Phrasebook",
                        icon: "book.pages",
                        tint: AppTheme.terracottaDeepColor,
                        textColor: AppTheme.onAccentColor,
                        subtitleColor: AppTheme.onAccentColor.opacity(0.78)
                    ) {
                        actions.openRoute(.reference)
                    }
                    .frame(width: 154)
                }
                .padding(.vertical, 1)
            }
        }
    }

    private var todayPhraseCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack {
            FidelSectionLabel(title: "Phrase of the day")
                Spacer()
                FidelChip(title: "local", color: AppTheme.eucalyptusColor)
            }

            if let phrase = phraseOfDay {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text(phrase.amharic)
                        .font(AppTheme.Typography.amharicDisplay(size: 42, relativeTo: .largeTitle))
                        .foregroundStyle(AppTheme.inkColor)
                        .minimumScaleFactor(0.7)

                    Text(phrase.transliteration)
                        .font(AppTheme.Typography.transliteration(size: 16))
                        .foregroundStyle(AppTheme.terracottaDeepColor)

                    Text(phrase.english)
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.inkSecondaryColor)
                }
            } else {
                Text("Reference content is ready once lessons are loaded.")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.inkSecondaryColor)
            }
        }
        .fidelDesignCard()
    }

    private var localProgressCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            FidelSectionLabel(title: "On this device")

            HStack(spacing: AppTheme.Spacing.md) {
                FidelMetricTile(
                    icon: "flame",
                    value: "\(progress?.currentStreak ?? 0)",
                    label: "Streak",
                    subtitle: "days",
                    color: AppTheme.terracottaColor
                )

                FidelMetricTile(
                    icon: "bolt.fill",
                    value: "\(progress?.totalXP ?? 0)",
                    label: "XP",
                    subtitle: "earned",
                    color: AppTheme.goldColor
                )
            }

            HStack(spacing: AppTheme.Spacing.md) {
                FidelMetricTile(
                    icon: "checkmark.seal",
                    value: "\(progress?.lessonsCompleted.count ?? 0)",
                    label: "Lessons",
                    subtitle: "complete",
                    color: AppTheme.eucalyptusColor
                )

                FidelMetricTile(
                    icon: "textformat.abc",
                    value: "\(progress?.vocabularyMastered.count ?? 0)",
                    label: "Words",
                    subtitle: "saved",
                    color: AppTheme.plumColor
                )
            }
        }
    }

    private var nextRoute: FidelRoute {
        guard let progress else { return .fidelGrid }
        let stage = currentLearningStage

        if stage == .scriptAndSounds {
            return .fidelGrid
        }

        if let lesson = nextLesson(for: progress, stage: stage) {
            return .lesson(lesson.id)
        }

        return .practice(.flashcards)
    }

    private var nextActionTitle: String {
        guard let progress else { return "Start with Fidel" }
        let stage = currentLearningStage

        if stage == .scriptAndSounds {
            return "Strengthen your Fidel foundation"
        }

        if let lesson = nextLesson(for: progress, stage: stage) {
            return lesson.title
        }

        return "Review what you know"
    }

    private var nextActionSubtitle: String {
        guard let progress else {
            return "Learn the letter shapes and sounds that unlock the rest of the app."
        }
        let stage = currentLearningStage

        if stage == .scriptAndSounds {
            return "Search, compare vowels, and open a character when you are ready to trace."
        }

        if let lesson = nextLesson(for: progress, stage: stage) {
            return "\(stage.displayName) · \(lesson.description)"
        }

        return "You are caught up on available lessons. Keep memory fresh with a short practice round."
    }

    private var nextActionIcon: String {
        switch nextRoute {
        case .fidelGrid: return "character.book.closed"
        case .practice: return "rectangle.stack"
        case .lesson: return "play.circle.fill"
        default: return "arrow.forward.circle.fill"
        }
    }

    private var dailyGoalProgress: Double {
        guard dailyGoalXP > 0 else { return 0 }
        return min(Double(progress?.todayXP ?? 0) / Double(dailyGoalXP), 1)
    }

    private var phraseOfDay: Phrase? {
        let phrases = lessonRepository.getPhrases()
        guard !phrases.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return phrases[(day - 1) % phrases.count]
    }

    private var currentLearningStage: LearningStage {
        guard let progress else { return .scriptAndSounds }
        return LearningStage(rawValue: progress.currentStage) ?? .scriptAndSounds
    }

    private func nextLesson(for progress: UserProgress, stage: LearningStage) -> Lesson? {
        lessonRepository.getLessons()
            .filter { stage.availableLessonIds.contains($0.id) }
            .first { !progress.lessonsCompleted.contains($0.id) }
    }

    private func refreshProgress() {
        let repository = ProgressRepository(modelContext: modelContext)
        progress = repository.ensureUserProgress()
        dailyGoalXP = max(settingsStore.dailyXPGoal, 1)
    }
}

private struct DailyGoalRing: View {
    var progress: Double
    var value: Int
    var goal: Int

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppTheme.goldColor.opacity(0.18), lineWidth: 9)

            Circle()
                .trim(from: 0, to: max(0.04, min(progress, 1)))
                .stroke(
                    AppTheme.goldColor,
                    style: StrokeStyle(lineWidth: 9, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 0) {
                Text("\(value)")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(AppTheme.inkColor)
                Text("/\(goal)")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.inkSecondaryColor)
            }
        }
        .frame(width: 78, height: 78)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Daily goal \(value) of \(goal) XP")
    }
}

private struct ConversationPickerView: View {
    var onSelect: (Conversation) -> Void

    private let conversations = LessonRepository.shared.getConversations()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    FidelScreenHeader(
                        title: "Conversation",
                        amharicTitle: "ውይይት",
                        subtitle: "Choose a local guided exchange."
                    )

                    ForEach(Array(conversations.enumerated()), id: \.element.id) { _, conversation in
                        Button {
                            onSelect(conversation)
                        } label: {
                            HStack(spacing: AppTheme.Spacing.md) {
                                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                                    Text(conversation.title)
                                        .font(AppTheme.Typography.headline)
                                        .foregroundStyle(AppTheme.inkColor)
                                    Text("\(conversation.lines.count) lines · level \(conversation.difficulty)")
                                        .font(AppTheme.Typography.caption)
                                        .foregroundStyle(AppTheme.inkSecondaryColor)
                                        .lineLimit(2)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(AppTheme.mutedInkColor)
                            }
                            .fidelDesignCard(padding: AppTheme.Spacing.md)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(AppTheme.Spacing.lg)
                .padding(.bottom, AppTheme.Spacing.xl)
            }
            .background(FidelPaperBackground())
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct PracticeModeDestination: View {
    let mode: PracticeMode

    var body: some View {
        switch mode {
        case .flashcards:
            FlashcardView()
        case .quiz:
            QuizView()
        case .sentenceBuilder:
            SentenceBuilderView()
        case .speedDrill:
            SpeedDrillView()
        case .pronunciation:
            PronunciationPracticeView()
        case .tracing:
            TracingView()
        }
    }
}

private struct MissingRouteView: View {
    let title: String

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                title,
                systemImage: "exclamationmark.triangle",
                description: Text("This local content could not be loaded.")
            )
            .background(FidelPaperBackground())
        }
    }
}

private struct RootTabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 18, weight: selectedTab == tab ? .bold : .semibold))

                        Text(tab.title)
                            .font(.system(size: 10, weight: selectedTab == tab ? .bold : .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .foregroundStyle(selectedTab == tab ? AppTheme.terracottaColor : AppTheme.mutedInkColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background {
                        if selectedTab == tab {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(AppTheme.terracottaColor.opacity(0.12))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(AppTheme.hairlineColor, lineWidth: 1)
        )
        .shadow(color: AppTheme.terracottaDeepColor.opacity(0.14), radius: 18, x: 0, y: 10)
    }
}
