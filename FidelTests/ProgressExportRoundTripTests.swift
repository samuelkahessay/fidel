import Foundation
import SwiftData
import SyncKit
import XCTest
@testable import Fidel___Learn_Amharic

/// Verifies the JSON backup/restore round-trips the fields added by this
/// project: the pace tier (`AppSettingsStore.dailyGoalTier`) and the
/// streak-slack fields on `UserProgress`. Old backups predate both,
/// so restoring one must not throw and must fall back to sensible defaults.
@MainActor
final class ProgressExportRoundTripTests: XCTestCase {

    /// Containers must outlive the model instances/contexts using them.
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

    private func makeContainer() throws -> ModelContainer {
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
        return container
    }

    private func fetchProgress(from container: ModelContainer) throws -> UserProgress? {
        let ownerId = LocalLearner.userId
        let descriptor = FetchDescriptor<UserProgress>(
            predicate: #Predicate<UserProgress> { $0.ownerUserId == ownerId }
        )
        return try container.mainContext.fetch(descriptor).first
    }

    // MARK: - 1. Round-trip

    func testRoundTripCarriesPaceTierAndStreakSlackFields() throws {
        let sourceContainer = try makeContainer()
        let progress = UserProgress(ownerUserId: LocalLearner.userId)
        progress.totalXP = 500
        progress.streakFreezesAvailable = 2
        progress.weeklyStreakCount = 7
        progress.lastFreezeGrantWeek = 202627
        sourceContainer.mainContext.insert(progress)

        AppSettingsStore().dailyGoalTier = .serious

        let exportService = ProgressExportService(modelContext: sourceContainer.mainContext, settingsStore: AppSettingsStore())
        let data = try exportService.exportData()

        // Flip the live tier so the later assertion proves the import restored
        // it from the backup, rather than it simply having never changed.
        AppSettingsStore().dailyGoalTier = .casual

        let freshContainer = try makeContainer()
        let importService = ProgressExportService(modelContext: freshContainer.mainContext, settingsStore: AppSettingsStore())
        try importService.importData(data)

        let restored = try fetchProgress(from: freshContainer)
        XCTAssertEqual(restored?.totalXP, 500)
        XCTAssertEqual(restored?.streakFreezesAvailable, 2, "streakFreezesAvailable must survive the round trip")
        XCTAssertEqual(restored?.weeklyStreakCount, 7, "weeklyStreakCount must survive the round trip")
        XCTAssertEqual(restored?.lastFreezeGrantWeek, 202627, "lastFreezeGrantWeek must survive the round trip")
        XCTAssertEqual(AppSettingsStore().dailyGoalTier, .serious, "dailyGoalTier must be restored from the backup")
    }

    // MARK: - 2. Backward compatibility with old backups

    /// Hand-written backup JSON in the *old* shape: it has none of the keys
    /// this task adds (`dailyGoalTier`, `streakFreezesAvailable`,
    /// `weeklyStreakCount`, `lastFreezeGrantWeek`). A synthesized `Decodable`
    /// throws when a non-optional property's key is missing, so this is the
    /// regression the optional-with-default design guards against.
    private static let oldShapeBackupJSON: Data = {
        let json = """
        {
          "version": \(ProgressBackupSnapshot.currentVersion),
          "exportedAt": "2024-01-01T00:00:00Z",
          "userProgress": {
            "totalXP": 120,
            "currentStreak": 3,
            "longestStreak": 5,
            "lastPracticeDate": null,
            "lessonsCompleted": [1, 2],
            "patternsLearned": [],
            "vocabularyMastered": [],
            "conversationsPracticed": [],
            "dailyGoal": 50,
            "todayXP": 10,
            "achievements": [],
            "fidelCharactersRecognized": [],
            "charactersTraced": [],
            "currentStage": 1
          },
          "flashcards": [],
          "settings": {
            "dailyXPGoal": 50,
            "preferredResponseLanguage": "mixed",
            "showsTransliteration": true,
            "autoPlaysPronunciation": true,
            "hapticsEnabled": true,
            "selectedReferenceTab": 0,
            "showsAITools": true,
            "onboardingComplete": false,
            "lastOpenedActivity": null
          }
        }
        """
        return Data(json.utf8)
    }()

    func testOldShapeSnapshotDecodesWithNilNewFields() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let snapshot = try decoder.decode(ProgressBackupSnapshot.self, from: Self.oldShapeBackupJSON)

        XCTAssertNil(snapshot.userProgress?.streakFreezesAvailable)
        XCTAssertNil(snapshot.userProgress?.weeklyStreakCount)
        XCTAssertNil(snapshot.userProgress?.lastFreezeGrantWeek)
        XCTAssertNil(snapshot.settings.dailyGoalTier)
    }

    func testImportingOldShapeBackupDoesNotThrowAndAppliesDefaults() throws {
        let container = try makeContainer()
        AppSettingsStore().dailyGoalTier = .intense

        let importService = ProgressExportService(modelContext: container.mainContext, settingsStore: AppSettingsStore())

        XCTAssertNoThrow(try importService.importData(Self.oldShapeBackupJSON))

        let restored = try fetchProgress(from: container)
        XCTAssertEqual(restored?.totalXP, 120, "pre-existing fields must still import")
        XCTAssertEqual(restored?.streakFreezesAvailable, 0, "missing streakFreezesAvailable must default to 0")
        XCTAssertEqual(restored?.weeklyStreakCount, 0, "missing weeklyStreakCount must default to 0")
        XCTAssertEqual(restored?.lastFreezeGrantWeek, 0, "missing lastFreezeGrantWeek must default to 0")
        XCTAssertEqual(AppSettingsStore().dailyGoalTier, .regular, "missing dailyGoalTier must default to .regular")
    }

    // MARK: - Merge hygiene

    /// A divergent backup can list a lesson as in-progress that the local
    /// device has since completed. The import merge must not leave a completed
    /// lesson sitting in `lessonsInProgress`.
    func testCompletedLessonIsDroppedFromInProgressOnImport() throws {
        // Source backup: lessons 1 and 2 in progress (set directly to simulate
        // a divergent device; the normal guards would prevent this state).
        let sourceContainer = try makeContainer()
        let source = UserProgress(ownerUserId: LocalLearner.userId)
        source.lessonsInProgress = [1, 2]
        sourceContainer.mainContext.insert(source)
        let exportService = ProgressExportService(
            modelContext: sourceContainer.mainContext, settingsStore: AppSettingsStore())
        let data = try exportService.exportData()

        // Local device has already completed lesson 1.
        let targetContainer = try makeContainer()
        let local = UserProgress(ownerUserId: LocalLearner.userId)
        local.completeLesson(1)
        targetContainer.mainContext.insert(local)
        let importService = ProgressExportService(
            modelContext: targetContainer.mainContext, settingsStore: AppSettingsStore())
        try importService.importData(data)

        let restored = try fetchProgress(from: targetContainer)
        XCTAssertEqual(restored?.lessonsInProgress, [2], "completed lesson 1 must be filtered out; 2 remains")
        XCTAssertEqual(restored?.lessonsInProgress.contains(1), false)
        XCTAssertEqual(restored?.lessonsCompleted.contains(1), true)
    }

    func testImportMarksOnlyChangedCloudRecordsPending() throws {
        let sourceContainer = try makeContainer()
        let sourceProgress = UserProgress(ownerUserId: LocalLearner.userId)
        sourceProgress.totalXP = 900
        sourceContainer.mainContext.insert(sourceProgress)
        let sourceCard = FlashcardProgress(
            itemId: "vocab-1",
            itemType: "vocabulary",
            ownerUserId: LocalLearner.userId
        )
        sourceCard.repetitions = 4
        sourceContainer.mainContext.insert(sourceCard)
        let data = try ProgressExportService(modelContext: sourceContainer.mainContext).exportData()

        let targetContainer = try makeContainer()
        var markedIDs: [SyncID] = []
        let importService = ProgressExportService(
            modelContext: targetContainer.mainContext,
            onMutation: { markedIDs.append($0) }
        )
        let importStartedAt = Date.now

        let changedIDs = try importService.importData(data)

        XCTAssertEqual(Set(changedIDs), Set(markedIDs))
        XCTAssertEqual(Set(changedIDs), Set([sourceProgress.syncID, sourceCard.syncID]))
        let restoredProgress = try fetchProgress(from: targetContainer)
        XCTAssertGreaterThanOrEqual(restoredProgress?.syncModifiedAt ?? .distantPast, importStartedAt)
        let restoredCards = try targetContainer.mainContext.fetch(FetchDescriptor<FlashcardProgress>())
        XCTAssertGreaterThanOrEqual(restoredCards.first?.syncModifiedAt ?? .distantPast, importStartedAt)
    }

    func testRepeatingSameImportIsANoOp() throws {
        let sourceContainer = try makeContainer()
        let sourceProgress = UserProgress(ownerUserId: LocalLearner.userId)
        sourceProgress.totalXP = 42
        sourceProgress.lessonsCompleted = [1, 2]
        sourceContainer.mainContext.insert(sourceProgress)
        let data = try ProgressExportService(modelContext: sourceContainer.mainContext).exportData()

        let targetContainer = try makeContainer()
        var markedIDs: [SyncID] = []
        let importService = ProgressExportService(
            modelContext: targetContainer.mainContext,
            onMutation: { markedIDs.append($0) }
        )
        _ = try importService.importData(data)
        markedIDs.removeAll()
        let firstModifiedAt = try fetchProgress(from: targetContainer)?.syncModifiedAt

        let changedIDs = try importService.importData(data)

        XCTAssertTrue(changedIDs.isEmpty)
        XCTAssertTrue(markedIDs.isEmpty)
        XCTAssertEqual(try fetchProgress(from: targetContainer)?.syncModifiedAt, firstModifiedAt)
    }
}
