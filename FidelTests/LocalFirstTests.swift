import SwiftData
import XCTest
@testable import Fidel___Learn_Amharic

@MainActor
final class LocalFirstTests: XCTestCase {
    func testProgressRepositoryCreatesLocalDeviceProgress() throws {
        let container = try makeContainer()
        let repository = ProgressRepository(modelContext: container.mainContext)

        let progress = repository.ensureUserProgress()

        XCTAssertEqual(progress.ownerUserId, LocalLearner.userId)
    }

    func testSettingsStorePersistsDailyGoal() {
        let defaults = makeDefaults()
        var store = AppSettingsStore(defaults: defaults)

        store.dailyXPGoal = 120

        XCTAssertEqual(AppSettingsStore(defaults: defaults).dailyXPGoal, 120)
    }

    func testSettingsStoreClampsDailyGoal() {
        let defaults = makeDefaults()
        var store = AppSettingsStore(defaults: defaults)

        store.dailyXPGoal = -5

        XCTAssertEqual(store.dailyXPGoal, 10)
    }

    func testTracingCharacterAlsoCountsAsRecognized() {
        let progress = UserProgress(ownerUserId: LocalLearner.userId)

        progress.traceCharacter("0-1")

        XCTAssertEqual(progress.charactersTraced, ["0-1"])
        XCTAssertEqual(progress.fidelCharactersRecognized, ["0-1"])
    }

    func testDueCardsAreSortedBeforeFutureCards() {
        let now = Date.now
        let oldestDue = FlashcardProgress(itemId: "old", itemType: "vocabulary", ownerUserId: LocalLearner.userId)
        oldestDue.nextReviewDate = now.addingTimeInterval(-120)
        let newestDue = FlashcardProgress(itemId: "new", itemType: "vocabulary", ownerUserId: LocalLearner.userId)
        newestDue.nextReviewDate = now.addingTimeInterval(-30)
        let future = FlashcardProgress(itemId: "future", itemType: "vocabulary", ownerUserId: LocalLearner.userId)
        future.nextReviewDate = now.addingTimeInterval(120)

        let dueCards = FSRSAlgorithm.getDueCards(from: [future, newestDue, oldestDue])

        XCTAssertEqual(dueCards.map(\.itemId), ["old", "new"])
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            UserProgress.self,
            FlashcardProgress.self,
            SelamConversation.self,
            SelamMessage.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "FidelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
