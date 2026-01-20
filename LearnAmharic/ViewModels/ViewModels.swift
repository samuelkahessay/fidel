import Foundation
import SwiftUI
import SwiftData
import Combine

@Observable
class AppViewModel {
    var isLoading = false
    var errorMessage: String?
    
    func loadData() {
        isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isLoading = false
        }
    }
}

@Observable
class LearnViewModel {
    var selectedLesson: Lesson?
    var currentPatternIndex = 0
    
    var lessons: [Lesson] {
        AmharicData.lessons
    }
    
    func selectLesson(_ lesson: Lesson) {
        selectedLesson = lesson
        currentPatternIndex = 0
    }
    
    func nextPattern() {
        guard let lesson = selectedLesson else { return }
        if currentPatternIndex < lesson.patterns.count - 1 {
            currentPatternIndex += 1
        }
    }
    
    func previousPattern() {
        if currentPatternIndex > 0 {
            currentPatternIndex -= 1
        }
    }
}

@Observable
class PracticeViewModel {
    var currentMode: PracticeMode = .flashcards
    var isSessionActive = false
    var sessionScore = 0
    var sessionTotal = 0
    
    enum PracticeMode {
        case flashcards
        case quiz
        case sentenceBuilder
        case speedDrill
    }
    
    func startSession(mode: PracticeMode) {
        currentMode = mode
        isSessionActive = true
        sessionScore = 0
        sessionTotal = 0
    }
    
    func endSession() {
        isSessionActive = false
    }
    
    func recordAnswer(correct: Bool) {
        sessionTotal += 1
        if correct {
            sessionScore += 1
        }
    }
    
    var accuracy: Double {
        sessionTotal > 0 ? Double(sessionScore) / Double(sessionTotal) : 0
    }
}

@Observable
class ConversationViewModel {
    var selectedConversation: Conversation?
    var currentLineIndex = 0
    var isPlaying = false
    var selectedRole: String?
    
    var conversations: [Conversation] {
        AmharicData.conversations
    }
    
    func selectConversation(_ conversation: Conversation) {
        selectedConversation = conversation
        currentLineIndex = 0
        selectedRole = nil
    }
    
    func nextLine() {
        guard let conversation = selectedConversation else { return }
        if currentLineIndex < conversation.lines.count - 1 {
            currentLineIndex += 1
        }
    }
    
    func previousLine() {
        if currentLineIndex > 0 {
            currentLineIndex -= 1
        }
    }
    
    func reset() {
        currentLineIndex = 0
        isPlaying = false
    }
}

class QuizGenerator {
    static func generateVocabularyQuiz(count: Int = 10) -> [QuizQuestion] {
        let words = AmharicData.vocabulary.shuffled().prefix(count)
        
        return words.map { word in
            let wrongAnswers = AmharicData.vocabulary
                .filter { $0.english != word.english }
                .shuffled()
                .prefix(3)
                .map { $0.english }
            
            let options = ([word.english] + wrongAnswers).shuffled()
            
            return QuizQuestion(
                type: .multipleChoice,
                question: "What does this word mean?",
                amharic: word.amharic,
                correctAnswer: word.english,
                options: options
            )
        }
    }
    
    static func generatePhraseQuiz(count: Int = 10) -> [QuizQuestion] {
        let phrases = AmharicData.phrases.shuffled().prefix(count)
        
        return phrases.map { phrase in
            let wrongAnswers = AmharicData.phrases
                .filter { $0.english != phrase.english }
                .shuffled()
                .prefix(3)
                .map { $0.english }
            
            let options = ([phrase.english] + wrongAnswers).shuffled()
            
            return QuizQuestion(
                type: .multipleChoice,
                question: "What does this phrase mean?",
                amharic: phrase.amharic,
                correctAnswer: phrase.english,
                options: options
            )
        }
    }
    
    static func generateTranslationQuiz(count: Int = 10) -> [QuizQuestion] {
        let phrases = AmharicData.phrases.shuffled().prefix(count)
        
        return phrases.map { phrase in
            let wrongAnswers = AmharicData.phrases
                .filter { $0.amharic != phrase.amharic }
                .shuffled()
                .prefix(3)
                .map { $0.amharic }
            
            let options = ([phrase.amharic] + wrongAnswers).shuffled()
            
            return QuizQuestion(
                type: .translation,
                question: "Translate to Amharic:",
                amharic: phrase.english,
                correctAnswer: phrase.amharic,
                options: options
            )
        }
    }
}
