import Foundation
import SwiftData
import SwiftUI

// MARK: - Hero Action

/// What the hero's primary CTA does. Maps onto the existing Journey navigation.
enum HeroAction: Equatable {
    case practiceTracing
    case lesson(Int)
    case flashcards
    case matchPairs
    case conversation(Int)
    case browseChart
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
    /// The single "do this now" recommendation over the open path, from
    /// `NextStepPlanner`. Rebuilt on every `refresh()`.
    var recommendedSession: RecommendedSession?
    /// The always-open learning path, grouped into themed sections. Nothing
    /// here is locked.
    var pathSections: [JourneyPathSection] = []
    var showFidelChart = false
    var selectedLesson: Lesson?
    var selectedConversation: Conversation?
    var selectedPracticeMode: PracticeMode?

    private var progressRepository: ProgressRepositoryProtocol?
    private let lessonRepository: LessonRepositoryProtocol
    /// Built from the `ModelContext` passed to `configure`, used only to count
    /// due spaced-repetition reviews for the recommendation. Nil when configured
    /// without a context (e.g. some unit tests) — treated as zero due reviews.
    private var flashcardManager: FlashcardManager?

    init(
        lessonRepository: LessonRepositoryProtocol = LessonRepository.shared
    ) {
        self.lessonRepository = lessonRepository
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
        // `stageManager` is retained only as a "configured" sentinel — the path
        // is fully open, so nothing here reads a stage.
        guard stageManager != nil else { return }
        recommendedSession = buildRecommendedSession()
        pathSections = buildPathSections()
    }

    // MARK: - Open Path Building

    /// How the open path groups lessons into themed sections. Lesson-less
    /// Script & Sounds leads (its content is tracing/chart, surfaced by the
    /// view), then the three lesson bands. Verified against `getLessons()` ids
    /// (currently 1...8).
    private static let sectionPartition: [(stage: LearningStage, lessonIds: [Int])] = [
        (.scriptAndSounds, []),
        (.survivalPhrases, [1, 2]),
        (.buildingSentences, [3, 4, 5]),
        (.fluency, [6, 7, 8]),
    ]

    /// The single best "do this now" session over the open path. Prefers due
    /// reviews, then an in-progress lesson, then the next new lesson.
    private func buildRecommendedSession() -> RecommendedSession {
        let progress = progressRepository?.getUserProgress()
        let lessons = lessonRepository.getLessons()
        let dueReviewCount = flashcardManager?.getDueItems().count ?? 0

        return NextStepPlanner().recommend(
            progress: progress,
            lessons: lessons,
            tier: AppSettingsStore().dailyGoalTier,
            dueReviewCount: dueReviewCount
        )
    }

    /// Minimum FSRS stability (in days) for an item to count as "learned" for
    /// mastery display, independent of `vocabularyMastered`. Tunable: roughly
    /// "retained for about a week" is a reasonable bar for "learned" without
    /// requiring the stricter, XP-awarding `masterVocabulary` threshold.
    static let masteryMinStability: Double = 7

    /// The always-open path, grouped into themed sections with display-only
    /// mastery per lesson. Empty sections are dropped, except the lesson-less
    /// Script & Sounds intro which always leads.
    private func buildPathSections() -> [JourneyPathSection] {
        let progress = progressRepository?.getUserProgress()
        let completedLessonIds = Set(progress?.lessonsCompleted ?? [])
        let learnedItemIds = Set(progress?.vocabularyMastered ?? [])
            .union(flashcardManager?.learnedItemIds(minStability: Self.masteryMinStability) ?? [])
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

    // MARK: - Hero Action

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
}
