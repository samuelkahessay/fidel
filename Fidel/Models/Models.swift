import Foundation
import SwiftUI
import SwiftData

enum LocalLearner {
    static let userId = "local-device"
}

// MARK: - Core Data Models

/// Represents a sentence pattern for learning Amharic grammar
struct Pattern: Identifiable, Codable, Hashable {
    let id: String
    let category: String
    let unit: Int
    let description: String
    let structure: String
    let template: String
    let examples: [Example]
    let substitutions: [Substitution]
    
    struct Example: Codable, Hashable {
        let amharic: String
        let transliteration: String
        let english: String
    }
    
    struct Substitution: Codable, Hashable {
        let amharic: String
        let transliteration: String
        let english: String
    }
}

/// Represents a conversation scenario for dialogue practice
struct Conversation: Identifiable, Codable, Hashable {
    let id: Int
    let title: String
    let difficulty: Int
    let lines: [DialogueLine]
    
    struct DialogueLine: Codable, Hashable, Identifiable {
        var id: Int { lineNum }
        let lineNum: Int
        let speaker: String
        let amharic: String
        let transliteration: String
        let english: String
    }
    
    var difficultyStars: String {
        String(repeating: "star.fill", count: difficulty)
    }
}

/// Represents a quick reference phrase
struct Phrase: Identifiable, Codable, Hashable {
    let id: Int
    let amharic: String
    let transliteration: String
    let english: String
    let notes: String
}

/// Represents a vocabulary word with category
struct VocabularyWord: Identifiable, Codable, Hashable {
    var id: String { "\(category)-\(amharic)" }
    let category: String
    let amharic: String
    let transliteration: String
    let english: String
}

/// Fidel (Ethiopic script) character
struct FidelCharacter: Identifiable, Codable, Hashable {
    var id: String { "\(rowIndex)-\(vowelOrder)" }
    let character: String
    let consonant: String
    let rowIndex: Int    // 0-based position in the fidelChart (unique per consonant row)
    let vowelOrder: Int  // 1-7 for the seven vowel forms
    let romanization: String
    let audioHint: String
}

/// A lesson unit containing multiple learning items
struct Lesson: Identifiable, Hashable {
    let id: Int
    let title: String
    let description: String
    let patterns: [Pattern]
    let vocabulary: [VocabularyWord]
    let phrases: [Phrase]
    var isCompleted: Bool = false
    var progressPercent: Double = 0
}

/// A word-bank translation exercise (Duolingo-style "arrange the tiles").
///
/// Answer keys are stored explicitly per direction so the exercise never has to
/// guess word alignment at runtime: `amharicTokens` (in order) is the answer for
/// the English→Amharic direction, and `englishTokens` (in order) is the answer
/// for the Amharic→English direction. Per-word Amharic audio is keyed by each
/// token's `amharic` text (see AudioAssetRepository.wordAsset(forAmharic:)).
struct SentenceExercise: Identifiable, Codable, Hashable {
    let id: String
    let unit: Int
    let english: String
    let amharic: String
    let transliteration: String
    let amharicTokens: [Token]
    let englishTokens: [String]
    let amharicDistractors: [Token]
    let englishDistractors: [String]

    struct Token: Codable, Hashable, Identifiable {
        var id: String { amharic }
        let amharic: String
        let transliteration: String
        let english: String
    }
}

// MARK: - Numeric Reference Types

struct AmharicNumber: Codable, Hashable {
    let amharic: String
    let transliteration: String
    let value: Int
}

struct EthiopianMonth: Codable, Hashable {
    let amharic: String
    let transliteration: String
    let gregorian: String
    let month: Int
}

struct OrdinalNumber: Codable, Hashable {
    let amharic: String
    let transliteration: String
    let value: Int
}

struct AmharicFraction: Codable, Hashable {
    let amharic: String
    let transliteration: String
    let english: String
}

struct NumericReferenceData: Codable {
    let numbers: [AmharicNumber]
    let months: [EthiopianMonth]
    let ordinals: [OrdinalNumber]
    let fractions: [AmharicFraction]
}

// MARK: - SwiftData Models for Persistence

@Model
final class UserProgress {
    var id: UUID = UUID()
    var ownerUserId: String = ""
    var updatedAt: Date = Date()
    var totalXP: Int = 0
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastPracticeDate: Date?
    var lessonsCompleted: [Int] = []
    var patternsLearned: [String] = []
    var vocabularyMastered: [String] = []
    var conversationsPracticed: [Int] = []
    var dailyGoal: Int = 50
    var todayXP: Int = 0
    var achievements: [String] = []
    var fidelCharactersRecognized: [String] = []
    var charactersTraced: [String] = []
    var currentStage: Int = 0

    init(ownerUserId: String = "") {
        self.ownerUserId = ownerUserId
    }

    func recognizeFidelCharacter(_ charId: String) {
        if !fidelCharactersRecognized.contains(charId) {
            fidelCharactersRecognized.append(charId)
            addXP(2)
            updatedAt = .now
        }
    }

    func traceCharacter(_ charId: String) {
        if !charactersTraced.contains(charId) {
            charactersTraced.append(charId)
            if !fidelCharactersRecognized.contains(charId) {
                fidelCharactersRecognized.append(charId)
            }
            addXP(5)
            updatedAt = .now
        }
    }

    var learningStage: LearningStage {
        LearningStage(rawValue: currentStage) ?? .scriptAndSounds
    }
    
    func addXP(_ amount: Int) {
        totalXP += amount
        todayXP += amount
        updatedAt = .now
        checkStreak()
    }
    
    func checkStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date.now)
        
        if let lastDate = lastPracticeDate {
            let lastDay = calendar.startOfDay(for: lastDate)
            let daysDiff = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
            
            if daysDiff == 1 {
                currentStreak += 1
                if currentStreak > longestStreak {
                    longestStreak = currentStreak
                }
            } else if daysDiff > 1 {
                currentStreak = 1
            }
        } else {
            currentStreak = 1
        }
        
        lastPracticeDate = .now
    }
    
    func completeLesson(_ lessonId: Int) {
        if !lessonsCompleted.contains(lessonId) {
            lessonsCompleted.append(lessonId)
            addXP(25)
            updatedAt = .now
        }
    }
    
    func learnPattern(_ patternId: String) {
        if !patternsLearned.contains(patternId) {
            patternsLearned.append(patternId)
            addXP(10)
            updatedAt = .now
        }
    }
    
    func masterVocabulary(_ wordId: String) {
        if !vocabularyMastered.contains(wordId) {
            vocabularyMastered.append(wordId)
            addXP(5)
            updatedAt = .now
        }
    }
    
    func practiceConversation(_ conversationId: Int) {
        if !conversationsPracticed.contains(conversationId) {
            conversationsPracticed.append(conversationId)
            addXP(20)
            updatedAt = .now
        }
    }
}

@Model
final class FlashcardProgress {
    var id: UUID = UUID()
    var ownerUserId: String = ""
    var updatedAt: Date = Date()
    var itemId: String = ""
    var itemType: String = ""
    var easeFactor: Double = 2.5
    var interval: Int = 0
    var repetitions: Int = 0
    var nextReviewDate: Date = Date()
    var lastReviewDate: Date?
    var stability: Double = 0
    var difficulty: Double = 0
    var lapses: Int = 0

    init(itemId: String, itemType: String, ownerUserId: String = "") {
        self.itemId = itemId
        self.itemType = itemType
        self.ownerUserId = ownerUserId
    }
}

// MARK: - Quiz Types

enum QuizType: String, CaseIterable {
    case multipleChoice = "Multiple Choice"
    case translation = "Translation"
    case listening = "Listening"
}

struct QuizQuestion: Identifiable {
    let id = UUID()
    let type: QuizType
    let question: String
    let amharic: String?
    let correctAnswer: String
    let options: [String]
    let transliterationHint: String?
    /// The source word, when this question came from one — lets the UI play its
    /// pre-recorded pronunciation. Nil for questions not built from a vocabulary word.
    let vocabularyWord: VocabularyWord?
    var userAnswer: String?

    init(type: QuizType, question: String, amharic: String?, correctAnswer: String, options: [String], transliterationHint: String? = nil, vocabularyWord: VocabularyWord? = nil) {
        self.type = type
        self.question = question
        self.amharic = amharic
        self.correctAnswer = correctAnswer
        self.options = options
        self.transliterationHint = transliterationHint
        self.vocabularyWord = vocabularyWord
    }
    
    var isCorrect: Bool {
        userAnswer?.lowercased() == correctAnswer.lowercased()
    }
}

// MARK: - Cultural Notes

struct CulturalNote: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let amharicTitle: String
    let content: String
    let icon: String
    let lessonIds: [Int]
    let conversationIds: [Int]
}

// MARK: - Achievement System

struct Achievement: Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let requirement: Int
    let category: AchievementCategory
    
    enum AchievementCategory: String {
        case streak = "Streak"
        case vocabulary = "Vocabulary"
        case conversations = "Conversations"
        case xp = "XP"
        case lessons = "Lessons"
    }
}

let allAchievements: [Achievement] = [
    Achievement(id: "first_steps", title: "First Steps", description: "Complete your first lesson", icon: "figure.walk", requirement: 1, category: .lessons),
    Achievement(id: "word_collector", title: "Word Collector", description: "Learn 50 vocabulary words", icon: "text.book.closed", requirement: 50, category: .vocabulary),
    Achievement(id: "vocabulary_master", title: "Vocabulary Master", description: "Learn 200 vocabulary words", icon: "books.vertical", requirement: 200, category: .vocabulary),
    Achievement(id: "streak_3", title: "On Fire", description: "Maintain a 3-day streak", icon: "flame", requirement: 3, category: .streak),
    Achievement(id: "streak_7", title: "Week Warrior", description: "Maintain a 7-day streak", icon: "flame.fill", requirement: 7, category: .streak),
    Achievement(id: "streak_30", title: "Dedicated Learner", description: "Maintain a 30-day streak", icon: "star.fill", requirement: 30, category: .streak),
    Achievement(id: "conversationalist", title: "Conversationalist", description: "Practice 5 conversations", icon: "bubble.left.and.bubble.right", requirement: 5, category: .conversations),
    Achievement(id: "social_butterfly", title: "Social Butterfly", description: "Practice all 18 conversations", icon: "person.3.fill", requirement: 18, category: .conversations),
    Achievement(id: "xp_100", title: "Rising Star", description: "Earn 100 XP", icon: "star", requirement: 100, category: .xp),
    Achievement(id: "xp_500", title: "Shining Star", description: "Earn 500 XP", icon: "star.circle", requirement: 500, category: .xp),
    Achievement(id: "xp_1000", title: "Superstar", description: "Earn 1000 XP", icon: "star.circle.fill", requirement: 1000, category: .xp),
    Achievement(id: "culture_explorer", title: "Culture Explorer", description: "Complete Lesson 8 (Culture)", icon: "globe.americas.fill", requirement: 8, category: .lessons),
    Achievement(id: "polyglot", title: "Polyglot", description: "Complete all 8 lessons", icon: "graduationcap.fill", requirement: 8, category: .lessons),
]

// MARK: - Practice Mode

enum PracticeMode: String, CaseIterable, Identifiable, Hashable {
    case flashcards = "Flashcards"
    case quiz = "Quiz"
    case pronunciation = "Pronunciation"
    case sentenceBuilder = "Sentence Builder"
    case wordOrder = "Word Order"
    case matchPairs = "Match Pairs"
    case speedDrill = "Speed Drill"
    case tracing = "Character Tracing"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .flashcards: return "rectangle.stack.fill"
        case .quiz: return "questionmark.circle.fill"
        case .pronunciation: return "waveform.and.mic"
        case .sentenceBuilder: return "text.word.spacing"
        case .wordOrder: return "arrow.left.arrow.right"
        case .matchPairs: return "square.on.square"
        case .speedDrill: return "timer"
        case .tracing: return "scribble.variable"
        }
    }

    var description: String {
        switch self {
        case .flashcards: return "Review vocabulary with spaced repetition"
        case .quiz: return "Test your knowledge with multiple choice"
        case .pronunciation: return "Listen and practice speaking"
        case .sentenceBuilder: return "Build sentences using patterns"
        case .wordOrder: return "Tap word tiles into the right order to translate"
        case .matchPairs: return "Match Amharic words to their English meaning"
        case .speedDrill: return "Rapid-fire translation practice"
        case .tracing: return "Practice writing Fidel characters"
        }
    }

    var color: Color {
        switch self {
        case .flashcards: return AppTheme.infoColor
        case .quiz: return AppTheme.practiceColor
        case .pronunciation: return AppTheme.primaryColor
        case .sentenceBuilder: return AppTheme.warningColor
        case .wordOrder: return AppTheme.successColor
        case .matchPairs: return AppTheme.secondaryColor
        case .speedDrill: return AppTheme.accentRed
        case .tracing: return AppTheme.practiceColor
        }
    }
}
