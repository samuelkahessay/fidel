import Foundation
import SwiftData

// MARK: - ProgressRepository Protocol

protocol ProgressRepositoryProtocol {
    // User Progress
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
    
    // Statistics
    func getLessonsCompletedCount() -> Int
    func getVocabularyMasteredCount() -> Int
    func getCurrentStreak() -> Int
    func getTotalXP() -> Int
    func getTodayXP() -> Int
    func getDailyGoal() -> Int
    func getAchievements() -> [String]
}

// MARK: - ProgressRepository Implementation

@Observable
final class ProgressRepository: ProgressRepositoryProtocol {
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - User Progress
    
    func getUserProgress() -> UserProgress? {
        let descriptor = FetchDescriptor<UserProgress>()
        return try? modelContext.fetch(descriptor).first
    }
    
    private func getOrCreateUserProgress() -> UserProgress {
        if let existing = getUserProgress() {
            return existing
        }
        let newProgress = UserProgress()
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
        let descriptor = FetchDescriptor<FlashcardProgress>(
            predicate: #Predicate { $0.itemId == itemId && $0.itemType == type }
        )
        
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }
        
        let newProgress = FlashcardProgress(itemId: itemId, itemType: type)
        modelContext.insert(newProgress)
        return newProgress
    }
    
    func recordFlashcardReview(for itemId: String, type: String, rating: ReviewRating) {
        let progress = getOrCreateFlashcardProgress(for: itemId, type: type)
        FSRSAlgorithm.updateFlashcardProgress(progress: progress, rating: rating)
    }
    
    func getDueFlashcards(type: String?) -> [FlashcardProgress] {
        var descriptor = FetchDescriptor<FlashcardProgress>()
        
        if let type = type {
            descriptor.predicate = #Predicate { $0.itemType == type }
        }
        
        guard let allProgress = try? modelContext.fetch(descriptor) else {
            return []
        }
        
        return FSRSAlgorithm.getDueCards(from: allProgress)
    }
    
    func getUpcomingFlashcards(days: Int) -> [FlashcardProgress] {
        let descriptor = FetchDescriptor<FlashcardProgress>()
        guard let allProgress = try? modelContext.fetch(descriptor) else {
            return []
        }
        return FSRSAlgorithm.getUpcomingCards(from: allProgress, days: days)
    }
    
    func initializeFlashcards(vocabulary: [VocabularyWord], phrases: [Phrase]) {
        for word in vocabulary {
            _ = getOrCreateFlashcardProgress(for: word.id, type: "vocabulary")
        }
        for phrase in phrases {
            _ = getOrCreateFlashcardProgress(for: String(phrase.id), type: "phrase")
        }
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
}
