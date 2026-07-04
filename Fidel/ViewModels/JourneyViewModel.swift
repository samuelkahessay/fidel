import Foundation
import SwiftData
import SwiftUI

// MARK: - Journey Activity Types

enum ActivityType: Hashable {
    case fidel
    case lesson(Int)
    case practiceMode(PracticeMode)
    case conversation(Int)
}

/// Optional measurable progress shown on an activity card (e.g. recognized
/// characters toward the unlock target). Nil when the activity has no
/// meaningful count to display.
struct ActivityProgress: Equatable {
    let current: Int
    let target: Int
    let unit: String

    var fraction: Double {
        target > 0 ? min(Double(current) / Double(target), 1) : 0
    }
    var isComplete: Bool { current >= target }
}

struct JourneyActivity: Identifiable {
    let id: String
    let type: ActivityType
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    var isCompleted: Bool
    var progress: ActivityProgress? = nil
}

// MARK: - Next-Action Hero

/// What the hero's primary CTA does. Maps onto the existing Journey navigation.
enum HeroAction: Equatable {
    case practiceTracing
    case lesson(Int)
    case flashcards
    case matchPairs
    case conversation(Int)
    case browseChart
}

enum HeroStyle {
    /// Actionable requirement toward the next stage.
    case action
    /// Every next-stage criterion is met but the stage has not advanced yet.
    case ready
    /// No further stage to unlock (Fluency) — open-ended practice.
    case freePractice
}

/// The single most important next step, derived from the gating criteria.
struct NextActionHero {
    let eyebrow: String
    let title: String
    let detail: String
    let progress: Double
    let ctaLabel: String
    let ctaIcon: String
    let action: HeroAction
    let style: HeroStyle
    /// The hero bar shows only when it fully represents the gate (a single
    /// next-stage criterion). With multiple criteria the stage ring and the
    /// "Next stage" checklist carry progress, so the hero stays text + CTA only.
    var showsProgressBar: Bool = false
}

// MARK: - Open Path Model

/// One themed section of the always-open learning path (e.g. "Survival
/// Phrases"). Sections group lessons for display only — nothing here gates or
/// locks; every item is selectable at all times.
struct JourneyPathSection: Identifiable {
    let id: String
    let title: String
    let amharicTitle: String
    let items: [JourneyLessonItem]
}

/// A single lesson on the open path plus its display-only mastery. `masteryTier`
/// / `masteryFraction` come from `CurriculumService` and never restrict access.
struct JourneyLessonItem: Identifiable {
    let id: Int
    let lesson: Lesson
    let masteryTier: MasteryTier
    let masteryFraction: Double
    let isCompleted: Bool
}

// MARK: - Journey ViewModel

@MainActor
@Observable
final class JourneyViewModel {
    var stageManager: StageManager?
    var currentStage: LearningStage = .scriptAndSounds
    var activities: [JourneyActivity] = []
    /// The single "do this now" recommendation over the open path, from
    /// `NextStepPlanner`. Rebuilt on every `refresh()`.
    var recommendedSession: RecommendedSession?
    /// The always-open learning path, grouped into themed sections. Nothing
    /// here is locked.
    var pathSections: [JourneyPathSection] = []
    /// Bridge (Task 6): the open path never locks anything, so this is always
    /// empty. Kept only so the not-yet-reworked `JourneyView` compiles; removed
    /// in Task 8.
    var lockedStages: [LearningStage] = []
    /// Bridge (Task 6): stage progression is gone, so this stays 0. Kept only
    /// for `JourneyView` compile-safety; removed in Task 8.
    var progressToNextStage: Double = 0
    var showFidelChart = false
    var selectedLesson: Lesson?
    var selectedConversation: Conversation?
    var selectedPracticeMode: PracticeMode?
    var tappedLockedStage: LearningStage?
    var showStageAdvancement = false
    var advancedToStage: LearningStage?

    private var progressRepository: ProgressRepositoryProtocol?
    private let lessonRepository: LessonRepositoryProtocol
    private let audioAssetRepository: AudioAssetRepository
    /// Built from the `ModelContext` passed to `configure`, used only to count
    /// due spaced-repetition reviews for the recommendation. Nil when configured
    /// without a context (e.g. some unit tests) — treated as zero due reviews.
    private var flashcardManager: FlashcardManager?

    init(
        lessonRepository: LessonRepositoryProtocol = LessonRepository.shared,
        audioAssetRepository: AudioAssetRepository = .shared
    ) {
        self.lessonRepository = lessonRepository
        self.audioAssetRepository = audioAssetRepository
    }

    /// - Parameter modelContext: used to build a `FlashcardManager` for counting
    ///   due reviews in the recommendation. Optional so existing 2-arg callers
    ///   (and tests) keep compiling; without it, due-review count is treated as 0.
    func configure(
        stageManager: StageManager,
        progressRepository: ProgressRepositoryProtocol,
        modelContext: ModelContext? = nil
    ) {
        self.stageManager = stageManager
        self.progressRepository = progressRepository
        if let modelContext {
            self.flashcardManager = FlashcardManager(modelContext: modelContext)
        }
        refresh()
    }

    func refresh() {
        guard stageManager != nil else { return }
        currentStage = stageManager?.currentStage ?? currentStage
        activities = buildActivities()

        // Open path: nothing locks and there is no stage gate to progress
        // toward. These stay neutral only so the not-yet-reworked JourneyView
        // (Task 7) keeps compiling; they are removed in Task 8.
        lockedStages = []
        progressToNextStage = 0

        recommendedSession = buildRecommendedSession()
        pathSections = buildPathSections()
    }

    /// Open path: no stage-gating, so advancement is a no-op. Kept only so
    /// JourneyView (reworked in Task 7) still compiles; removed in Task 8.
    func checkAdvancement() {}

    // MARK: - Open Path Building

    /// How the open path groups lessons into themed sections. Lesson-less
    /// Script & Sounds leads (its content is tracing/chart, surfaced by the
    /// view), then the three lesson bands. Verified against `getLessons()` ids
    /// (currently 1...8).
    private static let sectionPartition: [(stage: LearningStage, lessonIds: [Int])] = [
        (.scriptAndSounds, []),
        (.survivalPhrases, [1, 2]),
        (.buildingSentences, [3, 4, 5]),
        (.fluency, [6, 7, 8])
    ]

    /// The single best "do this now" session over the open path. Prefers due
    /// reviews, then an in-progress lesson, then the next new lesson.
    private func buildRecommendedSession() -> RecommendedSession {
        let progress = progressRepository?.getUserProgress()
        let completedLessonIds = Set(progress?.lessonsCompleted ?? [])
        let lessons = lessonRepository.getLessons()
        let orderedLessonIds = lessons.map(\.id).sorted()
        // `progressPercent` is not persisted by the repo today, so this is
        // usually nil — the planner then falls through to the next new lesson.
        let inProgressLessonId = lessons.first {
            $0.progressPercent > 0 && !completedLessonIds.contains($0.id)
        }?.id
        let dueReviewCount = flashcardManager?.getDueItems().count ?? 0

        return NextStepPlanner().plan(
            completedLessonIds: completedLessonIds,
            inProgressLessonId: inProgressLessonId,
            tier: AppSettingsStore().dailyGoalTier,
            dueReviewCount: dueReviewCount,
            orderedLessonIds: orderedLessonIds
        )
    }

    /// The always-open path, grouped into themed sections with display-only
    /// mastery per lesson. Empty sections are dropped, except the lesson-less
    /// Script & Sounds intro which always leads.
    private func buildPathSections() -> [JourneyPathSection] {
        let progress = progressRepository?.getUserProgress()
        let completedLessonIds = Set(progress?.lessonsCompleted ?? [])
        let learnedItemIds = Set(progress?.vocabularyMastered ?? [])
        let recognizedCharIds = Set(progress?.fidelCharactersRecognized ?? [])
        let lessonsById = Dictionary(
            lessonRepository.getLessons().map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        return Self.sectionPartition.compactMap { entry in
            let items: [JourneyLessonItem] = entry.lessonIds.compactMap { lessonId in
                guard let lesson = lessonsById[lessonId] else { return nil }
                let mastery = CurriculumService.shared.mastery(
                    for: lesson,
                    learnedItemIds: learnedItemIds,
                    recognizedCharIds: recognizedCharIds
                )
                return JourneyLessonItem(
                    id: lesson.id,
                    lesson: lesson,
                    masteryTier: mastery.tier,
                    masteryFraction: mastery.fraction,
                    isCompleted: completedLessonIds.contains(lesson.id)
                )
            }
            // Drop empty sections gracefully, but always keep the (lesson-less)
            // Script & Sounds intro so the path opens with it.
            guard !items.isEmpty || entry.stage == .scriptAndSounds else { return nil }
            return JourneyPathSection(
                id: "stage_\(entry.stage.rawValue)",
                title: entry.stage.displayName,
                amharicTitle: entry.stage.amharicTitle,
                items: items
            )
        }
    }

    func selectCurrentStagePrimaryActivity() {
        guard let primaryActivity = activities.first else { return }
        selectActivity(primaryActivity)
    }

    func selectActivity(_ activity: JourneyActivity) {
        switch activity.type {
        case .fidel:
            showFidelChart = true
        case .lesson(let id):
            selectedLesson = lessonRepository.getLessons().first(where: { $0.id == id })
        case .practiceMode(let mode):
            selectedPracticeMode = mode
        case .conversation(let id):
            selectedConversation = lessonRepository.getConversations().first(where: { $0.id == id })
        }
    }

    // MARK: - Next-Action Hero

    /// The single clearest next step toward unlocking the next stage. Reads live
    /// progress each access (like `nextStageCriteria`) so it stays in sync after
    /// the view refreshes on return from an activity.
    var nextActionHero: NextActionHero? {
        guard let stageManager,
              let progress = progressRepository?.getUserProgress() else { return nil }

        // Fluency / no next stage: open-ended practice, never a fidel target.
        guard let criteria = stageManager.criteriaForNextStage(), !criteria.isEmpty else {
            return NextActionHero(
                eyebrow: "Keep practicing",
                title: "You've unlocked everything",
                detail: "Free practice with every lesson, drill, and conversation.",
                progress: 1,
                ctaLabel: "Review with flashcards",
                ctaIcon: "rectangle.stack.fill",
                action: .flashcards,
                style: .freePractice
            )
        }

        let nextStageName = LearningStage(rawValue: currentStage.rawValue + 1)?.displayName ?? "the next stage"

        // All criteria met but not advanced yet (transient until checkAdvancement).
        guard let unmet = criteria.first(where: { !$0.evaluate(progress) }) else {
            return NextActionHero(
                eyebrow: "Almost there",
                title: "Stage complete!",
                detail: "Unlocking \(nextStageName)…",
                progress: 1,
                ctaLabel: "Continue",
                ctaIcon: "checkmark.circle.fill",
                action: .practiceTracing, // unused: the .ready CTA calls refreshAfterReturn()
                style: .ready
            )
        }

        let plan = heroPlan(for: unmet, progress: progress)
        return NextActionHero(
            eyebrow: "Up next",
            title: plan.title(unmet.remaining(progress)),
            detail: "to unlock \(nextStageName)",
            progress: unmet.progressFraction(progress),
            ctaLabel: plan.ctaLabel,
            ctaIcon: plan.ctaIcon,
            action: plan.action,
            style: .action,
            showsProgressBar: criteria.count == 1
        )
    }

    func performHeroAction(_ action: HeroAction) {
        switch action {
        case .practiceTracing:
            selectedPracticeMode = .tracing
        case .lesson(let id):
            selectedLesson = lessonRepository.getLessons().first(where: { $0.id == id })
        case .flashcards:
            selectedPracticeMode = .flashcards
        case .matchPairs:
            selectedPracticeMode = .matchPairs
        case .conversation(let id):
            selectedConversation = lessonRepository.getConversations().first(where: { $0.id == id })
        case .browseChart:
            showFidelChart = true
        }
    }

    private struct HeroPlan {
        let title: (Int) -> String
        let ctaLabel: String
        let ctaIcon: String
        let action: HeroAction
    }

    /// Maps a gating criterion to hero copy + CTA using prefix-tolerant id
    /// matching, with a safe default for any unrecognized criterion id.
    private func heroPlan(for criterion: StageCriterion, progress: UserProgress) -> HeroPlan {
        func more(_ n: Int, _ noun: String) -> String {
            "\(n) more \(noun)\(n == 1 ? "" : "s")"
        }
        let id = criterion.id
        if id.contains("fidel") {
            return HeroPlan(
                title: { "Recognize \(more($0, "character"))" },
                ctaLabel: "Practice Fidel",
                ctaIcon: "scribble.variable",
                action: .practiceTracing
            )
        }
        if id.contains("lesson") {
            let lessonId = stageManager?.availableLessons()
                .first { !progress.lessonsCompleted.contains($0.id) }?.id
            return HeroPlan(
                title: { "Complete \(more($0, "lesson"))" },
                ctaLabel: "Continue lesson",
                ctaIcon: "book.fill",
                action: lessonId.map { .lesson($0) } ?? .flashcards
            )
        }
        if id.contains("vocab") {
            // Match Pairs is the mode that actually masters vocabulary; plain
            // flashcards only reschedule FSRS reviews and never advance the gate.
            return HeroPlan(
                title: { "Master \(more($0, "word"))" },
                ctaLabel: "Match word pairs",
                ctaIcon: "square.on.square",
                action: .matchPairs
            )
        }
        if id.contains("conversation") {
            let convId = stageManager?.availableConversations()
                .first { !progress.conversationsPracticed.contains($0.id) }?.id
            return HeroPlan(
                title: { _ in "Practice a conversation" },
                ctaLabel: "Practice a conversation",
                ctaIcon: "bubble.left.and.bubble.right",
                action: convId.map { .conversation($0) } ?? .flashcards
            )
        }
        // Unknown criterion id: fall back to the current stage's primary activity.
        return HeroPlan(
            title: { _ in criterion.description },
            ctaLabel: "Continue",
            ctaIcon: "arrow.right",
            action: primaryActivityAction()
        )
    }

    private func primaryActivityAction() -> HeroAction {
        switch activities.first?.type {
        case .fidel: return .browseChart
        case .practiceMode(.tracing): return .practiceTracing
        case .practiceMode: return .flashcards
        case .lesson(let id): return .lesson(id)
        case .conversation(let id): return .conversation(id)
        case .none: return .practiceTracing
        }
    }

    // MARK: - Activity Building

    private func buildActivities() -> [JourneyActivity] {
        guard let stageManager else { return [] }
        let progress = progressRepository?.getUserProgress()

        var result: [JourneyActivity] = []

        switch currentStage {
        case .scriptAndSounds:
            let recognized = progress?.fidelCharactersRecognized.count ?? 0
            let recognitionTarget = LearningStage.fidelRecognitionTarget
            // Primary: the adaptive tracing session (TraceSessionPlan.standard),
            // which serves new + due-for-review characters and marks recognition.
            result.append(JourneyActivity(
                id: "practice_fidel",
                type: .practiceMode(.tracing),
                title: "Practice Fidel",
                subtitle: "Trace characters to learn them — adapts to what you know",
                icon: "scribble.variable",
                color: AppTheme.practiceColor,
                isCompleted: recognized >= recognitionTarget,
                progress: ActivityProgress(
                    current: min(recognized, recognitionTarget),
                    target: recognitionTarget,
                    unit: "recognized"
                )
            ))
            // Secondary: the chart as a lookup tool (does not mark recognition).
            result.append(JourneyActivity(
                id: "fidel_chart",
                type: .fidel,
                title: "Browse the chart",
                subtitle: "Look up any letter, sound, and vowel form",
                icon: "character.book.closed",
                color: AppTheme.infoColor,
                isCompleted: false
            ))
            result.append(JourneyActivity(
                id: "character_quiz",
                type: .practiceMode(.quiz),
                title: "Character Quiz",
                subtitle: "Test your Fidel knowledge",
                icon: "questionmark.circle.fill",
                color: AppTheme.practiceColor,
                isCompleted: false
            ))

        case .survivalPhrases:
            let lessons = stageManager.availableLessons()
            let conversations = stageManager.availableConversations()

            if let lesson1 = lessons.first(where: { $0.id == 1 }) {
                result.append(JourneyActivity(
                    id: "lesson_1",
                    type: .lesson(1),
                    title: lesson1.title,
                    subtitle: lesson1.description,
                    icon: "book.fill",
                    color: AppTheme.primaryColor,
                    isCompleted: progress?.lessonsCompleted.contains(1) ?? false
                ))
            }

            result.append(JourneyActivity(
                id: "flashcards_s1",
                type: .practiceMode(.flashcards),
                title: "Flashcards",
                subtitle: "Review vocabulary with spaced repetition",
                icon: "rectangle.stack.fill",
                color: AppTheme.infoColor,
                isCompleted: false
            ))

            appendPronunciationPracticeIfAvailable(to: &result, id: "pronunciation_s1")

            if let lesson2 = lessons.first(where: { $0.id == 2 }) {
                result.append(JourneyActivity(
                    id: "lesson_2",
                    type: .lesson(2),
                    title: lesson2.title,
                    subtitle: lesson2.description,
                    icon: "book.fill",
                    color: AppTheme.primaryColor,
                    isCompleted: progress?.lessonsCompleted.contains(2) ?? false
                ))
            }

            result.append(JourneyActivity(
                id: "quiz_s1",
                type: .practiceMode(.quiz),
                title: "Quiz",
                subtitle: "Test your knowledge",
                icon: "questionmark.circle.fill",
                color: AppTheme.practiceColor,
                isCompleted: false
            ))

            for conv in conversations {
                result.append(JourneyActivity(
                    id: "conversation_\(conv.id)",
                    type: .conversation(conv.id),
                    title: conv.title,
                    subtitle: "\(conv.lines.count) lines",
                    icon: "bubble.left.and.bubble.right",
                    color: AppTheme.practiceColor,
                    isCompleted: progress?.conversationsPracticed.contains(conv.id) ?? false
                ))
            }

        case .buildingSentences:
            let lessons = stageManager.availableLessons()
            let conversations = stageManager.availableConversations()

            for lesson in lessons {
                result.append(JourneyActivity(
                    id: "lesson_\(lesson.id)",
                    type: .lesson(lesson.id),
                    title: lesson.title,
                    subtitle: lesson.description,
                    icon: "book.fill",
                    color: AppTheme.primaryColor,
                    isCompleted: progress?.lessonsCompleted.contains(lesson.id) ?? false
                ))
            }

            for mode in visiblePracticeModes(stageManager.availablePracticeModes()) {
                result.append(JourneyActivity(
                    id: "practice_\(mode.rawValue)",
                    type: .practiceMode(mode),
                    title: mode.rawValue,
                    subtitle: mode.description,
                    icon: mode.icon,
                    color: mode.color,
                    isCompleted: false
                ))
            }

            for conv in conversations {
                result.append(JourneyActivity(
                    id: "conversation_\(conv.id)",
                    type: .conversation(conv.id),
                    title: conv.title,
                    subtitle: "\(conv.lines.count) lines",
                    icon: "bubble.left.and.bubble.right",
                    color: AppTheme.practiceColor,
                    isCompleted: progress?.conversationsPracticed.contains(conv.id) ?? false
                ))
            }

        case .fluency:
            // All content available
            for lesson in lessonRepository.getLessons() {
                result.append(JourneyActivity(
                    id: "lesson_\(lesson.id)",
                    type: .lesson(lesson.id),
                    title: lesson.title,
                    subtitle: lesson.description,
                    icon: "book.fill",
                    color: AppTheme.primaryColor,
                    isCompleted: progress?.lessonsCompleted.contains(lesson.id) ?? false
                ))
            }

            for mode in visiblePracticeModes(PracticeMode.allCases) {
                result.append(JourneyActivity(
                    id: "practice_\(mode.rawValue)",
                    type: .practiceMode(mode),
                    title: mode.rawValue,
                    subtitle: mode.description,
                    icon: mode.icon,
                    color: mode.color,
                    isCompleted: false
                ))
            }

            for conv in lessonRepository.getConversations() {
                result.append(JourneyActivity(
                    id: "conversation_\(conv.id)",
                    type: .conversation(conv.id),
                    title: conv.title,
                    subtitle: "\(conv.lines.count) lines",
                    icon: "bubble.left.and.bubble.right",
                    color: AppTheme.practiceColor,
                    isCompleted: progress?.conversationsPracticed.contains(conv.id) ?? false
                ))
            }
        }

        return result
    }

    private func appendPronunciationPracticeIfAvailable(to result: inout [JourneyActivity], id: String) {
        guard audioAssetRepository.hasPronunciationPracticeContent else { return }
        result.append(JourneyActivity(
            id: id,
            type: .practiceMode(.pronunciation),
            title: "Pronunciation Practice",
            subtitle: "Listen to generated pronunciation",
            icon: "waveform",
            color: AppTheme.primaryColor,
            isCompleted: false
        ))
    }

    private func visiblePracticeModes(_ modes: [PracticeMode]) -> [PracticeMode] {
        modes.filter { mode in
            mode != .pronunciation || audioAssetRepository.hasPronunciationPracticeContent
        }
    }
}
