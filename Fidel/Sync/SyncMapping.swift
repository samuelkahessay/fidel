import CloudKit
import Foundation
import SyncKit

// MARK: - UserProgress

extension UserProgress {
    static let recordType = "UserProgress"

    /// Natural key: the owner user id IS the id (one UserProgress row per user).
    var syncID: SyncID {
        SyncID(recordType: Self.recordType, id: ownerUserId)
    }

    func encode(onto record: CKRecord) {
        record["ownerUserId"] = ownerUserId
        record["totalXP"] = totalXP
        record["currentStreak"] = currentStreak
        record["longestStreak"] = longestStreak
        record["lastPracticeDate"] = lastPracticeDate
        if !lessonsCompleted.isEmpty || cloudSystemFields != nil { record["lessonsCompleted"] = lessonsCompleted }
        if !lessonsInProgress.isEmpty || cloudSystemFields != nil { record["lessonsInProgress"] = lessonsInProgress }
        if !patternsLearned.isEmpty || cloudSystemFields != nil { record["patternsLearned"] = patternsLearned }
        if !vocabularyMastered.isEmpty || cloudSystemFields != nil { record["vocabularyMastered"] = vocabularyMastered }
        if !conversationsPracticed.isEmpty || cloudSystemFields != nil { record["conversationsPracticed"] = conversationsPracticed }
        record["dailyGoal"] = dailyGoal
        record["todayXP"] = todayXP
        if !achievements.isEmpty || cloudSystemFields != nil { record["achievements"] = achievements }
        if !fidelCharactersRecognized.isEmpty || cloudSystemFields != nil { record["fidelCharactersRecognized"] = fidelCharactersRecognized }
        if !charactersTraced.isEmpty || cloudSystemFields != nil { record["charactersTraced"] = charactersTraced }
        record["currentStage"] = currentStage
        record["streakFreezesAvailable"] = streakFreezesAvailable
        record["weeklyStreakCount"] = weeklyStreakCount
        record["lastFreezeGrantWeek"] = lastFreezeGrantWeek
        record["updatedAt"] = updatedAt
        record[SyncKeys.modifiedAt] = syncModifiedAt
        record[SyncKeys.schemaVersion] = 1
    }

    /// Whole-record overwrite: used for insert-on-first-fetch. Field-wise merge
    /// (mirroring `ProgressRepository.consolidateUserProgress`) lives in
    /// `FidelSyncStore.applyRemoteRecord`, not here.
    func apply(record: CKRecord) {
        if let ownerUserId = record["ownerUserId"] as? String { self.ownerUserId = ownerUserId }
        if let totalXP = record["totalXP"] as? Int { self.totalXP = totalXP }
        if let currentStreak = record["currentStreak"] as? Int { self.currentStreak = currentStreak }
        if let longestStreak = record["longestStreak"] as? Int { self.longestStreak = longestStreak }
        self.lastPracticeDate = record["lastPracticeDate"] as? Date
        if let lessonsCompleted = record["lessonsCompleted"] as? [Int] { self.lessonsCompleted = lessonsCompleted }
        if let lessonsInProgress = record["lessonsInProgress"] as? [Int] { self.lessonsInProgress = lessonsInProgress }
        if let patternsLearned = record["patternsLearned"] as? [String] { self.patternsLearned = patternsLearned }
        if let vocabularyMastered = record["vocabularyMastered"] as? [String] { self.vocabularyMastered = vocabularyMastered }
        if let conversationsPracticed = record["conversationsPracticed"] as? [Int] { self.conversationsPracticed = conversationsPracticed }
        if let dailyGoal = record["dailyGoal"] as? Int { self.dailyGoal = dailyGoal }
        if let todayXP = record["todayXP"] as? Int { self.todayXP = todayXP }
        if let achievements = record["achievements"] as? [String] { self.achievements = achievements }
        if let fidelCharactersRecognized = record["fidelCharactersRecognized"] as? [String] { self.fidelCharactersRecognized = fidelCharactersRecognized }
        if let charactersTraced = record["charactersTraced"] as? [String] { self.charactersTraced = charactersTraced }
        if let currentStage = record["currentStage"] as? Int { self.currentStage = currentStage }
        if let streakFreezesAvailable = record["streakFreezesAvailable"] as? Int { self.streakFreezesAvailable = streakFreezesAvailable }
        if let weeklyStreakCount = record["weeklyStreakCount"] as? Int { self.weeklyStreakCount = weeklyStreakCount }
        if let lastFreezeGrantWeek = record["lastFreezeGrantWeek"] as? Int { self.lastFreezeGrantWeek = lastFreezeGrantWeek }
        if let updatedAt = record["updatedAt"] as? Date { self.updatedAt = updatedAt }
        if let modifiedAt = record[SyncKeys.modifiedAt] as? Date { self.syncModifiedAt = modifiedAt }
    }
}

// MARK: - FlashcardProgress

extension FlashcardProgress {
    static let recordType = "FlashcardProgress"

    /// Natural key: "<ownerUserId>:<itemType>:<itemId>". `itemId` may itself
    /// contain colons (compound vocabulary ids); parsing back out of the raw
    /// id string must split on the first two colons only — see
    /// `FidelSyncStore.parseFlashcardNaturalKey`.
    var syncID: SyncID {
        SyncID(recordType: Self.recordType, id: "\(ownerUserId):\(itemType):\(itemId)")
    }

    func encode(onto record: CKRecord) {
        record["ownerUserId"] = ownerUserId
        record["itemId"] = itemId
        record["itemType"] = itemType
        record["easeFactor"] = easeFactor
        record["interval"] = interval
        record["repetitions"] = repetitions
        record["nextReviewDate"] = nextReviewDate
        record["lastReviewDate"] = lastReviewDate
        record["stability"] = stability
        record["difficulty"] = difficulty
        record["lapses"] = lapses
        record["updatedAt"] = updatedAt
        record[SyncKeys.modifiedAt] = syncModifiedAt
        record[SyncKeys.schemaVersion] = 1
    }

    /// Whole-record overwrite — FlashcardProgress uses plain last-write-wins,
    /// so this is the only apply path `FidelSyncStore` needs for this type.
    func apply(record: CKRecord) {
        if let ownerUserId = record["ownerUserId"] as? String { self.ownerUserId = ownerUserId }
        if let itemId = record["itemId"] as? String { self.itemId = itemId }
        if let itemType = record["itemType"] as? String { self.itemType = itemType }
        if let easeFactor = record["easeFactor"] as? Double { self.easeFactor = easeFactor }
        if let interval = record["interval"] as? Int { self.interval = interval }
        if let repetitions = record["repetitions"] as? Int { self.repetitions = repetitions }
        if let nextReviewDate = record["nextReviewDate"] as? Date { self.nextReviewDate = nextReviewDate }
        self.lastReviewDate = record["lastReviewDate"] as? Date
        if let stability = record["stability"] as? Double { self.stability = stability }
        if let difficulty = record["difficulty"] as? Double { self.difficulty = difficulty }
        if let lapses = record["lapses"] as? Int { self.lapses = lapses }
        if let updatedAt = record["updatedAt"] as? Date { self.updatedAt = updatedAt }
        if let modifiedAt = record[SyncKeys.modifiedAt] as? Date { self.syncModifiedAt = modifiedAt }
    }
}

// MARK: - CharacterTraceMastery

extension CharacterTraceMastery {
    static let recordType = "CharacterTraceMastery"

    /// Natural key: "<ownerUserId>:<characterId>".
    var syncID: SyncID {
        SyncID(recordType: Self.recordType, id: "\(ownerUserId):\(characterId)")
    }

    func encode(onto record: CKRecord) {
        record["ownerUserId"] = ownerUserId
        record["characterId"] = characterId
        record["level"] = level
        record["bestScore"] = bestScore
        record["attempts"] = attempts
        record["totalMisses"] = totalMisses
        record["lastPracticedAt"] = lastPracticedAt
        record["updatedAt"] = updatedAt
        record[SyncKeys.modifiedAt] = syncModifiedAt
        record[SyncKeys.schemaVersion] = 1
    }

    /// Whole-record overwrite: used for insert-on-first-fetch. Field-wise merge
    /// (mirroring `ProgressRepository.consolidateTraceMastery`) lives in
    /// `FidelSyncStore.applyRemoteRecord`, not here.
    func apply(record: CKRecord) {
        if let ownerUserId = record["ownerUserId"] as? String { self.ownerUserId = ownerUserId }
        if let characterId = record["characterId"] as? String { self.characterId = characterId }
        if let level = record["level"] as? Int { self.level = level }
        if let bestScore = record["bestScore"] as? Int { self.bestScore = bestScore }
        if let attempts = record["attempts"] as? Int { self.attempts = attempts }
        if let totalMisses = record["totalMisses"] as? Int { self.totalMisses = totalMisses }
        self.lastPracticedAt = record["lastPracticedAt"] as? Date
        if let updatedAt = record["updatedAt"] as? Date { self.updatedAt = updatedAt }
        if let modifiedAt = record[SyncKeys.modifiedAt] as? Date { self.syncModifiedAt = modifiedAt }
    }
}
