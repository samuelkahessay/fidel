// TracingSessionSizeTests — implemented in Task 9 of the open-learning-path plan.
import XCTest
import SwiftData
@testable import Fidel___Learn_Amharic

@MainActor
final class TracingSessionSizeTests: XCTestCase {

    /// Containers must outlive the repositories using their contexts.
    private var retainedContainers: [ModelContainer] = []

    override func setUp() {
        super.setUp()
        AppSettingsStore().dailyGoalTier = .regular
    }

    override func tearDown() {
        retainedContainers.removeAll()
        AppSettingsStore().dailyGoalTier = .regular
        super.tearDown()
    }

    private func freshRepo() throws -> ProgressRepository {
        let schema = Schema([
            UserProgress.self,
            FlashcardProgress.self,
            SelamConversation.self,
            SelamMessage.self,
            CharacterTraceMastery.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        retainedContainers.append(container)
        return ProgressRepository(modelContext: container.mainContext)
    }

    // A fresh learner has empty trace mastery, so the session fills to the tier
    // size from the 238 new characters — proving the size both scales and is exact.
    func testStandardSessionSizeFollowsTier() throws {
        let store = AppSettingsStore()

        store.dailyGoalTier = .casual
        let casual = TracingSessionViewModel(); casual.configure(progressRepository: try freshRepo())
        casual.startSession(plan: .standard)
        XCTAssertEqual(casual.items.count, DailyGoalTier.casual.tracingSessionSize) // 5

        store.dailyGoalTier = .intense
        let intense = TracingSessionViewModel(); intense.configure(progressRepository: try freshRepo())
        intense.startSession(plan: .standard)
        XCTAssertEqual(intense.items.count, DailyGoalTier.intense.tracingSessionSize) // 16
    }
}
