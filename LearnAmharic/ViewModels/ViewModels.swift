import Foundation
import SwiftUI
import SwiftData
import Combine

// MARK: - AppViewModel

@Observable
final class AppViewModel {
    var isLoading = false
    var errorMessage: String?
    
    private let lessonRepository: LessonRepositoryProtocol
    
    init(lessonRepository: LessonRepositoryProtocol = LessonRepository.shared) {
        self.lessonRepository = lessonRepository
    }
    
    func loadData() {
        isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isLoading = false
        }
    }
}

// MARK: - LearnViewModel

@Observable
final class LearnViewModel {
    var selectedLesson: Lesson?
    var currentPatternIndex = 0
    
    private let lessonRepository: LessonRepositoryProtocol
    
    init(lessonRepository: LessonRepositoryProtocol = LessonRepository.shared) {
        self.lessonRepository = lessonRepository
    }
    
    var lessons: [Lesson] {
        lessonRepository.getLessons()
    }
    
    var fidelChart: [[FidelCharacter]] {
        lessonRepository.getFidelChart()
    }
    
    var currentPattern: Pattern? {
        guard let lesson = selectedLesson,
              currentPatternIndex < lesson.patterns.count else { return nil }
        return lesson.patterns[currentPatternIndex]
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
    
    func getLesson(by id: Int) -> Lesson? {
        lessonRepository.getLesson(by: id)
    }
}

// MARK: - PracticeViewModel

@Observable
final class PracticeViewModel {
    var currentMode: PracticeMode = .flashcards
    var isSessionActive = false
    var sessionScore = 0
    var sessionTotal = 0
    
    enum PracticeMode: CaseIterable {
        case flashcards
        case quiz
        case sentenceBuilder
        case speedDrill
        
        var title: String {
            switch self {
            case .flashcards: return "Flashcards"
            case .quiz: return "Quiz"
            case .sentenceBuilder: return "Sentence Builder"
            case .speedDrill: return "Speed Drill"
            }
        }
        
        var icon: String {
            switch self {
            case .flashcards: return "rectangle.stack"
            case .quiz: return "questionmark.circle"
            case .sentenceBuilder: return "text.alignleft"
            case .speedDrill: return "bolt"
            }
        }
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

// MARK: - ConversationViewModel

@Observable
final class ConversationViewModel {
    var selectedConversation: Conversation?
    var currentLineIndex = 0
    var isPlaying = false
    var selectedRole: String?
    
    private let lessonRepository: LessonRepositoryProtocol
    
    init(lessonRepository: LessonRepositoryProtocol = LessonRepository.shared) {
        self.lessonRepository = lessonRepository
    }
    
    var conversations: [Conversation] {
        lessonRepository.getConversations()
    }
    
    var currentLine: Conversation.DialogueLine? {
        guard let conversation = selectedConversation,
              currentLineIndex < conversation.lines.count else { return nil }
        return conversation.lines[currentLineIndex]
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
    
    func getConversation(by id: Int) -> Conversation? {
        lessonRepository.getConversation(by: id)
    }
}

// MARK: - FlashcardViewModel

@Observable
final class FlashcardViewModel {
    var currentIndex = 0
    var isFlipped = false
    var offset: CGSize = .zero
    var showCompletion = false
    var correctCount = 0
    var incorrectCount = 0
    
    private(set) var vocabulary: [VocabularyWord] = []
    
    private let lessonRepository: LessonRepositoryProtocol
    private var progressRepository: ProgressRepositoryProtocol?
    
    init(lessonRepository: LessonRepositoryProtocol = LessonRepository.shared) {
        self.lessonRepository = lessonRepository
    }
    
    func configure(progressRepository: ProgressRepositoryProtocol) {
        self.progressRepository = progressRepository
    }
    
    func startSession(cardCount: Int = 20) {
        vocabulary = lessonRepository.getShuffledVocabulary(count: cardCount)
        currentIndex = 0
        isFlipped = false
        offset = .zero
        showCompletion = false
        correctCount = 0
        incorrectCount = 0
    }
    
    var currentWord: VocabularyWord? {
        currentIndex < vocabulary.count ? vocabulary[currentIndex] : nil
    }
    
    var progress: String {
        "\(currentIndex + 1)/\(vocabulary.count)"
    }
    
    var accuracyPercentage: Int {
        vocabulary.count > 0 ? Int((Double(correctCount) / Double(vocabulary.count)) * 100) : 0
    }
    
    func flip() {
        isFlipped.toggle()
    }
    
    func handleSwipe(correct: Bool) {
        if correct {
            correctCount += 1
            recordReview(rating: .good)
        } else {
            incorrectCount += 1
            recordReview(rating: .again)
        }
        nextCard()
    }
    
    private func recordReview(rating: ReviewRating) {
        guard let word = currentWord else { return }
        progressRepository?.recordFlashcardReview(for: word.id, type: "vocabulary", rating: rating)
    }
    
    private func nextCard() {
        if currentIndex < vocabulary.count - 1 {
            currentIndex += 1
            isFlipped = false
        } else {
            showCompletion = true
        }
    }
    
    func earnedXP() -> Int {
        correctCount * 5
    }
}

// MARK: - QuizViewModel

@Observable
final class QuizViewModel {
    var questions: [QuizQuestion] = []
    var currentQuestionIndex = 0
    var selectedAnswer: String?
    var showResult = false
    var isComplete = false
    var score = 0
    
    private let lessonRepository: LessonRepositoryProtocol
    
    init(lessonRepository: LessonRepositoryProtocol = LessonRepository.shared) {
        self.lessonRepository = lessonRepository
    }
    
    var currentQuestion: QuizQuestion? {
        currentQuestionIndex < questions.count ? questions[currentQuestionIndex] : nil
    }
    
    var progress: String {
        "\(currentQuestionIndex + 1)/\(questions.count)"
    }
    
    var accuracyPercentage: Int {
        questions.count > 0 ? Int((Double(score) / Double(questions.count)) * 100) : 0
    }
    
    func generateVocabularyQuiz(count: Int = 10) {
        let words = lessonRepository.getShuffledVocabulary(count: count)
        let allVocab = lessonRepository.getVocabulary()
        
        questions = words.map { word in
            let wrongAnswers = allVocab
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
        resetQuiz()
    }
    
    func generatePhraseQuiz(count: Int = 10) {
        let allPhrases = lessonRepository.getPhrases()
        let phrases = Array(allPhrases.shuffled().prefix(count))
        
        questions = phrases.map { phrase in
            let wrongAnswers = allPhrases
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
        resetQuiz()
    }
    
    func generateTranslationQuiz(count: Int = 10) {
        let allPhrases = lessonRepository.getPhrases()
        let phrases = Array(allPhrases.shuffled().prefix(count))
        
        questions = phrases.map { phrase in
            let wrongAnswers = allPhrases
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
        resetQuiz()
    }
    
    func selectAnswer(_ answer: String) {
        selectedAnswer = answer
    }
    
    func submitAnswer() {
        guard let answer = selectedAnswer,
              let question = currentQuestion else { return }
        
        if answer.lowercased() == question.correctAnswer.lowercased() {
            score += 1
        }
        showResult = true
    }
    
    func nextQuestion() {
        showResult = false
        selectedAnswer = nil
        
        if currentQuestionIndex < questions.count - 1 {
            currentQuestionIndex += 1
        } else {
            isComplete = true
        }
    }
    
    private func resetQuiz() {
        currentQuestionIndex = 0
        selectedAnswer = nil
        showResult = false
        isComplete = false
        score = 0
    }
}

// MARK: - ReferenceViewModel

@Observable
final class ReferenceViewModel {
    var searchText = ""
    var selectedCategory: String?
    
    private let lessonRepository: LessonRepositoryProtocol
    
    init(lessonRepository: LessonRepositoryProtocol = LessonRepository.shared) {
        self.lessonRepository = lessonRepository
    }
    
    var phrases: [Phrase] {
        let allPhrases = lessonRepository.getPhrases()
        if searchText.isEmpty {
            return allPhrases
        }
        return allPhrases.filter {
            $0.amharic.contains(searchText) ||
            $0.english.lowercased().contains(searchText.lowercased()) ||
            $0.transliteration.lowercased().contains(searchText.lowercased())
        }
    }
    
    var vocabulary: [VocabularyWord] {
        if let category = selectedCategory {
            return lessonRepository.getVocabulary(for: category)
        }
        let allVocab = lessonRepository.getVocabulary()
        if searchText.isEmpty {
            return allVocab
        }
        return allVocab.filter {
            $0.amharic.contains(searchText) ||
            $0.english.lowercased().contains(searchText.lowercased()) ||
            $0.transliteration.lowercased().contains(searchText.lowercased())
        }
    }
    
    var vocabularyCategories: [String] {
        lessonRepository.getVocabularyCategories()
    }
    
    var numbers: [(amharic: String, transliteration: String, value: Int)] {
        lessonRepository.getNumbers()
    }
    
    func selectCategory(_ category: String?) {
        selectedCategory = category
    }
    
    func clearSearch() {
        searchText = ""
    }
}

// MARK: - ProgressDashboardViewModel

@Observable
final class ProgressDashboardViewModel {
    private var progressRepository: ProgressRepositoryProtocol?
    
    func configure(progressRepository: ProgressRepositoryProtocol) {
        self.progressRepository = progressRepository
    }
    
    var totalXP: Int {
        progressRepository?.getTotalXP() ?? 0
    }
    
    var todayXP: Int {
        progressRepository?.getTodayXP() ?? 0
    }
    
    var dailyGoal: Int {
        progressRepository?.getDailyGoal() ?? 50
    }
    
    var currentStreak: Int {
        progressRepository?.getCurrentStreak() ?? 0
    }
    
    var lessonsCompleted: Int {
        progressRepository?.getLessonsCompletedCount() ?? 0
    }
    
    var vocabularyMastered: Int {
        progressRepository?.getVocabularyMasteredCount() ?? 0
    }
    
    var achievements: [String] {
        progressRepository?.getAchievements() ?? []
    }
    
    var dailyProgress: Double {
        guard dailyGoal > 0 else { return 0 }
        return min(Double(todayXP) / Double(dailyGoal), 1.0)
    }
    
    var level: Int {
        totalXP / 100 + 1
    }
    
    var xpToNextLevel: Int {
        100 - (totalXP % 100)
    }
}

// MARK: - Deprecated QuizGenerator (for backward compatibility)

enum QuizGenerator {
    static func generateVocabularyQuiz(count: Int = 10) -> [QuizQuestion] {
        let vm = QuizViewModel()
        vm.generateVocabularyQuiz(count: count)
        return vm.questions
    }
    
    static func generatePhraseQuiz(count: Int = 10) -> [QuizQuestion] {
        let vm = QuizViewModel()
        vm.generatePhraseQuiz(count: count)
        return vm.questions
    }
    
    static func generateTranslationQuiz(count: Int = 10) -> [QuizQuestion] {
        let vm = QuizViewModel()
        vm.generateTranslationQuiz(count: count)
        return vm.questions
    }
}
