import Foundation
import SwiftUI
import SwiftData

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
struct FidelCharacter: Identifiable, Hashable {
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

// MARK: - SwiftData Models for Persistence

@Model
final class UserProgress {
    var id: UUID
    var totalXP: Int
    var currentStreak: Int
    var longestStreak: Int
    var lastPracticeDate: Date?
    var lessonsCompleted: [Int]
    var patternsLearned: [String]
    var vocabularyMastered: [String]
    var conversationsPracticed: [Int]
    var dailyGoal: Int
    var todayXP: Int
    var achievements: [String]
    var fidelCharactersRecognized: [String]
    var charactersTraced: [String]
    var currentStage: Int

    init() {
        self.id = UUID()
        self.totalXP = 0
        self.currentStreak = 0
        self.longestStreak = 0
        self.lastPracticeDate = nil
        self.lessonsCompleted = []
        self.patternsLearned = []
        self.vocabularyMastered = []
        self.conversationsPracticed = []
        self.dailyGoal = 50
        self.todayXP = 0
        self.achievements = []
        self.fidelCharactersRecognized = []
        self.charactersTraced = []
        self.currentStage = 0
    }

    func recognizeFidelCharacter(_ charId: String) {
        if !fidelCharactersRecognized.contains(charId) {
            fidelCharactersRecognized.append(charId)
            addXP(2)
        }
    }

    func traceCharacter(_ charId: String) {
        if !charactersTraced.contains(charId) {
            charactersTraced.append(charId)
            addXP(5)
        }
    }

    var learningStage: LearningStage {
        LearningStage(rawValue: currentStage) ?? .scriptAndSounds
    }
    
    func addXP(_ amount: Int) {
        totalXP += amount
        todayXP += amount
        checkStreak()
    }
    
    func checkStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
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
        
        lastPracticeDate = Date()
    }
    
    func completeLesson(_ lessonId: Int) {
        if !lessonsCompleted.contains(lessonId) {
            lessonsCompleted.append(lessonId)
            addXP(25)
        }
    }
    
    func learnPattern(_ patternId: String) {
        if !patternsLearned.contains(patternId) {
            patternsLearned.append(patternId)
            addXP(10)
        }
    }
    
    func masterVocabulary(_ wordId: String) {
        if !vocabularyMastered.contains(wordId) {
            vocabularyMastered.append(wordId)
            addXP(5)
        }
    }
    
    func practiceConversation(_ conversationId: Int) {
        if !conversationsPracticed.contains(conversationId) {
            conversationsPracticed.append(conversationId)
            addXP(20)
        }
    }
}

@Model
final class FlashcardProgress {
    var id: UUID
    var itemId: String
    var itemType: String
    var easeFactor: Double
    var interval: Int
    var repetitions: Int
    var nextReviewDate: Date
    var lastReviewDate: Date?
    var stability: Double
    var difficulty: Double
    var lapses: Int
    
    init(itemId: String, itemType: String) {
        self.id = UUID()
        self.itemId = itemId
        self.itemType = itemType
        self.easeFactor = 2.5
        self.interval = 0
        self.repetitions = 0
        self.nextReviewDate = Date()
        self.lastReviewDate = nil
        self.stability = 0
        self.difficulty = 0
        self.lapses = 0
    }
}

// MARK: - Quiz Types

enum QuizType: String, CaseIterable {
    case multipleChoice = "Multiple Choice"
    case translation = "Translation"
    case listening = "Listening"
    case fillInBlank = "Fill in the Blank"
    case matching = "Matching"
}

struct QuizQuestion: Identifiable {
    let id = UUID()
    let type: QuizType
    let question: String
    let amharic: String?
    let correctAnswer: String
    let options: [String]
    let transliterationHint: String?
    var userAnswer: String?
    
    init(type: QuizType, question: String, amharic: String?, correctAnswer: String, options: [String], transliterationHint: String? = nil) {
        self.type = type
        self.question = question
        self.amharic = amharic
        self.correctAnswer = correctAnswer
        self.options = options
        self.transliterationHint = transliterationHint
    }
    
    var isCorrect: Bool {
        userAnswer?.lowercased() == correctAnswer.lowercased()
    }
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
    Achievement(id: "social_butterfly", title: "Social Butterfly", description: "Practice all 10 conversations", icon: "person.3.fill", requirement: 10, category: .conversations),
    Achievement(id: "xp_100", title: "Rising Star", description: "Earn 100 XP", icon: "star", requirement: 100, category: .xp),
    Achievement(id: "xp_500", title: "Shining Star", description: "Earn 500 XP", icon: "star.circle", requirement: 500, category: .xp),
    Achievement(id: "xp_1000", title: "Superstar", description: "Earn 1000 XP", icon: "star.circle.fill", requirement: 1000, category: .xp),
]

// MARK: - Practice Mode

enum PracticeMode: String, CaseIterable, Identifiable, Hashable {
    case flashcards = "Flashcards"
    case quiz = "Quiz"
    case pronunciation = "Pronunciation"
    case sentenceBuilder = "Sentence Builder"
    case speedDrill = "Speed Drill"
    case tracing = "Character Tracing"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .flashcards: return "rectangle.stack.fill"
        case .quiz: return "questionmark.circle.fill"
        case .pronunciation: return "waveform.and.mic"
        case .sentenceBuilder: return "text.word.spacing"
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
        case .speedDrill: return "Rapid-fire translation practice"
        case .tracing: return "Practice writing Fidel characters"
        }
    }

    var color: Color {
        switch self {
        case .flashcards: return .blue
        case .quiz: return .purple
        case .pronunciation: return AppTheme.primaryColor
        case .sentenceBuilder: return .orange
        case .speedDrill: return AppTheme.accentRed
        case .tracing: return .indigo
        }
    }
}
