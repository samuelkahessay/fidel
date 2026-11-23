import Foundation
import SwiftData
import SyncKit

enum ProgressExportError: LocalizedError {
    case invalidBackupVersion(Int)

    var errorDescription: String? {
        switch self {
        case .invalidBackupVersion(let version):
            return "Unsupported Fidel backup version \(version)."
        }
    }
}

struct ProgressBackupSnapshot: Codable {
    static let currentVersion = 1

    let version: Int
    let exportedAt: Date
    let userProgress: UserProgressSnapshot?
    let flashcards: [FlashcardProgressSnapshot]
    let settings: AppSettingsSnapshot

    init(userProgress: UserProgress?, flashcards: [FlashcardProgress], settingsStore: AppSettingsStore) {
        self.version = Self.currentVersion
        self.exportedAt = Date.now
        self.userProgress = userProgress.map(UserProgressSnapshot.init)
        self.flashcards = flashcards.map(FlashcardProgressSnapshot.init)
        self.settings = AppSettingsSnapshot(settingsStore: settingsStore)
    }
}

struct UserProgressSnapshot: Codable, Equatable {
    let totalXP: Int
    let currentStreak: Int
    let longestStreak: Int
    let lastPracticeDate: Date?
    let lessonsCompleted: [Int]
    // Optional so old backups (pre-in-progress-tracking) decode without this
    // key — a missing key on a non-optional Codable property throws on decode.
    let lessonsInProgress: [Int]?
    let patternsLearned: [String]
    let vocabularyMastered: [String]
    let conversationsPracticed: [Int]
    let dailyGoal: Int
    let todayXP: Int
    let achievements: [String]
    let fidelCharactersRecognized: [String]
    let charactersTraced: [String]
    let currentStage: Int
    // Optional so old backups (pre-streak-slack) decode without these keys —
    // a missing key on a non-optional Codable property throws on decode.
    let streakFreezesAvailable: Int?
    let weeklyStreakCount: Int?
    let lastFreezeGrantWeek: Int?

    init(progress: UserProgress) {
        totalXP = progress.totalXP
        currentStreak = progress.currentStreak
        longestStreak = progress.longestStreak
        lastPracticeDate = progress.lastPracticeDate
        lessonsCompleted = progress.lessonsCompleted
        lessonsInProgress = progress.lessonsInProgress
        patternsLearned = progress.patternsLearned
        vocabularyMastered = progress.vocabularyMastered
        conversationsPracticed = progress.conversationsPracticed
        dailyGoal = progress.dailyGoal
        todayXP = progress.todayXP
        achievements = progress.achievements
        fidelCharactersRecognized = progress.fidelCharactersRecognized
        charactersTraced = progress.charactersTraced
        currentStage = progress.currentStage
        streakFreezesAvailable = progress.streakFreezesAvailable
        weeklyStreakCount = progress.weeklyStreakCount
        lastFreezeGrantWeek = progress.lastFreezeGrantWeek
    }
}

struct FlashcardProgressSnapshot: Codable, Equatable {
    let itemId: String
    let itemType: String
    let easeFactor: Double
    let interval: Int
    let repetitions: Int
    let nextReviewDate: Date
    let lastReviewDate: Date?
    let stability: Double
    let difficulty: Double
    let lapses: Int

    init(progress: FlashcardProgress) {
        itemId = progress.itemId
        itemType = progress.itemType
        easeFactor = progress.easeFactor
        interval = progress.interval
        repetitions = progress.repetitions
        nextReviewDate = progress.nextReviewDate
        lastReviewDate = progress.lastReviewDate
        stability = progress.stability
        difficulty = progress.difficulty
        lapses = progress.lapses
    }
}

struct AppSettingsSnapshot: Codable {
    let dailyXPGoal: Int
    let preferredResponseLanguage: String
    let showsTransliteration: Bool
    let autoPlaysPronunciation: Bool
    let hapticsEnabled: Bool
    let selectedReferenceTab: Int
    let showsAITools: Bool
    let onboardingComplete: Bool
    let lastOpenedActivity: String?
    // Optional so old backups (pre-pace-tier) decode without this key — stored
    // as a raw String (not `DailyGoalTier`) so an unrecognized/renamed case in
    // a future backup still decodes instead of throwing.
    let dailyGoalTier: String?

    init(settingsStore: AppSettingsStore) {
        dailyXPGoal = settingsStore.dailyXPGoal
        preferredResponseLanguage = settingsStore.preferredResponseLanguage
        showsTransliteration = settingsStore.showsTransliteration
        autoPlaysPronunciation = settingsStore.autoPlaysPronunciation
        hapticsEnabled = settingsStore.hapticsEnabled
        selectedReferenceTab = settingsStore.selectedReferenceTab
        showsAITools = settingsStore.showsAITools
        onboardingComplete = settingsStore.onboardingComplete
        lastOpenedActivity = settingsStore.lastOpenedActivity
        dailyGoalTier = settingsStore.dailyGoalTier.rawValue
    }
}

@MainActor
struct ProgressExportService {
    private let modelContext: ModelContext
    private let settingsStore: AppSettingsStore
    private let onMutation: @MainActor (SyncID) -> Void

    init(
        modelContext: ModelContext,
        settingsStore: AppSettingsStore = AppSettingsStore(),
        onMutation: @escaping @MainActor (SyncID) -> Void = { _ in }
    ) {
        self.modelContext = modelContext
        self.settingsStore = settingsStore
        self.onMutation = onMutation
    }

    func exportData() throws -> Data {
        let snapshot = ProgressBackupSnapshot(
            userProgress: fetchUserProgress(),
            flashcards: fetchFlashcards(),
            settingsStore: settingsStore
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(snapshot)
    }

    @discardableResult
    func importData(_ data: Data) throws -> [SyncID] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(ProgressBackupSnapshot.self, from: data)
        guard snapshot.version == ProgressBackupSnapshot.currentVersion else {
            throw ProgressExportError.invalidBackupVersion(snapshot.version)
        }
        var changedIDs: [SyncID] = []
        if let userProgressID = importUserProgress(snapshot.userProgress) {
            changedIDs.append(userProgressID)
        }
        changedIDs.append(contentsOf: importFlashcards(snapshot.flashcards))
        importSettings(snapshot.settings)
        changedIDs.forEach(onMutation)
        return changedIDs
    }

    private func fetchUserProgress() -> UserProgress? {
        let ownerId = LocalLearner.userId
        let descriptor = FetchDescriptor<UserProgress>(
            predicate: #Predicate<UserProgress> { $0.ownerUserId == ownerId },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func fetchFlashcards() -> [FlashcardProgress] {
        let ownerId = LocalLearner.userId
        let descriptor = FetchDescriptor<FlashcardProgress>(
            predicate: #Predicate<FlashcardProgress> { $0.ownerUserId == ownerId }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func importUserProgress(_ snapshot: UserProgressSnapshot?) -> SyncID? {
        guard let snapshot else { return nil }
        let progress = fetchUserProgress() ?? UserProgress(ownerUserId: LocalLearner.userId)
        let isNew = progress.modelContext == nil
        let before = UserProgressSnapshot(progress: progress)
        if isNew {
            modelContext.insert(progress)
        }

        progress.ownerUserId = LocalLearner.userId
        progress.totalXP = max(progress.totalXP, snapshot.totalXP)
        progress.currentStreak = max(progress.currentStreak, snapshot.currentStreak)
        progress.longestStreak = max(progress.longestStreak, snapshot.longestStreak)
        progress.lastPracticeDate = maxDate(progress.lastPracticeDate, snapshot.lastPracticeDate)
        progress.lessonsCompleted = merged(progress.lessonsCompleted, snapshot.lessonsCompleted)
        // A merged-in backup may list a lesson as in-progress that the local
        // device has since completed; never let a completed lesson linger here.
        let completedAfterMerge = Set(progress.lessonsCompleted)
        progress.lessonsInProgress = merged(progress.lessonsInProgress, snapshot.lessonsInProgress ?? [])
            .filter { !completedAfterMerge.contains($0) }
        progress.patternsLearned = merged(progress.patternsLearned, snapshot.patternsLearned)
        progress.vocabularyMastered = merged(progress.vocabularyMastered, snapshot.vocabularyMastered)
        progress.conversationsPracticed = merged(progress.conversationsPracticed, snapshot.conversationsPracticed)
        progress.dailyGoal = snapshot.dailyGoal
        progress.todayXP = max(progress.todayXP, snapshot.todayXP)
        progress.achievements = merged(progress.achievements, snapshot.achievements)
        progress.fidelCharactersRecognized = merged(progress.fidelCharactersRecognized, snapshot.fidelCharactersRecognized)
        progress.charactersTraced = merged(progress.charactersTraced, snapshot.charactersTraced)
        progress.currentStage = max(progress.currentStage, snapshot.currentStage)
        progress.streakFreezesAvailable = max(progress.streakFreezesAvailable, snapshot.streakFreezesAvailable ?? 0)
        progress.weeklyStreakCount = max(progress.weeklyStreakCount, snapshot.weeklyStreakCount ?? 0)
        progress.lastFreezeGrantWeek = max(progress.lastFreezeGrantWeek, snapshot.lastFreezeGrantWeek ?? 0)
        guard isNew || UserProgressSnapshot(progress: progress) != before else { return nil }
        let mutationDate = Date.now
        progress.updatedAt = mutationDate
        progress.syncModifiedAt = mutationDate
        return progress.syncID
    }

    private func importFlashcards(_ snapshots: [FlashcardProgressSnapshot]) -> [SyncID] {
        let existing = fetchFlashcards()
        var existingByKey = Dictionary(uniqueKeysWithValues: existing.map { ("\($0.itemType)::\($0.itemId)", $0) })
        var changedIDs: [SyncID] = []

        for snapshot in snapshots {
            let key = "\(snapshot.itemType)::\(snapshot.itemId)"
            let progress =
                existingByKey[key]
                ?? FlashcardProgress(
                    itemId: snapshot.itemId,
                    itemType: snapshot.itemType,
                    ownerUserId: LocalLearner.userId
                )
            let isNew = existingByKey[key] == nil
            let before = FlashcardProgressSnapshot(progress: progress)
            if isNew {
                modelContext.insert(progress)
                existingByKey[key] = progress
            }
            if snapshot.repetitions >= progress.repetitions {
                progress.easeFactor = snapshot.easeFactor
                progress.interval = snapshot.interval
                progress.repetitions = snapshot.repetitions
                progress.nextReviewDate = snapshot.nextReviewDate
                progress.lastReviewDate = snapshot.lastReviewDate
                progress.stability = snapshot.stability
                progress.difficulty = snapshot.difficulty
                progress.lapses = snapshot.lapses
                progress.ownerUserId = LocalLearner.userId
            }
            guard isNew || FlashcardProgressSnapshot(progress: progress) != before else { continue }
            let mutationDate = Date.now
            progress.updatedAt = mutationDate
            progress.syncModifiedAt = mutationDate
            changedIDs.append(progress.syncID)
        }
        return changedIDs
    }

    private func importSettings(_ snapshot: AppSettingsSnapshot) {
        settingsStore.dailyXPGoal = snapshot.dailyXPGoal
        settingsStore.preferredResponseLanguage = snapshot.preferredResponseLanguage
        settingsStore.showsTransliteration = snapshot.showsTransliteration
        settingsStore.autoPlaysPronunciation = snapshot.autoPlaysPronunciation
        settingsStore.hapticsEnabled = snapshot.hapticsEnabled
        settingsStore.selectedReferenceTab = snapshot.selectedReferenceTab
        settingsStore.showsAITools = snapshot.showsAITools
        settingsStore.onboardingComplete = snapshot.onboardingComplete
        settingsStore.lastOpenedActivity = snapshot.lastOpenedActivity
        settingsStore.dailyGoalTier =
            DailyGoalTier(rawValue: snapshot.dailyGoalTier ?? DailyGoalTier.default.rawValue) ?? DailyGoalTier.default
    }

    private func maxDate(_ lhs: Date?, _ rhs: Date?) -> Date? {
        switch (lhs, rhs) {
        case (let l?, let r?):
            return max(l, r)
        case (let l?, nil):
            return l
        case (nil, let r?):
            return r
        case (nil, nil):
            return nil
        }
    }

    private func merged<T: Hashable>(_ lhs: [T], _ rhs: [T]) -> [T] {
        var seen = Set(lhs)
        return lhs + rhs.filter { seen.insert($0).inserted }
    }
}
