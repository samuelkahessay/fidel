import SwiftData
import XCTest
@testable import Fidel___Learn_Amharic

/// Tests for per-character tracing mastery: promotion rules, XP awards,
/// duplicate consolidation, and session composition.
@MainActor
final class TraceMasteryTests: XCTestCase {

    /// Containers must outlive the repositories using their contexts.
    private var retainedContainers: [ModelContainer] = []

    override func setUp() {
        super.setUp()
        // Session-composition asserts a tier-sized session (8 for .regular),
        // backed by real UserDefaults. Reset the shared tier so no other suite's
        // ordering can leak a different pace into this one.
        AppSettingsStore().dailyGoalTier = .regular
    }

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
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func makeRepository() throws -> ProgressRepository {
        let container = try makeContainer()
        retainedContainers.append(container)
        return ProgressRepository(modelContext: container.mainContext)
    }

    // MARK: - recordTraceCompletion

    func testFirstEverCompletionPromotesAndAwardsTraceXP() throws {
        let repository = try makeRepository()

        let outcome = repository.recordTraceCompletion(
            characterId: "0-1", completedLevel: 1, score: 85, misses: 1
        )

        XCTAssertTrue(outcome.didPromote)
        XCTAssertEqual(outcome.newLevel, 1)
        XCTAssertEqual(outcome.xpAwarded, 5)

        let progress = try XCTUnwrap(repository.getUserProgress())
        XCTAssertTrue(progress.charactersTraced.contains("0-1"))
        XCTAssertEqual(progress.totalXP, 5)

        let mastery = try XCTUnwrap(repository.getTraceMastery(for: "0-1"))
        XCTAssertEqual(mastery.level, 1)
        XCTAssertEqual(mastery.bestScore, 85)
        XCTAssertEqual(mastery.attempts, 1)
        XCTAssertEqual(mastery.totalMisses, 1)
        XCTAssertNotNil(mastery.lastPracticedAt)
    }

    func testPromotionsToHigherLevelsAwardBonusXP() throws {
        let repository = try makeRepository()
        _ = repository.recordTraceCompletion(characterId: "0-1", completedLevel: 1, score: 80, misses: 0)

        let toLevel2 = repository.recordTraceCompletion(characterId: "0-1", completedLevel: 2, score: 75, misses: 2)
        XCTAssertTrue(toLevel2.didPromote)
        XCTAssertEqual(toLevel2.newLevel, 2)
        XCTAssertEqual(toLevel2.xpAwarded, 8)

        let toLevel3 = repository.recordTraceCompletion(characterId: "0-1", completedLevel: 3, score: 95, misses: 0)
        XCTAssertTrue(toLevel3.didPromote)
        XCTAssertEqual(toLevel3.newLevel, 3)
        XCTAssertEqual(toLevel3.xpAwarded, 12)

        XCTAssertEqual(repository.getTotalXP(), 25)
    }

    func testLowScoreDoesNotPromote() throws {
        let repository = try makeRepository()

        let outcome = repository.recordTraceCompletion(
            characterId: "0-1", completedLevel: 1, score: 60, misses: 5
        )

        XCTAssertFalse(outcome.didPromote)
        XCTAssertEqual(outcome.newLevel, 0)
        XCTAssertEqual(outcome.xpAwarded, 1)

        let mastery = try XCTUnwrap(repository.getTraceMastery(for: "0-1"))
        XCTAssertEqual(mastery.level, 0)
        XCTAssertEqual(mastery.bestScore, 60)
    }

    func testRepeatPracticeAtCurrentLevelAwardsOneXP() throws {
        let repository = try makeRepository()
        _ = repository.recordTraceCompletion(characterId: "0-1", completedLevel: 1, score: 80, misses: 0)

        let repeated = repository.recordTraceCompletion(characterId: "0-1", completedLevel: 1, score: 92, misses: 0)

        XCTAssertFalse(repeated.didPromote)
        XCTAssertEqual(repeated.newLevel, 1)
        XCTAssertEqual(repeated.xpAwarded, 1)

        let mastery = try XCTUnwrap(repository.getTraceMastery(for: "0-1"))
        XCTAssertEqual(mastery.bestScore, 92)
        XCTAssertEqual(mastery.attempts, 2)
    }

    func testSkippedLevelDoesNotPromote() throws {
        let repository = try makeRepository()

        let outcome = repository.recordTraceCompletion(
            characterId: "0-1", completedLevel: 3, score: 100, misses: 0
        )

        XCTAssertFalse(outcome.didPromote)
        XCTAssertEqual(outcome.newLevel, 0)
    }

    func testDuplicateMasteryRowsAreConsolidated() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let repository = ProgressRepository(modelContext: context)

        let weaker = CharacterTraceMastery(characterId: "0-1", ownerUserId: LocalLearner.userId)
        weaker.level = 1
        weaker.bestScore = 50
        let stronger = CharacterTraceMastery(characterId: "0-1", ownerUserId: LocalLearner.userId)
        stronger.level = 2
        stronger.bestScore = 80
        context.insert(weaker)
        context.insert(stronger)

        let mastery = try XCTUnwrap(repository.getTraceMastery(for: "0-1"))
        XCTAssertEqual(mastery.level, 2)
        XCTAssertEqual(mastery.bestScore, 80)

        let remaining = try context.fetch(FetchDescriptor<CharacterTraceMastery>())
        XCTAssertEqual(remaining.count, 1)
    }

    // MARK: - Scoring formulas

    func testGuidedScoreFormula() {
        XCTAssertEqual(TracingSessionViewModel.guidedScore(misses: 0, hintsAutoPlayed: 0), 100)
        XCTAssertEqual(TracingSessionViewModel.guidedScore(misses: 2, hintsAutoPlayed: 1), 65)
        XCTAssertEqual(TracingSessionViewModel.guidedScore(misses: 9, hintsAutoPlayed: 3), 50)
    }

    func testSessionScoreUsesFixedScoreForAccessibilityCompletions() {
        let cleanStats = TraceEngine.TraceAttemptStats(misses: 0, hintsAutoPlayed: 0, duration: 4)
        XCTAssertEqual(
            TracingSessionViewModel.sessionScore(stats: cleanStats, usedGuideAssist: false), 100
        )

        var accessibleStats = cleanStats
        accessibleStats.accessibilityCompletions = 2
        XCTAssertEqual(
            TracingSessionViewModel.sessionScore(stats: accessibleStats, usedGuideAssist: false), 70,
            "Accessibility completions score a fixed 70 so promotion stays reachable"
        )
        XCTAssertEqual(
            TracingSessionViewModel.sessionScore(stats: accessibleStats, usedGuideAssist: true), 69,
            "Guide assist still caps below promotion"
        )
    }

    func testMemoryScoreFormulaAndAssistCap() {
        XCTAssertEqual(TracingSessionViewModel.memoryScore(evaluationScore: 0.5, usedAssist: false), 75)
        XCTAssertEqual(TracingSessionViewModel.memoryScore(evaluationScore: 0.9, usedAssist: false), 100)
        XCTAssertEqual(TracingSessionViewModel.memoryScore(evaluationScore: 0.9, usedAssist: true), 69)
    }

    // MARK: - Session composition

    func testStandardSessionMixesPromotionDueAndNewCharacters() throws {
        let repository = try makeRepository()
        _ = repository.recordTraceCompletion(characterId: "0-1", completedLevel: 1, score: 90, misses: 0)
        _ = repository.recordTraceCompletion(characterId: "1-1", completedLevel: 1, score: 90, misses: 0)
        _ = repository.recordTraceCompletion(characterId: "1-1", completedLevel: 2, score: 90, misses: 0)
        // Fully mastered character: should not be served.
        for level in 1...3 {
            _ = repository.recordTraceCompletion(characterId: "2-1", completedLevel: level, score: 95, misses: 0)
        }

        let viewModel = TracingSessionViewModel()
        viewModel.configure(progressRepository: repository)
        viewModel.startSession(plan: .standard)

        XCTAssertEqual(viewModel.items.count, 8)

        let itemsById = Dictionary(grouping: viewModel.items, by: { $0.character.id })
        XCTAssertEqual(itemsById["0-1"]?.first?.level, 2, "level-1 character should be served at level 2")
        XCTAssertEqual(itemsById["1-1"]?.first?.level, 3, "level-2 character should be served at level 3")
        XCTAssertNil(itemsById["2-1"], "mastered character should not be in the session")

        let newItems = viewModel.items.filter { !["0-1", "1-1", "2-1"].contains($0.character.id) }
        XCTAssertEqual(newItems.count, 6)
        XCTAssertTrue(newItems.allSatisfy { $0.level == 1 })
    }

    func testSingleSessionPlanServesNextLevel() throws {
        let repository = try makeRepository()
        _ = repository.recordTraceCompletion(characterId: "0-1", completedLevel: 1, score: 90, misses: 0)

        let character = try XCTUnwrap(
            AmharicData.fidelChart.flatMap { $0 }.first(where: { $0.id == "0-1" })
        )

        let viewModel = TracingSessionViewModel()
        viewModel.configure(progressRepository: repository)
        viewModel.startSession(plan: .single(character))

        XCTAssertEqual(viewModel.items.count, 1)
        XCTAssertEqual(viewModel.items[0].level, 2)
    }

    func testSingleSessionPlanCapsAtLevelThree() throws {
        let repository = try makeRepository()
        for level in 1...3 {
            _ = repository.recordTraceCompletion(characterId: "0-1", completedLevel: level, score: 95, misses: 0)
        }

        let character = try XCTUnwrap(
            AmharicData.fidelChart.flatMap { $0 }.first(where: { $0.id == "0-1" })
        )

        let viewModel = TracingSessionViewModel()
        viewModel.configure(progressRepository: repository)
        viewModel.startSession(plan: .single(character))

        XCTAssertEqual(viewModel.items[0].level, 3)
    }
}
