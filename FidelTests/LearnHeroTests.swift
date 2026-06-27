import SwiftData
import XCTest
@testable import Fidel___Learn_Amharic

/// Covers the Learn-tab next-action hero, per-activity progress, and the
/// StageCriterion current/target refactor.
@MainActor
final class LearnHeroTests: XCTestCase {

    // Keep each container alive for the lifetime of its repository.
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

    private func makeRepository() throws -> ProgressRepository {
        let container = try makeContainer()
        retainedContainers.append(container)
        return ProgressRepository(modelContext: container.mainContext)
    }

    /// Builds a configured JourneyViewModel. `configure` mutates the seeded
    /// UserProgress (set `currentStage` here — StageManager reads it at init).
    private func makeJourney(_ configure: (UserProgress) -> Void = { _ in }) throws -> JourneyViewModel {
        let repository = try makeRepository()
        let progress = repository.ensureUserProgress()
        configure(progress)
        let stageManager = StageManager(progressRepository: repository)
        let viewModel = JourneyViewModel()
        viewModel.configure(stageManager: stageManager, progressRepository: repository)
        return viewModel
    }

    private func ids(_ prefix: String, _ count: Int) -> [String] {
        (0..<count).map { "\(prefix)\($0)" }
    }

    // MARK: - Hero: fresh user

    func testFreshUserHeroPromptsFidelRecognition() throws {
        let viewModel = try makeJourney()

        let hero = try XCTUnwrap(viewModel.nextActionHero)
        XCTAssertEqual(hero.style, .action)
        XCTAssertEqual(hero.action, .practiceTracing)
        XCTAssertTrue(hero.title.contains("Recognize 50 more"), hero.title)
        XCTAssertTrue(hero.detail.contains("Survival Phrases"), hero.detail)
        XCTAssertEqual(hero.progress, 0, accuracy: 0.0001)
        XCTAssertEqual(hero.ctaLabel, "Practice Fidel")
    }

    func testHeroRemainingDecrementsWithProgress() throws {
        let viewModel = try makeJourney { $0.fidelCharactersRecognized = self.ids("c", 30) }

        let hero = try XCTUnwrap(viewModel.nextActionHero)
        XCTAssertTrue(hero.title.contains("Recognize 20 more"), hero.title)
        XCTAssertEqual(hero.progress, 0.6, accuracy: 0.0001)
    }

    func testHeroUsesSingularForOneRemaining() throws {
        let viewModel = try makeJourney { $0.fidelCharactersRecognized = self.ids("c", 49) }

        let hero = try XCTUnwrap(viewModel.nextActionHero)
        XCTAssertTrue(hero.title.contains("Recognize 1 more character"), hero.title)
        XCTAssertFalse(hero.title.contains("characters"), hero.title)
    }

    func testHeroReadyWhenCriterionMetButNotAdvanced() throws {
        // 50 recognized satisfies the next-stage criterion, but configure() does
        // not advance the stage, so the hero shows the transient "ready" state.
        let viewModel = try makeJourney { $0.fidelCharactersRecognized = self.ids("c", 50) }

        let hero = try XCTUnwrap(viewModel.nextActionHero)
        XCTAssertEqual(hero.style, .ready)
        XCTAssertFalse(hero.title.contains("0 more"), "must never say 'Recognize 0 more'")
    }

    // MARK: - Hero: fluency (no next stage)

    func testFluencyHeroIsFreePracticeWithoutCrash() throws {
        let viewModel = try makeJourney { $0.currentStage = LearningStage.fluency.rawValue }

        let hero = try XCTUnwrap(viewModel.nextActionHero)
        XCTAssertEqual(hero.style, .freePractice)
        XCTAssertEqual(hero.action, .flashcards)
        XCTAssertFalse(hero.title.lowercased().contains("character"), hero.title)
    }

    // MARK: - Hero: every criterion id maps to a usable action

    func testEveryNextStageCriterionMapsToNonEmptyAction() throws {
        // Each scenario makes a specific criterion the FIRST unmet one for its
        // gating stage, exercising every id -> action branch.
        // (currentStage, configure) -> expected substring in title
        try assertHeroAction(stage: .scriptAndSounds, titleContains: "Recognize") { _ in }
        try assertHeroAction(stage: .survivalPhrases, titleContains: "Complete") { _ in }            // lessons_1_2
        try assertHeroAction(stage: .survivalPhrases, titleContains: "Master") {                     // vocab_30
            $0.lessonsCompleted = [1, 2]
        }
        try assertHeroAction(stage: .buildingSentences, titleContains: "Complete") { _ in }          // all_lessons
        try assertHeroAction(stage: .buildingSentences, titleContains: "Master") {                   // vocab_100
            $0.lessonsCompleted = [1, 2, 3, 4, 5]
        }
        try assertHeroAction(stage: .buildingSentences, titleContains: "conversation") {             // conversations_5
            $0.lessonsCompleted = [1, 2, 3, 4, 5]
            $0.vocabularyMastered = self.ids("v", 100)
        }
    }

    private func assertHeroAction(
        stage: LearningStage,
        titleContains: String,
        configure: @escaping (UserProgress) -> Void
    ) throws {
        let viewModel = try makeJourney {
            $0.currentStage = stage.rawValue
            configure($0)
        }
        let hero = try XCTUnwrap(viewModel.nextActionHero, "no hero for stage \(stage)")
        XCTAssertEqual(hero.style, .action, "stage \(stage) should have an actionable hero")
        XCTAssertFalse(hero.ctaLabel.isEmpty, "stage \(stage) hero needs a CTA label")
        XCTAssertTrue(
            hero.title.localizedCaseInsensitiveContains(titleContains),
            "stage \(stage) title '\(hero.title)' should contain '\(titleContains)'"
        )
    }

    // MARK: - Practice Fidel activity progress

    func testPracticeFidelActivityProgressReflectsRecognition() throws {
        let viewModel = try makeJourney { $0.fidelCharactersRecognized = self.ids("c", 12) }

        let practiceFidel = try XCTUnwrap(viewModel.activities.first { $0.id == "practice_fidel" })
        let progress = try XCTUnwrap(practiceFidel.progress)
        XCTAssertEqual(progress.current, 12)
        XCTAssertEqual(progress.target, LearningStage.fidelRecognitionTarget)
        XCTAssertFalse(progress.isComplete)
        XCTAssertFalse(practiceFidel.isCompleted)
    }

    func testPracticeFidelActivityCompletesAtTarget() throws {
        let viewModel = try makeJourney { $0.fidelCharactersRecognized = self.ids("c", 60) }

        let practiceFidel = try XCTUnwrap(viewModel.activities.first { $0.id == "practice_fidel" })
        XCTAssertTrue(practiceFidel.isCompleted)
        // Progress is clamped to the target so the label never reads "60/50".
        XCTAssertEqual(practiceFidel.progress?.current, LearningStage.fidelRecognitionTarget)
    }

    // MARK: - StageCriterion current/target refactor

    func testCriterionEvaluateMatchesCurrentVersusTarget() throws {
        let repository = try makeRepository()
        let progress = repository.ensureUserProgress()

        let states: [(String, (UserProgress) -> Void)] = [
            ("empty", { _ in }),
            ("partial", {
                $0.fidelCharactersRecognized = self.ids("c", 25)
                $0.lessonsCompleted = [1]
                $0.vocabularyMastered = self.ids("v", 40)
                $0.conversationsPracticed = [1, 2]
            }),
            ("full", {
                $0.fidelCharactersRecognized = self.ids("c", 60)
                $0.lessonsCompleted = [1, 2, 3, 4, 5]
                $0.vocabularyMastered = self.ids("v", 120)
                $0.conversationsPracticed = [1, 2, 3, 4, 5, 6]
            })
        ]

        for (name, apply) in states {
            apply(progress)
            for stage in LearningStage.allCases {
                for criterion in LearningStage.criteria(for: stage) {
                    XCTAssertEqual(
                        criterion.evaluate(progress),
                        criterion.current(progress) >= criterion.target,
                        "[\(name)] \(criterion.id): evaluate must agree with current>=target"
                    )
                    let expectedRemaining = max(criterion.target - criterion.current(progress), 0)
                    XCTAssertEqual(criterion.remaining(progress), expectedRemaining, "[\(name)] \(criterion.id) remaining")
                }
            }
        }
    }

    func testCriterionProgressFractionIsClampedAndProportional() throws {
        let repository = try makeRepository()
        let progress = repository.ensureUserProgress()
        progress.fidelCharactersRecognized = ids("c", 25)

        let fidel = try XCTUnwrap(LearningStage.criteria(for: .survivalPhrases).first)
        XCTAssertEqual(fidel.progressFraction(progress), 0.5, accuracy: 0.0001)

        progress.fidelCharactersRecognized = ids("c", 80)
        XCTAssertEqual(fidel.progressFraction(progress), 1.0, accuracy: 0.0001, "fraction must clamp at 1")
    }

    // MARK: - Hero CTA routes to a screen that can satisfy the gate

    func testVocabHeroRoutesToMatchPairsNotFlashcards() throws {
        // Stage 1 with lessons 1 & 2 done -> first unmet criterion is vocab_30.
        // Flashcards only reschedule FSRS reviews; only Match Pairs masters vocab.
        let viewModel = try makeJourney {
            $0.currentStage = LearningStage.survivalPhrases.rawValue
            $0.lessonsCompleted = [1, 2]
        }
        let hero = try XCTUnwrap(viewModel.nextActionHero)
        XCTAssertEqual(hero.action, .matchPairs)
        XCTAssertNotEqual(hero.action, .flashcards)
    }

    func testHeroProgressBarOnlyWhenSingleNextStageCriterion() throws {
        // Stage 0 -> next stage has one criterion (fidel_50): hero bar is authoritative.
        let single = try XCTUnwrap(try makeJourney().nextActionHero)
        XCTAssertTrue(single.showsProgressBar)

        // Stage 1 -> next stage has two criteria: the hero defers to the ring/checklist.
        let multi = try XCTUnwrap(try makeJourney {
            $0.currentStage = LearningStage.survivalPhrases.rawValue
        }.nextActionHero)
        XCTAssertFalse(multi.showsProgressBar)
    }
}
