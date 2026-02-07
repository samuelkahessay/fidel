import Foundation

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

    func generateVocabularyQuiz(count: Int = 10, vocabulary: [VocabularyWord]? = nil) {
        let sourceVocab = vocabulary ?? lessonRepository.getVocabulary()
        let words = Array(sourceVocab.shuffled().prefix(count))
        let allVocab = sourceVocab.count > 3 ? sourceVocab : lessonRepository.getVocabulary()

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
