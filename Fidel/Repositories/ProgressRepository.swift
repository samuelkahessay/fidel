import Foundation
import SwiftData

// MARK: - ProgressRepository Protocol

protocol ProgressRepositoryProtocol {
    // User Progress
    @discardableResult
    func ensureUserProgress() -> UserProgress
    func getUserProgress() -> UserProgress?
    func addXP(_ amount: Int)
    func completeLesson(_ lessonId: Int)
    func learnPattern(_ patternId: String)
    func masterVocabulary(_ wordId: String)
    func practiceConversation(_ conversationId: Int)
    
    // Flashcard Progress
    func getOrCreateFlashcardProgress(for itemId: String, type: String) -> FlashcardProgress
    func recordFlashcardReview(for itemId: String, type: String, rating: ReviewRating)
    func getDueFlashcards(type: String?) -> [FlashcardProgress]
    func getUpcomingFlashcards(days: Int) -> [FlashcardProgress]
    func initializeFlashcards(vocabulary: [VocabularyWord], phrases: [Phrase])
    
    // Fidel & Stages
    func recognizeFidelCharacter(_ charId: String)
    func traceCharacter(_ charId: String)
    func getFidelCharactersRecognizedCount() -> Int
    func getCurrentStage() -> Int
    func setCurrentStage(_ stage: Int)

    // Statistics
    func getLessonsCompletedCount() -> Int
    func getVocabularyMasteredCount() -> Int
    func getCurrentStreak() -> Int
    func getTotalXP() -> Int
    func getTodayXP() -> Int
    func getDailyGoal() -> Int
    func getAchievements() -> [String]
    func getConversationsPracticedCount() -> Int
}

// MARK: - ProgressRepository Implementation

@Observable
final class ProgressRepository: ProgressRepositoryProtocol {
    
    private let modelContext: ModelContext
    private let explicitUserId: String?
    private var activeUserId: String {
        explicitUserId ?? AuthManager.shared.currentUserId ?? AuthManager.previewUserId
    }
    
    init(modelContext: ModelContext, userId: String? = nil) {
        self.modelContext = modelContext
        self.explicitUserId = userId
    }
    
    // MARK: - User Progress

    @discardableResult
    func ensureUserProgress() -> UserProgress {
        getOrCreateUserProgress()
    }
    
    func getUserProgress() -> UserProgress? {
        let ownerId = activeUserId
        let descriptor = FetchDescriptor<UserProgress>(
            predicate: #Predicate<UserProgress> { $0.ownerUserId == ownerId },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        guard let records = try? modelContext.fetch(descriptor), !records.isEmpty else {
            return nil
        }
        return consolidateUserProgress(records, ownerId: ownerId)
    }
    
    private func getOrCreateUserProgress() -> UserProgress {
        let ownerId = activeUserId
        if let existing = getUserProgress() {
            return existing
        }

        // Claim legacy local progress created before per-user ownership existed.
        let legacyDescriptor = FetchDescriptor<UserProgress>(
            predicate: #Predicate<UserProgress> { $0.ownerUserId == "" }
        )
        if let legacyRecords = try? modelContext.fetch(legacyDescriptor), !legacyRecords.isEmpty {
            let legacyProgress = consolidateUserProgress(legacyRecords, ownerId: ownerId)
            legacyProgress.ownerUserId = ownerId
            legacyProgress.updatedAt = Date()
            return legacyProgress
        }

        let newProgress = UserProgress(ownerUserId: ownerId)
        modelContext.insert(newProgress)
        return newProgress
    }
    
    func addXP(_ amount: Int) {
        let progress = getOrCreateUserProgress()
        progress.addXP(amount)
    }
    
    func completeLesson(_ lessonId: Int) {
        let progress = getOrCreateUserProgress()
        progress.completeLesson(lessonId)
    }
    
    func learnPattern(_ patternId: String) {
        let progress = getOrCreateUserProgress()
        progress.learnPattern(patternId)
    }
    
    func masterVocabulary(_ wordId: String) {
        let progress = getOrCreateUserProgress()
        progress.masterVocabulary(wordId)
    }
    
    func practiceConversation(_ conversationId: Int) {
        let progress = getOrCreateUserProgress()
        progress.practiceConversation(conversationId)
    }
    
    // MARK: - Flashcard Progress
    
    func getOrCreateFlashcardProgress(for itemId: String, type: String) -> FlashcardProgress {
        let ownerId = activeUserId
        let descriptor = FetchDescriptor<FlashcardProgress>(
            predicate: #Predicate<FlashcardProgress> {
                $0.ownerUserId == ownerId && $0.itemId == itemId && $0.itemType == type
            }
        )
        
        if let existingRecords = try? modelContext.fetch(descriptor), !existingRecords.isEmpty {
            return consolidateFlashcardProgress(existingRecords, ownerId: ownerId)
        }
        
        let newProgress = FlashcardProgress(itemId: itemId, itemType: type, ownerUserId: ownerId)
        modelContext.insert(newProgress)
        return newProgress
    }
    
    func recordFlashcardReview(for itemId: String, type: String, rating: ReviewRating) {
        let progress = getOrCreateFlashcardProgress(for: itemId, type: type)
        FSRSAlgorithm.updateFlashcardProgress(progress: progress, rating: rating)
    }
    
    func getDueFlashcards(type: String?) -> [FlashcardProgress] {
        let ownerId = activeUserId
        let descriptor: FetchDescriptor<FlashcardProgress>
        
        if let type = type {
            descriptor = FetchDescriptor<FlashcardProgress>(
                predicate: #Predicate<FlashcardProgress> {
                    $0.ownerUserId == ownerId && $0.itemType == type
                }
            )
        } else {
            descriptor = FetchDescriptor<FlashcardProgress>(
                predicate: #Predicate<FlashcardProgress> { $0.ownerUserId == ownerId }
            )
        }
        
        guard let allProgress = try? modelContext.fetch(descriptor) else {
            return []
        }
        
        let deduplicated = deduplicatedFlashcards(from: allProgress, ownerId: ownerId)
        return FSRSAlgorithm.getDueCards(from: deduplicated)
    }
    
    func getUpcomingFlashcards(days: Int) -> [FlashcardProgress] {
        let ownerId = activeUserId
        let descriptor = FetchDescriptor<FlashcardProgress>(
            predicate: #Predicate<FlashcardProgress> { $0.ownerUserId == ownerId }
        )
        guard let allProgress = try? modelContext.fetch(descriptor) else {
            return []
        }
        let deduplicated = deduplicatedFlashcards(from: allProgress, ownerId: ownerId)
        return FSRSAlgorithm.getUpcomingCards(from: deduplicated, days: days)
    }
    
    func initializeFlashcards(vocabulary: [VocabularyWord], phrases: [Phrase]) {
        for word in vocabulary {
            _ = getOrCreateFlashcardProgress(for: word.id, type: "vocabulary")
        }
        for phrase in phrases {
            _ = getOrCreateFlashcardProgress(for: String(phrase.id), type: "phrase")
        }
    }
    
    // MARK: - Fidel & Stages

    func recognizeFidelCharacter(_ charId: String) {
        let progress = getOrCreateUserProgress()
        progress.recognizeFidelCharacter(charId)
    }

    func traceCharacter(_ charId: String) {
        let progress = getOrCreateUserProgress()
        progress.traceCharacter(charId)
    }

    func getFidelCharactersRecognizedCount() -> Int {
        getUserProgress()?.fidelCharactersRecognized.count ?? 0
    }

    func getCurrentStage() -> Int {
        getUserProgress()?.currentStage ?? 0
    }

    func setCurrentStage(_ stage: Int) {
        let progress = getOrCreateUserProgress()
        progress.currentStage = stage
        progress.updatedAt = Date()
    }

    // MARK: - Statistics

    func getLessonsCompletedCount() -> Int {
        getUserProgress()?.lessonsCompleted.count ?? 0
    }
    
    func getVocabularyMasteredCount() -> Int {
        getUserProgress()?.vocabularyMastered.count ?? 0
    }
    
    func getCurrentStreak() -> Int {
        getUserProgress()?.currentStreak ?? 0
    }
    
    func getTotalXP() -> Int {
        getUserProgress()?.totalXP ?? 0
    }
    
    func getTodayXP() -> Int {
        getUserProgress()?.todayXP ?? 0
    }
    
    func getDailyGoal() -> Int {
        getUserProgress()?.dailyGoal ?? 50
    }
    
    func getAchievements() -> [String] {
        getUserProgress()?.achievements ?? []
    }

    func getConversationsPracticedCount() -> Int {
        getUserProgress()?.conversationsPracticed.count ?? 0
    }

    // MARK: - Cloud Merge Helpers

    private func consolidateUserProgress(_ records: [UserProgress], ownerId: String) -> UserProgress {
        precondition(!records.isEmpty, "Expected at least one UserProgress record")
        var primary = records[0]
        if let strongest = records.max(by: { !isUserProgress($0, strongerThan: $1) }) {
            primary = strongest
        }

        var didMutate = primary.ownerUserId != ownerId
        if didMutate {
            primary.ownerUserId = ownerId
        }

        for record in records where record !== primary {
            primary.totalXP = max(primary.totalXP, record.totalXP)
            primary.currentStreak = max(primary.currentStreak, record.currentStreak)
            primary.longestStreak = max(primary.longestStreak, record.longestStreak)
            primary.dailyGoal = max(primary.dailyGoal, record.dailyGoal)
            primary.todayXP = max(primary.todayXP, record.todayXP)
            primary.currentStage = max(primary.currentStage, record.currentStage)
            primary.lastPracticeDate = maxDate(primary.lastPracticeDate, record.lastPracticeDate)
            primary.lessonsCompleted = mergedUnique(primary.lessonsCompleted, record.lessonsCompleted)
            primary.patternsLearned = mergedUnique(primary.patternsLearned, record.patternsLearned)
            primary.vocabularyMastered = mergedUnique(primary.vocabularyMastered, record.vocabularyMastered)
            primary.conversationsPracticed = mergedUnique(primary.conversationsPracticed, record.conversationsPracticed)
            primary.achievements = mergedUnique(primary.achievements, record.achievements)
            primary.fidelCharactersRecognized = mergedUnique(primary.fidelCharactersRecognized, record.fidelCharactersRecognized)
            primary.charactersTraced = mergedUnique(primary.charactersTraced, record.charactersTraced)
            primary.updatedAt = maxDate(primary.updatedAt, record.updatedAt) ?? Date()
            didMutate = true
            modelContext.delete(record)
        }

        if didMutate {
            primary.updatedAt = Date()
        }

        return primary
    }

    private func isUserProgress(_ lhs: UserProgress, strongerThan rhs: UserProgress) -> Bool {
        if lhs.totalXP != rhs.totalXP { return lhs.totalXP > rhs.totalXP }
        if lhs.currentStage != rhs.currentStage { return lhs.currentStage > rhs.currentStage }
        if lhs.lessonsCompleted.count != rhs.lessonsCompleted.count {
            return lhs.lessonsCompleted.count > rhs.lessonsCompleted.count
        }
        if lhs.vocabularyMastered.count != rhs.vocabularyMastered.count {
            return lhs.vocabularyMastered.count > rhs.vocabularyMastered.count
        }
        if lhs.conversationsPracticed.count != rhs.conversationsPracticed.count {
            return lhs.conversationsPracticed.count > rhs.conversationsPracticed.count
        }
        return lhs.updatedAt > rhs.updatedAt
    }

    private func deduplicatedFlashcards(from cards: [FlashcardProgress], ownerId: String) -> [FlashcardProgress] {
        var grouped: [String: [FlashcardProgress]] = [:]
        grouped.reserveCapacity(cards.count)

        for card in cards {
            let key = "\(card.itemType)::\(card.itemId)"
            grouped[key, default: []].append(card)
        }

        return grouped.values.map { records in
            consolidateFlashcardProgress(records, ownerId: ownerId)
        }
    }

    private func consolidateFlashcardProgress(_ records: [FlashcardProgress], ownerId: String) -> FlashcardProgress {
        precondition(!records.isEmpty, "Expected at least one FlashcardProgress record")
        var primary = records[0]
        if let strongest = records.max(by: { !isFlashcardProgress($0, strongerThan: $1) }) {
            primary = strongest
        }

        var didMutate = primary.ownerUserId != ownerId
        if didMutate {
            primary.ownerUserId = ownerId
        }

        for record in records where record !== primary {
            // Keep the most advanced scheduling state in case local and cloud copies both exist.
            if isFlashcardProgress(record, strongerThan: primary) {
                primary.easeFactor = record.easeFactor
                primary.interval = record.interval
                primary.repetitions = record.repetitions
                primary.nextReviewDate = record.nextReviewDate
                primary.lastReviewDate = record.lastReviewDate
                primary.stability = record.stability
                primary.difficulty = record.difficulty
                primary.lapses = record.lapses
            }
            didMutate = true
            modelContext.delete(record)
        }

        if didMutate {
            primary.updatedAt = Date()
        }

        return primary
    }

    private func isFlashcardProgress(_ lhs: FlashcardProgress, strongerThan rhs: FlashcardProgress) -> Bool {
        if lhs.repetitions != rhs.repetitions { return lhs.repetitions > rhs.repetitions }
        if lhs.interval != rhs.interval { return lhs.interval > rhs.interval }
        let lhsLast = lhs.lastReviewDate ?? .distantPast
        let rhsLast = rhs.lastReviewDate ?? .distantPast
        if lhsLast != rhsLast { return lhsLast > rhsLast }
        return lhs.updatedAt > rhs.updatedAt
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

    private func mergedUnique<T: Hashable>(_ lhs: [T], _ rhs: [T]) -> [T] {
        Array(Set(lhs).union(rhs))
    }
}
