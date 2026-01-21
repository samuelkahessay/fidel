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
    func getPatterns(for unit: Int) -> [Pattern]
    
    // Conversations
    func getConversations() -> [Conversation]
    func getConversation(by id: Int) -> Conversation?
    
    // Phrases
    func getPhrases() -> [Phrase]
    
    // Vocabulary
    func getVocabulary() -> [VocabularyWord]
    func getVocabulary(for category: String) -> [VocabularyWord]
    func getVocabularyCategories() -> [String]
    func getShuffledVocabulary(count: Int) -> [VocabularyWord]
    
    // Fidel
    func getFidelChart() -> [[FidelCharacter]]
    
    // Numbers
    func getNumbers() -> [(amharic: String, transliteration: String, value: Int)]
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
    
    func getPatterns(for unit: Int) -> [Pattern] {
        AmharicData.patterns.filter { $0.unit == unit }
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
    
    func getShuffledVocabulary(count: Int) -> [VocabularyWord] {
        Array(AmharicData.vocabulary.shuffled().prefix(count))
    }
    
    // MARK: - Fidel
    
    func getFidelChart() -> [[FidelCharacter]] {
        AmharicData.fidelChart
    }
    
    // MARK: - Numbers
    
    func getNumbers() -> [(amharic: String, transliteration: String, value: Int)] {
        AmharicData.numbers
    }
}
