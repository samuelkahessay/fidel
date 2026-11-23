import CloudKit
import SwiftData
import SyncKit
import XCTest

@testable import Fidel___Learn_Amharic

/// Tests for `SyncMapping` (CKRecord encode/apply/syncID on the three synced
/// models) and `FidelSyncStore` (the `SyncStore` conformance). Two of the
/// three models use field-wise merge on `applyRemoteRecord` mirroring
/// `ProgressRepository`'s consolidation logic rather than plain last-write-wins;
/// see individual test comments for which policy applies to which model.
@MainActor
final class FidelSyncStoreTests: XCTestCase {

    /// Containers must outlive the model instances using their contexts.
    private var retainedContainers: [ModelContainer] = []

    override func tearDown() {
        retainedContainers.removeAll()
        super.tearDown()
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            UserProgress.self,
            FlashcardProgress.self,
            SelamConversation.self,
            SelamMessage.self,
            CharacterTraceMastery.self,
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        retainedContainers.append(container)
        return ModelContext(container)
    }

    private let zoneID = CKRecordZone.ID(zoneName: "test-zone", ownerName: CKCurrentUserDefaultName)

    // MARK: - Round-trip: UserProgress

    func test_userProgress_encodeApply_roundTripsEveryField() throws {
        let contextA = try makeContext()
        let contextB = try makeContext()

        let source = UserProgress(ownerUserId: "user-1")
        source.totalXP = 1234
        source.currentStreak = 7
        source.longestStreak = 21
        source.lastPracticeDate = Date(timeIntervalSince1970: 1_700_000_000)
        source.lessonsCompleted = [1, 2, 3]
        source.lessonsInProgress = [4, 5]
        source.patternsLearned = ["pattern-a", "pattern-b"]
        source.vocabularyMastered = ["word-1", "word-2", "word-3"]
        source.conversationsPracticed = [10, 20]
        source.dailyGoal = 80
        source.todayXP = 42
        source.achievements = ["ach-1", "ach-2"]
        source.fidelCharactersRecognized = ["0-1", "0-2"]
        source.charactersTraced = ["0-1"]
        source.currentStage = 3
        source.streakFreezesAvailable = 2
        source.weeklyStreakCount = 5
        source.lastFreezeGrantWeek = 202601
        source.updatedAt = Date(timeIntervalSince1970: 1_700_000_500)
        source.syncModifiedAt = Date(timeIntervalSince1970: 1_700_000_600)
        contextA.insert(source)

        let record = CKRecord(recordType: UserProgress.recordType, recordID: source.syncID.recordID(in: zoneID))
        source.encode(onto: record)

        let destination = UserProgress()
        contextB.insert(destination)
        destination.apply(record: record)

        XCTAssertEqual(destination.ownerUserId, "user-1")
        XCTAssertEqual(destination.totalXP, 1234)
        XCTAssertEqual(destination.currentStreak, 7)
        XCTAssertEqual(destination.longestStreak, 21)
        XCTAssertEqual(destination.lastPracticeDate, source.lastPracticeDate)
        XCTAssertEqual(destination.lessonsCompleted.count, 3)
        XCTAssertEqual(destination.lessonsCompleted[0], 1)
        XCTAssertEqual(destination.lessonsCompleted[1], 2)
        XCTAssertEqual(destination.lessonsCompleted[2], 3)
        XCTAssertEqual(destination.lessonsInProgress.count, 2)
        XCTAssertEqual(destination.lessonsInProgress[0], 4)
        XCTAssertEqual(destination.lessonsInProgress[1], 5)
        XCTAssertEqual(destination.patternsLearned.count, 2)
        XCTAssertEqual(destination.patternsLearned[0], "pattern-a")
        XCTAssertEqual(destination.patternsLearned[1], "pattern-b")
        XCTAssertEqual(destination.vocabularyMastered.count, 3)
        XCTAssertEqual(destination.vocabularyMastered[0], "word-1")
        XCTAssertEqual(destination.vocabularyMastered[1], "word-2")
        XCTAssertEqual(destination.vocabularyMastered[2], "word-3")
        XCTAssertEqual(destination.conversationsPracticed.count, 2)
        XCTAssertEqual(destination.conversationsPracticed[0], 10)
        XCTAssertEqual(destination.conversationsPracticed[1], 20)
        XCTAssertEqual(destination.dailyGoal, 80)
        XCTAssertEqual(destination.todayXP, 42)
        XCTAssertEqual(destination.achievements.count, 2)
        XCTAssertEqual(destination.achievements[0], "ach-1")
        XCTAssertEqual(destination.achievements[1], "ach-2")
        XCTAssertEqual(destination.fidelCharactersRecognized.count, 2)
        XCTAssertEqual(destination.fidelCharactersRecognized[0], "0-1")
        XCTAssertEqual(destination.fidelCharactersRecognized[1], "0-2")
        XCTAssertEqual(destination.charactersTraced.count, 1)
        XCTAssertEqual(destination.charactersTraced[0], "0-1")
        XCTAssertEqual(destination.currentStage, 3)
        XCTAssertEqual(destination.streakFreezesAvailable, 2)
        XCTAssertEqual(destination.weeklyStreakCount, 5)
        XCTAssertEqual(destination.lastFreezeGrantWeek, 202601)
        XCTAssertEqual(destination.updatedAt, source.updatedAt)
        XCTAssertEqual(destination.syncModifiedAt, source.syncModifiedAt)
        XCTAssertEqual(record[SyncKeys.schemaVersion] as? Int, 1)
    }

    func test_userProgress_firstUpload_omitsEmptyArraysCloudKitCannotInfer() throws {
        let progress = UserProgress(ownerUserId: "new-user")
        let record = CKRecord(
            recordType: UserProgress.recordType,
            recordID: progress.syncID.recordID(in: zoneID)
        )

        progress.encode(onto: record)

        XCTAssertNil(record["lessonsCompleted"])
        XCTAssertNil(record["lessonsInProgress"])
        XCTAssertNil(record["patternsLearned"])
        XCTAssertNil(record["vocabularyMastered"])
        XCTAssertNil(record["conversationsPracticed"])
        XCTAssertNil(record["achievements"])
        XCTAssertNil(record["fidelCharactersRecognized"])
        XCTAssertNil(record["charactersTraced"])
    }

    func test_userProgress_existingRecord_encodesEmptyArraysToPropagateClears() throws {
        let progress = UserProgress(ownerUserId: "existing-user")
        progress.cloudSystemFields = Data([0x01])
        let record = CKRecord(
            recordType: UserProgress.recordType,
            recordID: progress.syncID.recordID(in: zoneID)
        )

        progress.encode(onto: record)

        XCTAssertEqual(record["lessonsCompleted"] as? [Int], [])
        XCTAssertEqual(record["achievements"] as? [String], [])
        XCTAssertEqual(record["charactersTraced"] as? [String], [])
    }

    // MARK: - Round-trip: FlashcardProgress

    func test_flashcardProgress_encodeApply_roundTripsEveryField() throws {
        let contextA = try makeContext()
        let contextB = try makeContext()

        let source = FlashcardProgress(itemId: "vocab:42", itemType: "vocabulary", ownerUserId: "user-1")
        source.easeFactor = 2.35
        source.interval = 6
        source.repetitions = 4
        source.nextReviewDate = Date(timeIntervalSince1970: 1_700_100_000)
        source.lastReviewDate = Date(timeIntervalSince1970: 1_700_050_000)
        source.stability = 12.5
        source.difficulty = 3.75
        source.lapses = 2
        source.updatedAt = Date(timeIntervalSince1970: 1_700_100_100)
        source.syncModifiedAt = Date(timeIntervalSince1970: 1_700_100_200)
        contextA.insert(source)

        let record = CKRecord(recordType: FlashcardProgress.recordType, recordID: source.syncID.recordID(in: zoneID))
        source.encode(onto: record)

        let destination = FlashcardProgress(itemId: "", itemType: "")
        contextB.insert(destination)
        destination.apply(record: record)

        XCTAssertEqual(destination.ownerUserId, "user-1")
        XCTAssertEqual(destination.itemId, "vocab:42")
        XCTAssertEqual(destination.itemType, "vocabulary")
        XCTAssertEqual(destination.easeFactor, 2.35)
        XCTAssertEqual(destination.interval, 6)
        XCTAssertEqual(destination.repetitions, 4)
        XCTAssertEqual(destination.nextReviewDate, source.nextReviewDate)
        XCTAssertEqual(destination.lastReviewDate, source.lastReviewDate)
        XCTAssertEqual(destination.stability, 12.5)
        XCTAssertEqual(destination.difficulty, 3.75)
        XCTAssertEqual(destination.lapses, 2)
        XCTAssertEqual(destination.updatedAt, source.updatedAt)
        XCTAssertEqual(destination.syncModifiedAt, source.syncModifiedAt)
        XCTAssertEqual(record[SyncKeys.schemaVersion] as? Int, 1)
    }

    // MARK: - Round-trip: CharacterTraceMastery

    func test_characterTraceMastery_encodeApply_roundTripsEveryField() throws {
        let contextA = try makeContext()
        let contextB = try makeContext()

        let source = CharacterTraceMastery(characterId: "0-7", ownerUserId: "user-1")
        source.level = 2
        source.bestScore = 88
        source.attempts = 9
        source.totalMisses = 14
        source.lastPracticedAt = Date(timeIntervalSince1970: 1_700_200_000)
        source.updatedAt = Date(timeIntervalSince1970: 1_700_200_100)
        source.syncModifiedAt = Date(timeIntervalSince1970: 1_700_200_200)
        contextA.insert(source)

        let record = CKRecord(recordType: CharacterTraceMastery.recordType, recordID: source.syncID.recordID(in: zoneID))
        source.encode(onto: record)

        let destination = CharacterTraceMastery(characterId: "", ownerUserId: "")
        contextB.insert(destination)
        destination.apply(record: record)

        XCTAssertEqual(destination.ownerUserId, "user-1")
        XCTAssertEqual(destination.characterId, "0-7")
        XCTAssertEqual(destination.level, 2)
        XCTAssertEqual(destination.bestScore, 88)
        XCTAssertEqual(destination.attempts, 9)
        XCTAssertEqual(destination.totalMisses, 14)
        XCTAssertEqual(destination.lastPracticedAt, source.lastPracticedAt)
        XCTAssertEqual(destination.updatedAt, source.updatedAt)
        XCTAssertEqual(destination.syncModifiedAt, source.syncModifiedAt)
        XCTAssertEqual(record[SyncKeys.schemaVersion] as? Int, 1)
    }

    // MARK: - UserProgress field-wise merge

    func test_userProgressMergeUnionsArraysAndMaxesCounters() throws {
        let context = try makeContext()
        let store = FidelSyncStore(context: context)

        let local = UserProgress(ownerUserId: "user-1")
        local.lessonsCompleted = [1, 2]
        local.totalXP = 100
        local.syncModifiedAt = Date(timeIntervalSince1970: 1_700_000_000)
        context.insert(local)
        try context.save()

        let remote = UserProgress(ownerUserId: "user-1")
        remote.lessonsCompleted = [2, 3]
        remote.totalXP = 80
        remote.syncModifiedAt = Date(timeIntervalSince1970: 1_700_000_050)
        let record = CKRecord(recordType: UserProgress.recordType, recordID: local.syncID.recordID(in: zoneID))
        remote.encode(onto: record)

        let result = try store.applyRemoteRecord(record)

        XCTAssertEqual(local.lessonsCompleted, [1, 2, 3])
        XCTAssertEqual(local.totalXP, 100)
        XCTAssertEqual(result, .localNewer)
    }

    func test_userProgressMergeTakesNewerSideForScalarFields() throws {
        let context = try makeContext()
        let store = FidelSyncStore(context: context)

        let local = UserProgress(ownerUserId: "user-1")
        local.currentStreak = 3
        local.dailyGoal = 50
        local.todayXP = 10
        local.lastPracticeDate = Date(timeIntervalSince1970: 1_700_000_000)
        local.syncModifiedAt = Date(timeIntervalSince1970: 1_700_000_000)
        context.insert(local)
        try context.save()

        // Remote is the newer side (later syncModifiedAt): its scalar values win.
        let remote = UserProgress(ownerUserId: "user-1")
        remote.currentStreak = 9
        remote.dailyGoal = 100
        remote.todayXP = 55
        remote.lastPracticeDate = Date(timeIntervalSince1970: 1_700_050_000)
        remote.syncModifiedAt = Date(timeIntervalSince1970: 1_700_100_000)
        let record = CKRecord(recordType: UserProgress.recordType, recordID: local.syncID.recordID(in: zoneID))
        remote.encode(onto: record)

        let result = try store.applyRemoteRecord(record)

        XCTAssertEqual(local.currentStreak, 9)
        XCTAssertEqual(local.dailyGoal, 100)
        XCTAssertEqual(local.todayXP, 55)
        XCTAssertEqual(local.lastPracticeDate, remote.lastPracticeDate)
        // All arrays are empty on both sides and every merged scalar now
        // equals what the remote record already carried, so no re-upload
        // is needed.
        XCTAssertEqual(result, .applied)
    }

    /// Regression for the array-merge livelock: two independent stores hold
    /// the same *set* of additive elements in different orders. Because
    /// `mergedUnion` starts from each side's own local order, an
    /// order-sensitive `Array ==` convergence check would never see the
    /// merged result as equal to the remote's array, so both sides would
    /// return `.localNewer` forever and re-upload without end. The
    /// convergence check must compare these fields as `Set`s.
    func test_userProgressMergeConvergesWhenAdditiveArraysDifferOnlyInOrder() throws {
        let contextA = try makeContext()
        let storeA = FidelSyncStore(context: contextA)

        let local = UserProgress(ownerUserId: "user-1")
        local.lessonsCompleted = [1, 2, 3]
        local.achievements = ["ach-a", "ach-b", "ach-c"]
        local.syncModifiedAt = Date(timeIntervalSince1970: 1_700_000_000)
        contextA.insert(local)
        try contextA.save()

        // Remote independently holds the exact same sets, but in a different
        // element order (as if merged/reconciled on another device).
        let remote = UserProgress(ownerUserId: "user-1")
        remote.lessonsCompleted = [2, 3, 1]
        remote.achievements = ["ach-b", "ach-c", "ach-a"]
        remote.syncModifiedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let record = CKRecord(recordType: UserProgress.recordType, recordID: local.syncID.recordID(in: zoneID))
        remote.encode(onto: record)

        let firstApply = try storeA.applyRemoteRecord(record)

        XCTAssertEqual(Set(local.lessonsCompleted), Set([1, 2, 3]))
        XCTAssertEqual(Set(local.achievements), Set(["ach-a", "ach-b", "ach-c"]))
        XCTAssertEqual(firstApply, .applied, "same set in different order must converge, not livelock")

        // Idempotency: applying the identical remote record again must still
        // converge (no flapping between .applied and .localNewer).
        let secondApply = try storeA.applyRemoteRecord(record)
        XCTAssertEqual(secondApply, .applied)
    }

    /// `lessonsInProgress` has removal semantics (a lesson leaves the set once
    /// completed elsewhere), so it must NOT be unioned — union can never
    /// remove, which would make a completed-elsewhere lesson stay "in
    /// progress" forever. It is newest-side-wins like currentStreak/todayXP.
    func test_userProgressMergeLessonsInProgressIsNewestSideWinsNotUnion() throws {
        let context = try makeContext()
        let store = FidelSyncStore(context: context)

        let local = UserProgress(ownerUserId: "user-1")
        local.lessonsInProgress = [5]
        local.syncModifiedAt = Date(timeIntervalSince1970: 1_700_100_000)  // local is newer

        let remote = UserProgress(ownerUserId: "user-1")
        remote.lessonsInProgress = [9]
        remote.syncModifiedAt = Date(timeIntervalSince1970: 1_700_000_000)  // remote is older
        context.insert(local)
        try context.save()

        let record = CKRecord(recordType: UserProgress.recordType, recordID: local.syncID.recordID(in: zoneID))
        remote.encode(onto: record)

        let result = try store.applyRemoteRecord(record)

        // Local is newer, so local's set wins wholesale — not unioned with
        // remote's [9].
        XCTAssertEqual(local.lessonsInProgress, [5])
        XCTAssertEqual(result, .localNewer)
    }

    /// Remote-newer case: the remote's set replaces local's wholesale, again
    /// proving this is whole-value newest-side-wins, not a union.
    func test_userProgressMergeLessonsInProgressTakesRemoteWholesaleWhenRemoteIsNewer() throws {
        let context = try makeContext()
        let store = FidelSyncStore(context: context)

        let local = UserProgress(ownerUserId: "user-1")
        local.lessonsInProgress = [5]
        local.syncModifiedAt = Date(timeIntervalSince1970: 1_700_000_000)  // local is older
        context.insert(local)
        try context.save()

        let remote = UserProgress(ownerUserId: "user-1")
        remote.lessonsInProgress = [9]
        remote.syncModifiedAt = Date(timeIntervalSince1970: 1_700_100_000)  // remote is newer
        let record = CKRecord(recordType: UserProgress.recordType, recordID: local.syncID.recordID(in: zoneID))
        remote.encode(onto: record)

        let result = try store.applyRemoteRecord(record)

        // Remote is newer, so remote's set replaces local's wholesale — not
        // unioned to [5, 9].
        XCTAssertEqual(local.lessonsInProgress, [9])
        XCTAssertEqual(result, .applied)
    }

    /// `streakFreezesAvailable` and `weeklyStreakCount` are non-monotonic
    /// (freezes are consumable; the weekly count resets), so `max` would
    /// refund a freeze spent locally as soon as a stale, freeze-rich remote
    /// record merges in. They must be newest-side-wins like the other
    /// per-period counters.
    func test_userProgressMergeStreakFreezesAvailableIsNewestSideWinsNotMax() throws {
        let context = try makeContext()
        let store = FidelSyncStore(context: context)

        let local = UserProgress(ownerUserId: "user-1")
        local.streakFreezesAvailable = 1  // a freeze was just spent locally
        local.weeklyStreakCount = 2
        local.syncModifiedAt = Date(timeIntervalSince1970: 1_700_100_000)  // local is newer
        context.insert(local)
        try context.save()

        let remote = UserProgress(ownerUserId: "user-1")
        remote.streakFreezesAvailable = 3  // stale, higher remote value
        remote.weeklyStreakCount = 5
        remote.syncModifiedAt = Date(timeIntervalSince1970: 1_700_000_000)  // remote is older
        let record = CKRecord(recordType: UserProgress.recordType, recordID: local.syncID.recordID(in: zoneID))
        remote.encode(onto: record)

        let result = try store.applyRemoteRecord(record)

        // Local is newer: its lower freeze count and weekly count win — the
        // spent freeze must NOT be refunded by max().
        XCTAssertEqual(local.streakFreezesAvailable, 1)
        XCTAssertEqual(local.weeklyStreakCount, 2)
        XCTAssertEqual(result, .localNewer)
    }

    // MARK: - FlashcardProgress plain LWW

    func test_flashcardLWWKeepsNewerWholeRecord() throws {
        let context = try makeContext()
        let store = FidelSyncStore(context: context)

        let local = FlashcardProgress(itemId: "word-1", itemType: "vocabulary", ownerUserId: "user-1")
        local.repetitions = 1
        local.interval = 1
        local.easeFactor = 2.5
        local.syncModifiedAt = Date(timeIntervalSince1970: 1_700_000_000)
        context.insert(local)
        try context.save()

        let remote = FlashcardProgress(itemId: "word-1", itemType: "vocabulary", ownerUserId: "user-1")
        remote.repetitions = 5
        remote.interval = 12
        remote.easeFactor = 2.8
        remote.syncModifiedAt = Date(timeIntervalSince1970: 1_700_100_000)
        let record = CKRecord(recordType: FlashcardProgress.recordType, recordID: local.syncID.recordID(in: zoneID))
        remote.encode(onto: record)

        let result = try store.applyRemoteRecord(record)

        XCTAssertEqual(local.repetitions, 5)
        XCTAssertEqual(local.interval, 12)
        XCTAssertEqual(local.easeFactor, 2.8)
        XCTAssertEqual(result, .applied)
    }

    func test_flashcardLWWKeepsLocalWhenLocalIsNewer() throws {
        let context = try makeContext()
        let store = FidelSyncStore(context: context)

        let local = FlashcardProgress(itemId: "word-1", itemType: "vocabulary", ownerUserId: "user-1")
        local.repetitions = 5
        local.interval = 12
        local.syncModifiedAt = Date(timeIntervalSince1970: 1_700_100_000)
        context.insert(local)
        try context.save()

        let remote = FlashcardProgress(itemId: "word-1", itemType: "vocabulary", ownerUserId: "user-1")
        remote.repetitions = 1
        remote.interval = 1
        remote.syncModifiedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let record = CKRecord(recordType: FlashcardProgress.recordType, recordID: local.syncID.recordID(in: zoneID))
        remote.encode(onto: record)

        let result = try store.applyRemoteRecord(record)

        // Local wins: not applied, values remain untouched.
        XCTAssertEqual(local.repetitions, 5)
        XCTAssertEqual(local.interval, 12)
        XCTAssertEqual(result, .localNewer)
    }

    /// A malformed remote record with NO `modifiedAt` key set must lose to a
    /// local record that has a real timestamp — an absent timestamp must
    /// default to `.distantPast`, not `.distantFuture` (which would make a
    /// broken remote record look infinitely new and clobber real local FSRS
    /// scheduling state).
    func test_flashcardLWWAbsentRemoteTimestampLosesToRealLocalTimestamp() throws {
        let context = try makeContext()
        let store = FidelSyncStore(context: context)

        let local = FlashcardProgress(itemId: "word-1", itemType: "vocabulary", ownerUserId: "user-1")
        local.repetitions = 5
        local.interval = 12
        local.easeFactor = 2.8
        local.stability = 20.0
        local.difficulty = 4.0
        local.syncModifiedAt = Date(timeIntervalSince1970: 1_700_000_000)
        context.insert(local)
        try context.save()

        // Build a remote record without ever setting SyncKeys.modifiedAt.
        let remote = FlashcardProgress(itemId: "word-1", itemType: "vocabulary", ownerUserId: "user-1")
        remote.repetitions = 1
        remote.interval = 1
        remote.easeFactor = 2.5
        let record = CKRecord(recordType: FlashcardProgress.recordType, recordID: local.syncID.recordID(in: zoneID))
        record["ownerUserId"] = remote.ownerUserId
        record["itemId"] = remote.itemId
        record["itemType"] = remote.itemType
        record["easeFactor"] = remote.easeFactor
        record["interval"] = remote.interval
        record["repetitions"] = remote.repetitions
        record["updatedAt"] = remote.updatedAt
        // Deliberately NOT setting record[SyncKeys.modifiedAt].
        XCTAssertNil(record[SyncKeys.modifiedAt], "test setup must not set modifiedAt")

        let result = try store.applyRemoteRecord(record)

        XCTAssertEqual(result, .localNewer)
        XCTAssertEqual(local.repetitions, 5)
        XCTAssertEqual(local.interval, 12)
        XCTAssertEqual(local.easeFactor, 2.8)
        XCTAssertEqual(local.stability, 20.0)
        XCTAssertEqual(local.difficulty, 4.0)
    }

    // MARK: - CharacterTraceMastery field-wise merge (mirrors consolidateTraceMastery: max, not sum)

    func test_traceMasteryMergeMaxes() throws {
        let context = try makeContext()
        let store = FidelSyncStore(context: context)

        let local = CharacterTraceMastery(characterId: "0-1", ownerUserId: "user-1")
        local.level = 2
        local.bestScore = 70
        local.attempts = 5
        local.totalMisses = 20
        local.lastPracticedAt = Date(timeIntervalSince1970: 1_700_000_000)
        local.syncModifiedAt = Date(timeIntervalSince1970: 1_700_000_000)
        context.insert(local)
        try context.save()

        let remote = CharacterTraceMastery(characterId: "0-1", ownerUserId: "user-1")
        remote.level = 1  // lower than local
        remote.bestScore = 95  // higher than local
        remote.attempts = 3  // lower than local
        remote.totalMisses = 30  // higher than local
        remote.lastPracticedAt = Date(timeIntervalSince1970: 1_700_050_000)  // newer than local
        remote.syncModifiedAt = Date(timeIntervalSince1970: 1_700_050_000)
        let record = CKRecord(recordType: CharacterTraceMastery.recordType, recordID: local.syncID.recordID(in: zoneID))
        remote.encode(onto: record)

        let result = try store.applyRemoteRecord(record)

        // Per consolidateTraceMastery (ProgressRepository.swift:305-332): every
        // field is max(local, remote), including attempts/totalMisses (NOT
        // summed — summing would double-count on repeated merges).
        XCTAssertEqual(local.level, 2)
        XCTAssertEqual(local.bestScore, 95)
        XCTAssertEqual(local.attempts, 5)
        XCTAssertEqual(local.totalMisses, 30)
        XCTAssertEqual(local.lastPracticedAt, remote.lastPracticedAt)
        // Merged differs from what the remote record carried (level/attempts
        // stayed at local's higher values) so the engine must re-upload.
        XCTAssertEqual(result, .localNewer)
    }

    // MARK: - Insert-on-first-fetch natural-key parsing

    func test_insertOnFirstFetchParsesNaturalKeys_userProgress() throws {
        let context = try makeContext()
        let store = FidelSyncStore(context: context)

        let id = SyncID(recordType: UserProgress.recordType, id: "user-42")
        let record = CKRecord(recordType: UserProgress.recordType, recordID: id.recordID(in: zoneID))
        let remoteModel = UserProgress(ownerUserId: "user-42")
        remoteModel.totalXP = 555
        remoteModel.currentStage = 2
        remoteModel.encode(onto: record)

        let result = try store.applyRemoteRecord(record)

        let inserted = try context.fetch(FetchDescriptor<UserProgress>()).first
        XCTAssertNotNil(inserted)
        XCTAssertEqual(inserted?.ownerUserId, "user-42")
        XCTAssertEqual(inserted?.totalXP, 555)
        XCTAssertEqual(inserted?.currentStage, 2)
        XCTAssertEqual(result, .applied)
    }

    func test_insertOnFirstFetchParsesNaturalKeys_flashcardProgress_simpleItemId() throws {
        let context = try makeContext()
        let store = FidelSyncStore(context: context)

        let id = SyncID(recordType: FlashcardProgress.recordType, id: "user-42:vocabulary:word-9")
        let record = CKRecord(recordType: FlashcardProgress.recordType, recordID: id.recordID(in: zoneID))
        let remoteModel = FlashcardProgress(itemId: "word-9", itemType: "vocabulary", ownerUserId: "user-42")
        remoteModel.repetitions = 3
        remoteModel.encode(onto: record)

        let result = try store.applyRemoteRecord(record)

        let inserted = try context.fetch(FetchDescriptor<FlashcardProgress>()).first
        XCTAssertNotNil(inserted)
        XCTAssertEqual(inserted?.ownerUserId, "user-42")
        XCTAssertEqual(inserted?.itemType, "vocabulary")
        XCTAssertEqual(inserted?.itemId, "word-9")
        XCTAssertEqual(inserted?.repetitions, 3)
        XCTAssertEqual(result, .applied)
    }

    /// itemId itself contains a colon (e.g. a compound vocabulary word id) —
    /// proves the parser splits on only the first two colons, not naively on
    /// every colon.
    func test_insertOnFirstFetchParsesNaturalKeys_flashcardProgress_itemIdContainsColon() throws {
        let context = try makeContext()
        let store = FidelSyncStore(context: context)

        let id = SyncID(recordType: FlashcardProgress.recordType, id: "user-42:vocabulary:word-9:variant-2")
        let record = CKRecord(recordType: FlashcardProgress.recordType, recordID: id.recordID(in: zoneID))
        let remoteModel = FlashcardProgress(itemId: "word-9:variant-2", itemType: "vocabulary", ownerUserId: "user-42")
        remoteModel.repetitions = 7
        remoteModel.encode(onto: record)

        let result = try store.applyRemoteRecord(record)

        let inserted = try context.fetch(FetchDescriptor<FlashcardProgress>()).first
        XCTAssertNotNil(inserted)
        XCTAssertEqual(inserted?.ownerUserId, "user-42")
        XCTAssertEqual(inserted?.itemType, "vocabulary")
        XCTAssertEqual(inserted?.itemId, "word-9:variant-2")
        XCTAssertEqual(inserted?.repetitions, 7)
        XCTAssertEqual(result, .applied)
    }

    func test_insertOnFirstFetchParsesNaturalKeys_characterTraceMastery() throws {
        let context = try makeContext()
        let store = FidelSyncStore(context: context)

        let id = SyncID(recordType: CharacterTraceMastery.recordType, id: "user-42:0-3")
        let record = CKRecord(recordType: CharacterTraceMastery.recordType, recordID: id.recordID(in: zoneID))
        let remoteModel = CharacterTraceMastery(characterId: "0-3", ownerUserId: "user-42")
        remoteModel.level = 1
        remoteModel.bestScore = 60
        remoteModel.encode(onto: record)

        let result = try store.applyRemoteRecord(record)

        let inserted = try context.fetch(FetchDescriptor<CharacterTraceMastery>()).first
        XCTAssertNotNil(inserted)
        XCTAssertEqual(inserted?.ownerUserId, "user-42")
        XCTAssertEqual(inserted?.characterId, "0-3")
        XCTAssertEqual(inserted?.level, 1)
        XCTAssertEqual(inserted?.bestScore, 60)
        XCTAssertEqual(result, .applied)
    }

    // MARK: - Unknown record type

    func test_applyRemoteRecord_unknownRecordType_isSkippedNotError() throws {
        let context = try makeContext()
        let store = FidelSyncStore(context: context)

        let id = SyncID(recordType: "SomeFutureType", id: "abc")
        let record = CKRecord(recordType: "SomeFutureType", recordID: id.recordID(in: zoneID))

        let result = try store.applyRemoteRecord(record)

        XCTAssertEqual(result, .applied)
    }

    // MARK: - allSyncIDs / resetAllSystemFields

    func test_allSyncIDs_includesAllInsertedModels() throws {
        let context = try makeContext()
        let store = FidelSyncStore(context: context)

        let progress = UserProgress(ownerUserId: "user-1")
        context.insert(progress)
        let card = FlashcardProgress(itemId: "w-1", itemType: "vocabulary", ownerUserId: "user-1")
        context.insert(card)
        let mastery = CharacterTraceMastery(characterId: "0-1", ownerUserId: "user-1")
        context.insert(mastery)
        try context.save()

        let ids = try store.allSyncIDs()

        XCTAssertTrue(ids.contains(progress.syncID))
        XCTAssertTrue(ids.contains(card.syncID))
        XCTAssertTrue(ids.contains(mastery.syncID))
    }

    func test_resetAllSystemFields_clearsCloudSystemFields() throws {
        let context = try makeContext()
        let store = FidelSyncStore(context: context)

        let progress = UserProgress(ownerUserId: "user-1")
        progress.cloudSystemFields = Data([0x01, 0x02])
        context.insert(progress)
        try context.save()

        try store.resetAllSystemFields()

        XCTAssertNil(progress.cloudSystemFields)
    }

    // MARK: - didSaveRecord updates system fields only

    func test_didSaveRecord_updatesSystemFieldsOnlyNotUserVisibleFields() throws {
        let context = try makeContext()
        let store = FidelSyncStore(context: context)

        let local = UserProgress(ownerUserId: "user-1")
        local.totalXP = 100
        context.insert(local)
        try context.save()

        let record = CKRecord(recordType: UserProgress.recordType, recordID: local.syncID.recordID(in: zoneID))
        // Simulate a save response carrying different user-visible values —
        // didSaveRecord must NOT apply them, only persist system fields.
        record["totalXP"] = 999
        XCTAssertNil(local.cloudSystemFields)

        store.didSaveRecord(record)

        XCTAssertEqual(local.totalXP, 100)
        XCTAssertNotNil(local.cloudSystemFields)
    }
}
