import SwiftData
import XCTest
@testable import Fidel___Learn_Amharic

/// Tests for the sync metadata fields (`syncModifiedAt`, `cloudSystemFields`)
/// added to the three SyncKit-synced models, and the explicit `.none`
/// CloudKit container used so SyncKit — not SwiftData's automatic mirroring —
/// owns sync. Selam models intentionally get no sync fields (device-local).
@MainActor
final class SyncFieldsTests: XCTestCase {

    /// Containers must outlive the model instances using their contexts.
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
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        retainedContainers.append(container)
        return container
    }

    private func assertDefaults(syncModifiedAt: Date, cloudSystemFields: Data?, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertNil(cloudSystemFields, file: file, line: line)
        XCTAssertEqual(syncModifiedAt.timeIntervalSinceNow, 0, accuracy: 5, file: file, line: line)
    }

    func test_userProgress_hasSyncFieldDefaults() throws {
        let container = try makeContainer()
        let progress = UserProgress(ownerUserId: LocalLearner.userId)
        container.mainContext.insert(progress)

        assertDefaults(syncModifiedAt: progress.syncModifiedAt, cloudSystemFields: progress.cloudSystemFields)
    }

    func test_flashcardProgress_hasSyncFieldDefaults() throws {
        let container = try makeContainer()
        let card = FlashcardProgress(itemId: "item-1", itemType: "vocabulary", ownerUserId: LocalLearner.userId)
        container.mainContext.insert(card)

        assertDefaults(syncModifiedAt: card.syncModifiedAt, cloudSystemFields: card.cloudSystemFields)
    }

    func test_characterTraceMastery_hasSyncFieldDefaults() throws {
        let container = try makeContainer()
        let mastery = CharacterTraceMastery(characterId: "0-1", ownerUserId: LocalLearner.userId)
        container.mainContext.insert(mastery)

        assertDefaults(syncModifiedAt: mastery.syncModifiedAt, cloudSystemFields: mastery.cloudSystemFields)
    }
}
