import Foundation
import SwiftData

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

struct UserProgressSnapshot: Codable {
    let totalXP: Int
    let currentStreak: Int
    let longestStreak: Int
    let lastPracticeDate: Date?
    let lessonsCompleted: [Int]
    let patternsLearned: [String]
    let vocabularyMastered: [String]
    let conversationsPracticed: [Int]
    let dailyGoal: Int
    let todayXP: Int
    let achievements: [String]
    let fidelCharactersRecognized: [String]
    let charactersTraced: [String]
    let currentStage: Int

    init(progress: UserProgress) {
        totalXP = progress.totalXP
        currentStreak = progress.currentStreak
        longestStreak = progress.longestStreak
        lastPracticeDate = progress.lastPracticeDate
        lessonsCompleted = progress.lessonsCompleted
        patternsLearned = progress.patternsLearned
        vocabularyMastered = progress.vocabularyMastered
        conversationsPracticed = progress.conversationsPracticed
        dailyGoal = progress.dailyGoal
        todayXP = progress.todayXP
        achievements = progress.achievements
        fidelCharactersRecognized = progress.fidelCharactersRecognized
        charactersTraced = progress.charactersTraced
        currentStage = progress.currentStage
    }
}

struct FlashcardProgressSnapshot: Codable {
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
    }
}

@MainActor
struct ProgressExportService {
    private let modelContext: ModelContext
    private let settingsStore: AppSettingsStore

    init(modelContext: ModelContext, settingsStore: AppSettingsStore = AppSettingsStore()) {
        self.modelContext = modelContext
        self.settingsStore = settingsStore
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

    func importData(_ data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(ProgressBackupSnapshot.self, from: data)
        guard snapshot.version == ProgressBackupSnapshot.currentVersion else {
            throw ProgressExportError.invalidBackupVersion(snapshot.version)
        }
        importUserProgress(snapshot.userProgress)
        importFlashcards(snapshot.flashcards)
        importSettings(snapshot.settings)
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

    private func importUserProgress(_ snapshot: UserProgressSnapshot?) {
        guard let snapshot else { return }
        let progress = fetchUserProgress() ?? UserProgress(ownerUserId: LocalLearner.userId)
        if progress.modelContext == nil {
            modelContext.insert(progress)
        }

        progress.ownerUserId = LocalLearner.userId
        progress.totalXP = max(progress.totalXP, snapshot.totalXP)
        progress.currentStreak = max(progress.currentStreak, snapshot.currentStreak)
        progress.longestStreak = max(progress.longestStreak, snapshot.longestStreak)
        progress.lastPracticeDate = maxDate(progress.lastPracticeDate, snapshot.lastPracticeDate)
        progress.lessonsCompleted = merged(progress.lessonsCompleted, snapshot.lessonsCompleted)
        progress.patternsLearned = merged(progress.patternsLearned, snapshot.patternsLearned)
        progress.vocabularyMastered = merged(progress.vocabularyMastered, snapshot.vocabularyMastered)
        progress.conversationsPracticed = merged(progress.conversationsPracticed, snapshot.conversationsPracticed)
        progress.dailyGoal = snapshot.dailyGoal
        progress.todayXP = max(progress.todayXP, snapshot.todayXP)
        progress.achievements = merged(progress.achievements, snapshot.achievements)
        progress.fidelCharactersRecognized = merged(progress.fidelCharactersRecognized, snapshot.fidelCharactersRecognized)
        progress.charactersTraced = merged(progress.charactersTraced, snapshot.charactersTraced)
        progress.currentStage = max(progress.currentStage, snapshot.currentStage)
        progress.updatedAt = Date.now
    }

    private func importFlashcards(_ snapshots: [FlashcardProgressSnapshot]) {
        let existing = fetchFlashcards()
        var existingByKey = Dictionary(uniqueKeysWithValues: existing.map { ("\($0.itemType)::\($0.itemId)", $0) })

        for snapshot in snapshots {
            let key = "\(snapshot.itemType)::\(snapshot.itemId)"
            let progress = existingByKey[key] ?? FlashcardProgress(
                itemId: snapshot.itemId,
                itemType: snapshot.itemType,
                ownerUserId: LocalLearner.userId
            )
            if existingByKey[key] == nil {
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
                progress.updatedAt = Date.now
            }
        }
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
    }

    private func maxDate(_ lhs: Date?, _ rhs: Date?) -> Date? {
        switch (lhs, rhs) {
        case let (l?, r?):
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
        Array(Set(lhs).union(rhs))
    }
}
