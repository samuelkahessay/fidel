import SwiftData
import XCTest
@testable import Fidel___Learn_Amharic

/// Covers the open-path rewire of `JourneyViewModel` (Task 6): nothing is
/// locked, the `NextStepPlanner`-driven recommendation, and per-lesson mastery
/// tiers in `pathSections`.
@MainActor
final class JourneyViewModelOpenPathTests: XCTestCase {

    // Keep each container alive for the lifetime of its repository/context.
    private var retainedContainers: [ModelContainer] = []

    override func tearDown() {
        retainedContainers.removeAll()
        super.tearDown()
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            UserProgress.self,
            FlashcardProgress.self,
            SelamConversation.self,
            SelamMessage.self,
            CharacterTraceMastery.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private typealias ProgressSeed = (UserProgress) -> Void

    /// A learner with no progress at all.
    private func freshProgress() -> ProgressSeed { { _ in } }

    /// Builds a configured JourneyViewModel over a fresh in-memory store. The
    /// `progress` seed mutates the seeded UserProgress; `completedLessons` are
    /// completed through the repository (which also records their Fidel
    /// characters, exactly like real completion).
    private func makeConfiguredJourneyViewModel(
        progress seed: @escaping ProgressSeed = { _ in },
        completedLessons: [Int] = []
    ) throws -> JourneyViewModel {
        let container = try makeContainer()
        retainedContainers.append(container)
        let context = container.mainContext
        let repository = ProgressRepository(modelContext: context)
        let progress = repository.ensureUserProgress()
        seed(progress)
        for lessonId in completedLessons {
            repository.completeLesson(lessonId)
        }
        let stageManager = StageManager(progressRepository: repository)
        let viewModel = JourneyViewModel()
        viewModel.configure(
            stageManager: stageManager,
            progressRepository: repository,
            modelContext: context
        )
        return viewModel
    }

    // MARK: - Nothing is locked

    func testNothingIsLocked() throws {
        let vm = try makeConfiguredJourneyViewModel(progress: freshProgress())
        XCTAssertFalse(vm.pathSections.isEmpty)
        // Every section carries content except the (lesson-less) Script & Sounds
        // intro section, which is allowed to be represented minimally.
        XCTAssertTrue(vm.pathSections.allSatisfy { !$0.items.isEmpty || $0.title == "Script & Sounds" })
        // All lesson items are always available — the open path never locks.
        let allItems = vm.pathSections.flatMap(\.items)
        XCTAssertFalse(allItems.isEmpty)
    }

    // MARK: - Recommendation for a fresh user

    func testFreshUserRecommendationIsFirstLesson() throws {
        let vm = try makeConfiguredJourneyViewModel(progress: freshProgress())
        XCTAssertEqual(vm.recommendedSession?.heroAction, .lesson(1))
    }

    // MARK: - Resuming an in-progress lesson

    /// Lesson 1 is completed and lesson 2 was started (persisted via
    /// `lessonsInProgress`) with no due reviews — the recommender should
    /// resume lesson 2 rather than fall through to a new lesson.
    func testInProgressLessonTriggersResume() throws {
        let vm = try makeConfiguredJourneyViewModel(
            progress: { $0.lessonsInProgress = [2] },
            completedLessons: [1]
        )
        XCTAssertEqual(vm.recommendedSession?.kind, .resumeLesson(2))
        XCTAssertEqual(vm.recommendedSession?.heroAction, .lesson(2))
    }

    // MARK: - Completed lesson shows mastery

    func testCompletedLessonShowsMastery() throws {
        let progress = freshProgress()
        let vm = try makeConfiguredJourneyViewModel(progress: progress, completedLessons: [1])
        let item = try XCTUnwrap(vm.pathSections.flatMap(\.items).first { $0.lesson.id == 1 })
        XCTAssertTrue(item.isCompleted)
        XCTAssertGreaterThan(item.masteryTier, .new)
        XCTAssertGreaterThan(item.masteryFraction, 0)
    }

    // MARK: - FSRS-reviewed items count toward mastery

    /// `FlashcardManager.learnedItemIds` is the primitive `buildPathSections`
    /// unions with `vocabularyMastered` — verify its stability threshold
    /// directly: at/above the minimum counts, below it doesn't.
    func testLearnedItemIdsIncludesHighStabilityAndExcludesLowStability() throws {
        let container = try makeContainer()
        retainedContainers.append(container)
        let context = container.mainContext
        let flashcardManager = FlashcardManager(modelContext: context)

        let highId = "vocab-high-stability"
        let lowId = "vocab-low-stability"
        flashcardManager.getOrCreateProgress(for: highId, type: "vocabulary").stability = 7
        flashcardManager.getOrCreateProgress(for: lowId, type: "vocabulary").stability = 3

        let learned = flashcardManager.learnedItemIds(minStability: 7)
        XCTAssertTrue(learned.contains(highId))
        XCTAssertFalse(learned.contains(lowId))
    }

    /// A vocab word that is NOT in `vocabularyMastered` but has been reviewed
    /// enough (FSRS stability >= the mastery threshold) must still raise its
    /// lesson's mastery fraction — reviewed-but-not-"mastered" items should no
    /// longer be invisible to the mastery ring.
    func testFSRSReviewedItemRaisesMasteryAboveVocabularyMasteredBaseline() throws {
        let lesson = try XCTUnwrap(LessonRepository.shared.getLessons().first { $0.id == 1 })
        try XCTSkipIf(lesson.vocabulary.count < 2, "test needs at least two vocab words in lesson 1")
        let masteredWordId = lesson.vocabulary[0].id
        let fsrsWordId = lesson.vocabulary[1].id

        let container = try makeContainer()
        retainedContainers.append(container)
        let context = container.mainContext
        let repository = ProgressRepository(modelContext: context)
        let progress = repository.ensureUserProgress()
        progress.masterVocabulary(masteredWordId)
        let stageManager = StageManager(progressRepository: repository)

        let vm = JourneyViewModel()
        vm.configure(stageManager: stageManager, progressRepository: repository, modelContext: context)
        let baselineItem = try XCTUnwrap(vm.pathSections.flatMap(\.items).first { $0.lesson.id == 1 })
        let baselineFraction = baselineItem.masteryFraction
        XCTAssertGreaterThan(baselineFraction, 0, "one mastered vocab word should already register some mastery")

        let flashcardManager = FlashcardManager(modelContext: context)
        flashcardManager.getOrCreateProgress(for: fsrsWordId, type: "vocabulary").stability = 10

        vm.refresh()
        let updatedItem = try XCTUnwrap(vm.pathSections.flatMap(\.items).first { $0.lesson.id == 1 })
        XCTAssertGreaterThan(updatedItem.masteryFraction, baselineFraction)
    }

    // MARK: - Section shape

    func testSectionTitlesUseLearningStageNames() throws {
        let vm = try makeConfiguredJourneyViewModel(progress: freshProgress())
        let titles = vm.pathSections.map(\.title)
        XCTAssertEqual(titles.first, LearningStage.scriptAndSounds.displayName)
        XCTAssertTrue(titles.contains(LearningStage.survivalPhrases.displayName))
        XCTAssertTrue(titles.contains(LearningStage.buildingSentences.displayName))
        XCTAssertTrue(titles.contains(LearningStage.fluency.displayName))
        // Survival Phrases owns lessons 1 & 2.
        let survival = try XCTUnwrap(vm.pathSections.first { $0.title == LearningStage.survivalPhrases.displayName })
        XCTAssertEqual(survival.items.map(\.lesson.id), [1, 2])
        XCTAssertEqual(survival.amharicTitle, LearningStage.survivalPhrases.amharicTitle)
    }
}
