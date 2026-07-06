import SwiftData
import SyncKit
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

    // MARK: - onMutation wiring (Task 4)

    /// `ProgressRepository`'s injected `onMutation` callback is the single
    /// wiring point every ad-hoc call site relies on to reach `SyncEngine`.
    /// A spy in place of a real `SyncEngine` proves a genuine mutation
    /// (`addXP`) fires the callback with the affected model's own syncID,
    /// without needing a live CloudKit container.
    func test_addXP_firesOnMutationWithUserProgressSyncID() throws {
        let container = try makeContainer()
        var observedIDs: [SyncID] = []
        let repository = ProgressRepository(
            modelContext: container.mainContext,
            onMutation: { observedIDs.append($0) }
        )

        repository.addXP(10)

        let progress = try XCTUnwrap(repository.getUserProgress())
        XCTAssertEqual(observedIDs, [progress.syncID])
    }

    /// `recordTraceCompletion` touches two distinct synced records
    /// (`CharacterTraceMastery` directly, `UserProgress` via the internal
    /// `traceCharacter`/`addXP` call) — both syncIDs must reach the callback
    /// so neither record silently fails to publish.
    func test_recordTraceCompletion_firesOnMutationForBothMasteryAndUserProgress() throws {
        let container = try makeContainer()
        var observedIDs: [SyncID] = []
        let repository = ProgressRepository(
            modelContext: container.mainContext,
            onMutation: { observedIDs.append($0) }
        )

        repository.recordTraceCompletion(characterId: "0-1", completedLevel: 1, score: 90, misses: 0)

        let progress = try XCTUnwrap(repository.getUserProgress())
        let mastery = try XCTUnwrap(repository.getTraceMastery(for: "0-1"))
        XCTAssertTrue(observedIDs.contains(progress.syncID))
        XCTAssertTrue(observedIDs.contains(mastery.syncID))
    }

    /// A repository constructed with no `onMutation` (the default) must not
    /// crash — every one of the ~17 view call sites relies on this default
    /// being safe for read-only construction (e.g. `LessonCard.isCompleted`).
    func test_progressRepository_withoutOnMutation_doesNotCrash() throws {
        let container = try makeContainer()
        let repository = ProgressRepository(modelContext: container.mainContext)

        repository.addXP(5)

        XCTAssertEqual(repository.getUserProgress()?.totalXP, 5)
    }
}
