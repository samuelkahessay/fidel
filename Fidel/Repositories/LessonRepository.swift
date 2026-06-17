import Foundation

// MARK: - LessonRepository Protocol

/// Abstracts access to lesson content data
/// Enables future data source changes (API, CoreData, etc.) without affecting ViewModels
protocol LessonRepositoryProtocol {
    // Lessons
    func getLessons() -> [Lesson]
    func getLesson(by id: Int) -> Lesson?
    
    // Patterns
    func getPatterns() -> [Pattern]

    // Sentence (word-bank) exercises
    func getSentenceExercises() -> [SentenceExercise]

    // Conversations
    func getConversations() -> [Conversation]
    func getConversation(by id: Int) -> Conversation?
    
    // Phrases
    func getPhrases() -> [Phrase]
    
    // Vocabulary
    func getVocabulary() -> [VocabularyWord]
    func getVocabulary(for category: String) -> [VocabularyWord]
    func getVocabularyCategories() -> [String]
    
    // Fidel
    func getFidelChart() -> [[FidelCharacter]]

    // Numbers
    func getNumbers() -> [AmharicNumber]
    func getEthiopianMonths() -> [EthiopianMonth]
    func getOrdinalNumbers() -> [OrdinalNumber]
    func getFractions() -> [AmharicFraction]

    // Cultural Notes
    func getCulturalNotes() -> [CulturalNote]
    func getCulturalNotes(forLesson lessonId: Int) -> [CulturalNote]
    func getCulturalNotes(forConversation conversationId: Int) -> [CulturalNote]
}

// MARK: - LessonRepository Implementation

/// Default implementation backed by static AmharicData
final class LessonRepository: LessonRepositoryProtocol {
    
    // MARK: - Singleton (for easy access, but can be injected)
    
    static let shared = LessonRepository()
    
    // MARK: - Lessons
    
    func getLessons() -> [Lesson] {
        AmharicData.lessons
    }
    
    func getLesson(by id: Int) -> Lesson? {
        AmharicData.lessons.first { $0.id == id }
    }
    
    // MARK: - Patterns
    
    func getPatterns() -> [Pattern] {
        AmharicData.patterns
    }
    
    // MARK: - Sentence Exercises

    func getSentenceExercises() -> [SentenceExercise] {
        AmharicData.sentenceExercises
    }

    // MARK: - Conversations
    
    func getConversations() -> [Conversation] {
        AmharicData.conversations
    }
    
    func getConversation(by id: Int) -> Conversation? {
        AmharicData.conversations.first { $0.id == id }
    }
    
    // MARK: - Phrases
    
    func getPhrases() -> [Phrase] {
        AmharicData.phrases
    }
    
    // MARK: - Vocabulary
    
    func getVocabulary() -> [VocabularyWord] {
        AmharicData.vocabulary
    }
    
    func getVocabulary(for category: String) -> [VocabularyWord] {
        AmharicData.vocabularyByCategory(category)
    }
    
    func getVocabularyCategories() -> [String] {
        AmharicData.vocabularyCategories
    }
    
    // MARK: - Fidel
    
    func getFidelChart() -> [[FidelCharacter]] {
        AmharicData.fidelChart
    }
    
    // MARK: - Numbers

    func getNumbers() -> [AmharicNumber] {
        AmharicData.numbers
    }

    func getEthiopianMonths() -> [EthiopianMonth] {
        AmharicData.ethiopianMonths
    }

    func getOrdinalNumbers() -> [OrdinalNumber] {
        AmharicData.ordinalNumbers
    }

    func getFractions() -> [AmharicFraction] {
        AmharicData.fractions
    }

    // MARK: - Cultural Notes

    func getCulturalNotes() -> [CulturalNote] {
        AmharicData.culturalNotes
    }

    func getCulturalNotes(forLesson lessonId: Int) -> [CulturalNote] {
        AmharicData.culturalNotes.filter { $0.lessonIds.contains(lessonId) }
    }

    func getCulturalNotes(forConversation conversationId: Int) -> [CulturalNote] {
        AmharicData.culturalNotes.filter { $0.conversationIds.contains(conversationId) }
    }
}
