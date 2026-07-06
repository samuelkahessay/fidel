import CloudKit
import Foundation
import os
import SwiftData
import SyncKit

/// `SyncStore` conformance bridging SwiftData's three synced Fidel models to
/// CloudKit. Shape mirrors `ThroughlineSyncStore` (throwing lookup, `Handle`
/// bundle, insert-on-first-fetch, didSaveRecord updates system fields only),
/// but `applyRemoteRecord` performs FIELD-WISE MERGES for `UserProgress` and
/// `CharacterTraceMastery` — mirroring the consolidation logic in
/// `ProgressRepository` — instead of plain last-write-wins. `FlashcardProgress`
/// uses plain whole-record LWW, same as the Throughline reference.
@MainActor
final class FidelSyncStore: SyncStore {
    private let context: ModelContext
    private let logger = Logger(subsystem: "dev.skahessay.learnamharic", category: "sync")

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - SyncStore

    func recordToSave(for id: SyncID, in zoneID: CKRecordZone.ID) throws -> CKRecord? {
        guard let found = try lookup(id) else { return nil }
        let record = CKRecordFactory.baseRecord(for: id, systemFields: found.systemFields, zoneID: zoneID)
        found.encode(record)
        return record
    }

    func applyRemoteRecord(_ record: CKRecord) throws -> RemoteApplyResult {
        guard let id = SyncID(recordName: record.recordID.recordName) else {
            logger.error("applyRemoteRecord: unparseable recordName \(record.recordID.recordName, privacy: .public) for recordType \(record.recordType, privacy: .public)")
            return .applied
        }

        if let found = try lookup(id) {
            let result = try mergeAndApply(found, record: record, id: id)
            try context.save()
            return result
        } else if try insertNew(from: record, id: id) {
            try context.save()
            return .applied
        } else {
            logger.error("applyRemoteRecord: unknown record type \(id.recordType, privacy: .public) for recordName \(record.recordID.recordName, privacy: .public)")
            return .applied
        }
    }

    func applyRemoteDeletion(of id: SyncID) throws {
        guard let found = try lookup(id) else { return }
        found.delete(context)
        try context.save()
    }

    func didSaveRecord(_ record: CKRecord) {
        do {
            guard let id = SyncID(recordName: record.recordID.recordName),
                  let found = try lookup(id) else { return }
            found.setSystemFields(CKRecordFactory.systemFieldsData(from: record))
            try? context.save()
        } catch {
            logger.error("didSaveRecord lookup failed for \(record.recordID.recordName, privacy: .public): \(String(describing: error), privacy: .public)")
        }
    }

    func allSyncIDs() -> [SyncID] {
        var ids: [SyncID] = []
        ids += (try? context.fetch(FetchDescriptor<UserProgress>()))?.map(\.syncID) ?? []
        ids += (try? context.fetch(FetchDescriptor<FlashcardProgress>()))?.map(\.syncID) ?? []
        ids += (try? context.fetch(FetchDescriptor<CharacterTraceMastery>()))?.map(\.syncID) ?? []
        return ids
    }

    func resetAllSystemFields() {
        (try? context.fetch(FetchDescriptor<UserProgress>()))?.forEach { $0.cloudSystemFields = nil }
        (try? context.fetch(FetchDescriptor<FlashcardProgress>()))?.forEach { $0.cloudSystemFields = nil }
        (try? context.fetch(FetchDescriptor<CharacterTraceMastery>()))?.forEach { $0.cloudSystemFields = nil }
        try? context.save()
    }

    // MARK: - Merge dispatch

    /// Applies a remote record onto an existing local twin, using field-wise
    /// merge for `UserProgress`/`CharacterTraceMastery` and plain LWW for
    /// `FlashcardProgress`.
    private func mergeAndApply(_ found: Handle, record: CKRecord, id: SyncID) throws -> RemoteApplyResult {
        switch id.recordType {
        case UserProgress.recordType:
            guard let model = found.userProgress else { return .applied }
            return mergeUserProgress(model, remoteRecord: record)
        case CharacterTraceMastery.recordType:
            guard let model = found.characterTraceMastery else { return .applied }
            return mergeTraceMastery(model, remoteRecord: record)
        case FlashcardProgress.recordType:
            guard let model = found.flashcardProgress else { return .applied }
            return applyFlashcardLWW(model, remoteRecord: record)
        default:
            return .applied
        }
    }

    // MARK: - UserProgress field-wise merge

    /// Mirrors `ProgressRepository.consolidateUserProgress`:
    /// - array fields: union preserving local order, then appending new-from-remote elements.
    /// - counters (totalXP, longestStreak, currentStage): max(local, remote).
    /// - currentStreak / lastPracticeDate / todayXP / dailyGoal: taken from whichever side
    ///   has the newer `syncModifiedAt` (whole-value, not maxed).
    /// - streakFreezesAvailable / weeklyStreakCount / lastFreezeGrantWeek: not touched by
    ///   `consolidateUserProgress` in ProgressRepository, so treated the same as the other
    ///   counters here (max) — see final report for this extrapolation.
    /// - updatedAt / syncModifiedAt: max of the two.
    private func mergeUserProgress(_ local: UserProgress, remoteRecord: CKRecord) -> RemoteApplyResult {
        let remoteModifiedAt = remoteRecord[SyncKeys.modifiedAt] as? Date ?? .distantPast
        let localModifiedAt = local.syncModifiedAt
        let remoteIsNewer = remoteModifiedAt > localModifiedAt

        let remoteLessonsCompleted = remoteRecord["lessonsCompleted"] as? [Int] ?? []
        let remoteLessonsInProgress = remoteRecord["lessonsInProgress"] as? [Int] ?? []
        let remotePatternsLearned = remoteRecord["patternsLearned"] as? [String] ?? []
        let remoteVocabularyMastered = remoteRecord["vocabularyMastered"] as? [String] ?? []
        let remoteConversationsPracticed = remoteRecord["conversationsPracticed"] as? [Int] ?? []
        let remoteAchievements = remoteRecord["achievements"] as? [String] ?? []
        let remoteFidelCharactersRecognized = remoteRecord["fidelCharactersRecognized"] as? [String] ?? []
        let remoteCharactersTraced = remoteRecord["charactersTraced"] as? [String] ?? []

        let remoteTotalXP = remoteRecord["totalXP"] as? Int ?? 0
        let remoteLongestStreak = remoteRecord["longestStreak"] as? Int ?? 0
        let remoteCurrentStage = remoteRecord["currentStage"] as? Int ?? 0
        let remoteStreakFreezesAvailable = remoteRecord["streakFreezesAvailable"] as? Int ?? 0
        let remoteWeeklyStreakCount = remoteRecord["weeklyStreakCount"] as? Int ?? 0
        let remoteLastFreezeGrantWeek = remoteRecord["lastFreezeGrantWeek"] as? Int ?? 0

        let remoteCurrentStreak = remoteRecord["currentStreak"] as? Int ?? 0
        let remoteLastPracticeDate = remoteRecord["lastPracticeDate"] as? Date
        let remoteTodayXP = remoteRecord["todayXP"] as? Int ?? 0
        let remoteDailyGoal = remoteRecord["dailyGoal"] as? Int ?? 0
        let remoteUpdatedAt = remoteRecord["updatedAt"] as? Date ?? .distantPast

        local.lessonsCompleted = Self.mergedUnion(local.lessonsCompleted, remoteLessonsCompleted)
        local.lessonsInProgress = Self.mergedUnion(local.lessonsInProgress, remoteLessonsInProgress)
        local.patternsLearned = Self.mergedUnion(local.patternsLearned, remotePatternsLearned)
        local.vocabularyMastered = Self.mergedUnion(local.vocabularyMastered, remoteVocabularyMastered)
        local.conversationsPracticed = Self.mergedUnion(local.conversationsPracticed, remoteConversationsPracticed)
        local.achievements = Self.mergedUnion(local.achievements, remoteAchievements)
        local.fidelCharactersRecognized = Self.mergedUnion(local.fidelCharactersRecognized, remoteFidelCharactersRecognized)
        local.charactersTraced = Self.mergedUnion(local.charactersTraced, remoteCharactersTraced)

        local.totalXP = max(local.totalXP, remoteTotalXP)
        local.longestStreak = max(local.longestStreak, remoteLongestStreak)
        local.currentStage = max(local.currentStage, remoteCurrentStage)
        local.streakFreezesAvailable = max(local.streakFreezesAvailable, remoteStreakFreezesAvailable)
        local.weeklyStreakCount = max(local.weeklyStreakCount, remoteWeeklyStreakCount)
        local.lastFreezeGrantWeek = max(local.lastFreezeGrantWeek, remoteLastFreezeGrantWeek)

        if remoteIsNewer {
            local.currentStreak = remoteCurrentStreak
            local.lastPracticeDate = remoteLastPracticeDate
            local.todayXP = remoteTodayXP
            local.dailyGoal = remoteDailyGoal
        }

        local.updatedAt = max(local.updatedAt, remoteUpdatedAt)
        local.syncModifiedAt = max(local.syncModifiedAt, remoteModifiedAt)

        let mergedMatchesRemote =
            local.lessonsCompleted == remoteLessonsCompleted &&
            local.lessonsInProgress == remoteLessonsInProgress &&
            local.patternsLearned == remotePatternsLearned &&
            local.vocabularyMastered == remoteVocabularyMastered &&
            local.conversationsPracticed == remoteConversationsPracticed &&
            local.achievements == remoteAchievements &&
            local.fidelCharactersRecognized == remoteFidelCharactersRecognized &&
            local.charactersTraced == remoteCharactersTraced &&
            local.totalXP == remoteTotalXP &&
            local.longestStreak == remoteLongestStreak &&
            local.dailyGoal == remoteDailyGoal &&
            local.todayXP == remoteTodayXP &&
            local.currentStage == remoteCurrentStage &&
            local.streakFreezesAvailable == remoteStreakFreezesAvailable &&
            local.weeklyStreakCount == remoteWeeklyStreakCount &&
            local.lastFreezeGrantWeek == remoteLastFreezeGrantWeek &&
            local.currentStreak == remoteCurrentStreak &&
            local.lastPracticeDate == remoteLastPracticeDate

        return mergedMatchesRemote ? .applied : .localNewer
    }

    // MARK: - CharacterTraceMastery field-wise merge

    /// Mirrors `ProgressRepository.consolidateTraceMastery` (verified at
    /// ProgressRepository.swift:305-332): level/bestScore/attempts/totalMisses
    /// all use max(local, remote) — attempts and totalMisses are NOT summed,
    /// which avoids double-counting on repeated merges. lastPracticedAt takes
    /// the later of the two.
    private func mergeTraceMastery(_ local: CharacterTraceMastery, remoteRecord: CKRecord) -> RemoteApplyResult {
        let remoteLevel = remoteRecord["level"] as? Int ?? 0
        let remoteBestScore = remoteRecord["bestScore"] as? Int ?? 0
        let remoteAttempts = remoteRecord["attempts"] as? Int ?? 0
        let remoteTotalMisses = remoteRecord["totalMisses"] as? Int ?? 0
        let remoteLastPracticedAt = remoteRecord["lastPracticedAt"] as? Date
        let remoteModifiedAt = remoteRecord[SyncKeys.modifiedAt] as? Date ?? .distantPast

        local.level = max(local.level, remoteLevel)
        local.bestScore = max(local.bestScore, remoteBestScore)
        local.attempts = max(local.attempts, remoteAttempts)
        local.totalMisses = max(local.totalMisses, remoteTotalMisses)
        local.lastPracticedAt = Self.maxDate(local.lastPracticedAt, remoteLastPracticedAt)
        local.syncModifiedAt = max(local.syncModifiedAt, remoteModifiedAt)

        let mergedMatchesRemote =
            local.level == remoteLevel &&
            local.bestScore == remoteBestScore &&
            local.attempts == remoteAttempts &&
            local.totalMisses == remoteTotalMisses &&
            local.lastPracticedAt == remoteLastPracticedAt

        return mergedMatchesRemote ? .applied : .localNewer
    }

    // MARK: - FlashcardProgress plain LWW

    private func applyFlashcardLWW(_ local: FlashcardProgress, remoteRecord: CKRecord) -> RemoteApplyResult {
        let remoteModifiedAt = remoteRecord[SyncKeys.modifiedAt] as? Date ?? .distantFuture
        if ConflictResolution.winner(localModifiedAt: local.syncModifiedAt, serverModifiedAt: remoteModifiedAt) == .local {
            return .localNewer
        }
        local.apply(record: remoteRecord)
        return .applied
    }

    // MARK: - Merge helpers

    /// Union preserving local order, then appending any new-from-remote
    /// elements not already present.
    private static func mergedUnion<T: Equatable>(_ local: [T], _ remote: [T]) -> [T] {
        var result = local
        for element in remote where !result.contains(element) {
            result.append(element)
        }
        return result
    }

    private static func maxDate(_ lhs: Date?, _ rhs: Date?) -> Date? {
        switch (lhs, rhs) {
        case let (l?, r?): return max(l, r)
        case (let l?, nil): return l
        case (nil, let r?): return r
        case (nil, nil): return nil
        }
    }

    // MARK: - Type-erased model handle

    /// Small closure bundle so the switch over record types lives in one
    /// place. Unlike Throughline's `Handle`, this also exposes the typed
    /// model instances (`userProgress`/`flashcardProgress`/`characterTraceMastery`)
    /// so `mergeAndApply` can run field-wise merges instead of a uniform
    /// whole-record `apply`.
    private struct Handle {
        let modifiedAt: Date
        let systemFields: Data?
        let encode: (CKRecord) -> Void
        let apply: (CKRecord) -> Void
        let setSystemFields: (Data) -> Void
        let delete: (ModelContext) -> Void
        let userProgress: UserProgress?
        let flashcardProgress: FlashcardProgress?
        let characterTraceMastery: CharacterTraceMastery?
    }

    /// Fetch errors propagate (throw) instead of being swallowed into `nil`:
    /// nil means "genuinely not found" (safe to treat as an unknown ID and
    /// insert), whereas a thrown fetch error must not be conflated with that
    /// case, or a transient failure would look like a new remote record and
    /// insert a duplicate.
    private func lookup(_ id: SyncID) throws -> Handle? {
        switch id.recordType {
        case UserProgress.recordType:
            let key = id.id
            var d = FetchDescriptor<UserProgress>(predicate: #Predicate { $0.ownerUserId == key })
            d.fetchLimit = 1
            guard let m = try context.fetch(d).first else { return nil }
            return handle(m)
        case FlashcardProgress.recordType:
            guard let (ownerUserId, itemType, itemId) = Self.parseFlashcardNaturalKey(id.id) else {
                logger.error("lookup: malformed FlashcardProgress natural key \(id.id, privacy: .public)")
                return nil
            }
            var d = FetchDescriptor<FlashcardProgress>(predicate: #Predicate {
                $0.ownerUserId == ownerUserId && $0.itemType == itemType && $0.itemId == itemId
            })
            d.fetchLimit = 1
            guard let m = try context.fetch(d).first else { return nil }
            return handle(m)
        case CharacterTraceMastery.recordType:
            let (ownerUserId, characterId) = Self.parseTraceMasteryNaturalKey(id.id)
            var d = FetchDescriptor<CharacterTraceMastery>(predicate: #Predicate {
                $0.ownerUserId == ownerUserId && $0.characterId == characterId
            })
            d.fetchLimit = 1
            guard let m = try context.fetch(d).first else { return nil }
            return handle(m)
        default:
            return nil
        }
    }

    private func handle(_ m: UserProgress) -> Handle {
        Handle(modifiedAt: m.syncModifiedAt, systemFields: m.cloudSystemFields,
               encode: m.encode(onto:), apply: m.apply(record:),
               setSystemFields: { m.cloudSystemFields = $0 },
               delete: { $0.delete(m) },
               userProgress: m, flashcardProgress: nil, characterTraceMastery: nil)
    }
    private func handle(_ m: FlashcardProgress) -> Handle {
        Handle(modifiedAt: m.syncModifiedAt, systemFields: m.cloudSystemFields,
               encode: m.encode(onto:), apply: m.apply(record:),
               setSystemFields: { m.cloudSystemFields = $0 },
               delete: { $0.delete(m) },
               userProgress: nil, flashcardProgress: m, characterTraceMastery: nil)
    }
    private func handle(_ m: CharacterTraceMastery) -> Handle {
        Handle(modifiedAt: m.syncModifiedAt, systemFields: m.cloudSystemFields,
               encode: m.encode(onto:), apply: m.apply(record:),
               setSystemFields: { m.cloudSystemFields = $0 },
               delete: { $0.delete(m) },
               userProgress: nil, flashcardProgress: nil, characterTraceMastery: m)
    }

    // MARK: - Insert-on-first-fetch

    /// Returns false for an unrecognized record type so the caller can log it
    /// (additive-only schema policy: unknown types only come from newer
    /// clients; they're skipped here and reappear on any full refetch).
    @discardableResult
    private func insertNew(from record: CKRecord, id: SyncID) throws -> Bool {
        switch id.recordType {
        case UserProgress.recordType:
            let m = UserProgress(ownerUserId: id.id)
            m.apply(record: record)
            context.insert(m)
        case FlashcardProgress.recordType:
            guard let (ownerUserId, itemType, itemId) = Self.parseFlashcardNaturalKey(id.id) else {
                logger.error("insertNew: malformed FlashcardProgress natural key \(id.id, privacy: .public)")
                return false
            }
            let m = FlashcardProgress(itemId: itemId, itemType: itemType, ownerUserId: ownerUserId)
            m.apply(record: record)
            context.insert(m)
        case CharacterTraceMastery.recordType:
            let (ownerUserId, characterId) = Self.parseTraceMasteryNaturalKey(id.id)
            let m = CharacterTraceMastery(characterId: characterId, ownerUserId: ownerUserId)
            m.apply(record: record)
            context.insert(m)
        default:
            return false
        }
        return true
    }

    // MARK: - Natural-key parsing

    /// Splits "<ownerUserId>:<itemType>:<itemId>" on the FIRST TWO colons
    /// only. `itemId` may itself contain colons (e.g. compound vocabulary
    /// word ids), so everything after the second colon is treated as the
    /// (possibly colon-containing) itemId verbatim. Returns nil if either
    /// colon is missing (malformed key — caller logs and skips).
    static func parseFlashcardNaturalKey(_ raw: String) -> (ownerUserId: String, itemType: String, itemId: String)? {
        guard let firstColon = raw.firstIndex(of: ":") else { return nil }
        let afterFirst = raw.index(after: firstColon)
        guard let secondColon = raw[afterFirst...].firstIndex(of: ":") else { return nil }
        let ownerUserId = String(raw[..<firstColon])
        let itemType = String(raw[afterFirst..<secondColon])
        let itemId = String(raw[raw.index(after: secondColon)...])
        return (ownerUserId, itemType, itemId)
    }

    /// Splits "<ownerUserId>:<characterId>" on the FIRST colon only.
    /// `characterId` may itself contain colons in principle, so the
    /// remainder after the first colon is the characterId verbatim. If no
    /// colon is present, the whole string is treated as characterId with an
    /// empty ownerUserId (defensive fallback; in practice SyncKit always
    /// produces well-formed ids from `CharacterTraceMastery.syncID`).
    static func parseTraceMasteryNaturalKey(_ raw: String) -> (ownerUserId: String, characterId: String) {
        guard let firstColon = raw.firstIndex(of: ":") else { return ("", raw) }
        let ownerUserId = String(raw[..<firstColon])
        let characterId = String(raw[raw.index(after: firstColon)...])
        return (ownerUserId, characterId)
    }
}
