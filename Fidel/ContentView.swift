import SwiftData
import SwiftUI
import SyncKit
import os

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

    /// Selam runs on Apple's on-device model, so it only appears where Apple
    /// Intelligence is available.
    static var visibleCases: [AppTab] {
        SelamAvailability.isEnabled ? allCases : allCases.filter { $0 != .selam }
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
    @Environment(SyncEngine.self) private var sync

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(AppTab.visibleCases) { tab in
                Tab(tab.title, systemImage: tab.icon, value: tab) {
                    tabContent(for: tab)
                }
            }
        }
        .tint(AppTheme.terracottaColor)
        .tabBarMinimizeBehavior(.onScrollDown)
        .sheet(item: $activeRoute) { route in
            routeDestination(route)
        }
        .sheet(isPresented: Binding(
            get: { sync.status.state == .needsAccountChoice },
            set: { _ in }
        )) {
            AccountChangeSheet()
                .interactiveDismissDisabled()
        }
    }

    @ViewBuilder
    private func tabContent(for tab: AppTab) -> some View {
        switch tab {
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

/// Presented when `SyncEngine` detects the device's iCloud account changed
/// out from under the sync engine (`SyncStatus.State.needsAccountChoice`).
/// The user picks whether to upload this device's local data into the new
/// account, or wipe local data and adopt the new account's data (keeping a
/// local archive first).
private struct AccountChangeSheet: View {
    @Environment(SyncEngine.self) private var sync
    @Environment(\.modelContext) private var context
    @State private var archiveFailed = false
    @State private var wipeFailed = false

    private static let logger = Logger(subsystem: "dev.skahessay.learnamharic", category: "sync")

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        sync.mergeLocalDataIntoCurrentAccount()
                    } label: {
                        Label("Keep this device's data", systemImage: "arrow.up.doc.on.clipboard")
                    }
                    Button(role: .destructive) {
                        adoptRemote()
                    } label: {
                        Label("Start fresh from iCloud", systemImage: "icloud.and.arrow.down")
                    }
                } footer: {
                    if archiveFailed {
                        Label("Couldn't create a local archive — nothing was changed. Free up space and try again, or choose Keep this device's data.", systemImage: "exclamationmark.triangle")
                    } else if wipeFailed {
                        Label("Couldn't clear this device's data — nothing was changed. Try again, or choose Keep this device's data.", systemImage: "exclamationmark.triangle")
                    } else {
                        Text("The iCloud account on this device changed. Choose whether to upload this device's data into the new account, or replace it with the new account's data (a local archive is kept).")
                    }
                }
            }
            .navigationTitle("iCloud Account Changed")
        }
    }

    private func adoptRemote() {
        // Archive FIRST. If it fails, bail without touching any data — this
        // is the data-loss guard for the destructive path.
        archiveFailed = false
        wipeFailed = false
        guard archiveStoreFiles() else {
            archiveFailed = true
            return
        }
        do {
            try FidelSyncStore(context: context).wipeSyncedModels()
        } catch {
            Self.logger.error("Failed to wipe local data: \(error, privacy: .public)")
            wipeFailed = true
            return
        }
        sync.adoptCurrentAccountData()
    }

    /// Copies the SwiftData store files aside before wiping, honoring the
    /// "keep a local archive" promise in the spec. Returns `false` if the
    /// archive directory couldn't be created or an existing store file
    /// failed to copy — callers must not proceed with the wipe in that case.
    private func archiveStoreFiles() -> Bool {
        let fm = FileManager.default
        let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let stamp = ISO8601DateFormatter().string(from: .now)
        let archive = support.appendingPathComponent("Archive-\(stamp)", isDirectory: true)
        do {
            try fm.createDirectory(at: archive, withIntermediateDirectories: true)
        } catch {
            Self.logger.error("Failed to create archive directory: \(error, privacy: .public)")
            return false
        }
        // Fidel's ModelContainer uses the default ModelConfiguration (no
        // explicit URL — see FidelApp.swift), so its SQLite store is
        // `default.store` (+ WAL sidecar files) in Application Support.
        for name in ["default.store", "default.store-shm", "default.store-wal"] {
            let source = support.appendingPathComponent(name)
            guard fm.fileExists(atPath: source.path) else { continue }
            do {
                try fm.copyItem(at: source, to: archive.appendingPathComponent(name))
            } catch {
                Self.logger.error("Failed to archive \(name, privacy: .public): \(error, privacy: .public)")
                return false
            }
        }
        return true
    }
}

private struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncEngine.self) private var sync

    let actions: AppNavigationActions

    @State private var progress: UserProgress?
    @State private var dailyGoalXP = 20
    /// The single "do this now" recommendation, built from the SAME
    /// `NextStepPlanner` that drives the Learn tab. Today no longer reads the
    /// now-frozen `UserProgress.currentStage`, so its hero stays a live
    /// recommendation instead of getting stuck on "Practice your Fidel".
    @State private var recommendedSession: RecommendedSession?

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
                .padding(.bottom, AppTheme.Spacing.lg)
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
                        subtitle: "Browse letters",
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

                    if SelamAvailability.isEnabled {
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
                    }

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

    /// The CTA route for the current recommendation. Mirrors the Learn tab's
    /// `HeroAction` handling so Today and Learn always agree on "do this now".
    private var nextRoute: FidelRoute {
        guard let session = recommendedSession else { return .practice(.tracing) }
        return route(for: session.heroAction)
    }

    private func route(for action: HeroAction) -> FidelRoute {
        switch action {
        case .lesson(let id): return .lesson(id)
        case .conversation(let id): return .conversation(id)
        case .flashcards: return .practice(.flashcards)
        case .matchPairs: return .practice(.matchPairs)
        case .practiceTracing: return .practice(.tracing)
        case .browseChart: return .fidelGrid
        }
    }

    private var nextActionTitle: String {
        recommendedSession?.title ?? "Practice your Fidel"
    }

    private var nextActionSubtitle: String {
        recommendedSession?.detail ?? "Trace characters to learn them — go at your own pace."
    }

    private var nextActionIcon: String {
        switch nextRoute {
        case .fidelGrid: return "character.book.closed"
        case .practice(.tracing): return "scribble.variable"
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

    private func refreshProgress() {
        let repository = ProgressRepository(modelContext: modelContext, onMutation: { sync.markPending($0) })
        let current = repository.ensureUserProgress()
        progress = current
        dailyGoalXP = max(settingsStore.dailyXPGoal, 1)
        recommendedSession = buildRecommendedSession(for: current)
    }

    /// Builds the recommendation from the SAME inputs the Learn tab feeds
    /// `NextStepPlanner` (completed lessons, pace tier, due-review count, ordered
    /// lesson ids) — never from the now-frozen `UserProgress.currentStage`.
    private func buildRecommendedSession(for progress: UserProgress) -> RecommendedSession {
        let lessons = lessonRepository.getLessons()
        let dueReviewCount = FlashcardManager(modelContext: modelContext).getDueItems().count
        return NextStepPlanner().recommend(
            progress: progress,
            lessons: lessons,
            tier: settingsStore.dailyGoalTier,
            dueReviewCount: dueReviewCount
        )
    }
}

private struct DailyGoalRing: View {
    var progress: Double
    var value: Int
    var goal: Int

    var body: some View {
        GoldProgressRing(
            progress: progress,
            lineWidth: 9,
            size: 78,
            accessibilityLabel: "Daily goal \(value) of \(goal) XP"
        ) {
            VStack(spacing: 0) {
                Text("\(value)")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(AppTheme.inkColor)
                Text("/\(goal)")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.inkSecondaryColor)
            }
        }
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
        case .pronunciation:
            PronunciationPracticeView()
        case .tracing:
            TracingSessionView()
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

