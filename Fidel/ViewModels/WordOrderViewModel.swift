import Foundation

/// Drives the Word Order ("Translate") exercise: arrange shuffled word tiles to
/// reconstruct a sentence, in both directions (English prompt → Amharic tiles,
/// and Amharic prompt → English tiles).
@MainActor
@Observable
final class WordOrderViewModel {

    enum Direction {
        case englishToAmharic   // prompt is English, tiles are Amharic
        case amharicToEnglish   // prompt is Amharic, tiles are English
    }

    /// A single draggable/tappable word tile. `id` is unique per instance so the
    /// UI tracks tiles correctly even when two tiles share the same text.
    struct Tile: Identifiable, Hashable {
        let id = UUID()
        let text: String          // displayed word and the value compared against the answer
        let transliteration: String?
        let isAmharic: Bool       // selects the font and whether tapping plays audio
        var audioText: String? { isAmharic ? text : nil }
    }

    struct Question: Identifiable {
        let id: String
        let direction: Direction
        let promptText: String            // the sentence shown as the prompt
        let promptTransliteration: String?
        let promptAudioText: String?      // Amharic sentence to sound on the prompt speaker (amharicToEnglish only)
        let tilesAreAmharic: Bool
        let answer: [String]              // ordered correct values
        let correctText: String           // full correct sentence, shown on a miss
        let bank: [Tile]
    }

    private(set) var questions: [Question] = []
    var currentIndex = 0
    var placed: [Tile] = []
    var bank: [Tile] = []
    var showFeedback = false
    var lastWasCorrect = false
    var showResult = false
    var score = 0

    private var correctCount = 0
    private var didAwardXP = false

    private let lessonRepository: LessonRepositoryProtocol
    private var progressRepository: ProgressRepositoryProtocol?

    init(lessonRepository: LessonRepositoryProtocol = LessonRepository.shared) {
        self.lessonRepository = lessonRepository
    }

    func configure(progressRepository: ProgressRepositoryProtocol) {
        self.progressRepository = progressRepository
    }

    var currentQuestion: Question? {
        currentIndex < questions.count ? questions[currentIndex] : nil
    }

    var isLastQuestion: Bool {
        currentIndex >= questions.count - 1
    }

    /// All tiles placed → the answer can be checked.
    var canCheck: Bool {
        guard let q = currentQuestion else { return false }
        return placed.count == q.answer.count
    }

    var earnedXP: Int { correctCount * 10 }

    // MARK: - Session lifecycle

    func startSession(count: Int = 8) {
        let exercises = Array(lessonRepository.getSentenceExercises().shuffled().prefix(count))
        questions = exercises.enumerated().map { index, exercise in
            // Alternate direction so both "and vice versa" forms appear in a session.
            let direction: Direction = index.isMultiple(of: 2) ? .englishToAmharic : .amharicToEnglish
            return Self.makeQuestion(from: exercise, direction: direction)
        }
        currentIndex = 0
        score = 0
        correctCount = 0
        didAwardXP = false
        showResult = false
        loadCurrentQuestion()
    }

    func restart() {
        startSession()
    }

    private func loadCurrentQuestion() {
        showFeedback = false
        lastWasCorrect = false
        placed = []
        bank = currentQuestion?.bank ?? []
    }

    // MARK: - Tile interaction

    func placeTile(_ tile: Tile) {
        guard !showFeedback, let idx = bank.firstIndex(of: tile) else { return }
        bank.remove(at: idx)
        placed.append(tile)
    }

    func removeTile(_ tile: Tile) {
        guard !showFeedback, let idx = placed.firstIndex(of: tile) else { return }
        placed.remove(at: idx)
        bank.append(tile)
    }

    // MARK: - Checking & progression

    func check() {
        guard let q = currentQuestion, !showFeedback else { return }
        let attempt = placed.map { normalize($0.text) }
        let answer = q.answer.map { normalize($0) }
        lastWasCorrect = attempt == answer
        if lastWasCorrect {
            score += 1
            correctCount += 1
        }
        showFeedback = true
    }

    func advance() {
        if isLastQuestion {
            showResult = true
            awardXPIfNeeded()
        } else {
            currentIndex += 1
            loadCurrentQuestion()
        }
    }

    private func awardXPIfNeeded() {
        guard !didAwardXP else { return }
        didAwardXP = true
        if earnedXP > 0 {
            progressRepository?.addXP(earnedXP)
        }
    }

    private func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespaces).lowercased()
    }

    // MARK: - Question construction

    private static func makeQuestion(from exercise: SentenceExercise, direction: Direction) -> Question {
        switch direction {
        case .englishToAmharic:
            let correct = exercise.amharicTokens.map {
                Tile(text: $0.amharic, transliteration: $0.transliteration, isAmharic: true)
            }
            let distractors = exercise.amharicDistractors.map {
                Tile(text: $0.amharic, transliteration: $0.transliteration, isAmharic: true)
            }
            return Question(
                id: "\(exercise.id)-en2am",
                direction: direction,
                promptText: exercise.english,
                promptTransliteration: nil,
                promptAudioText: nil,
                tilesAreAmharic: true,
                answer: exercise.amharicTokens.map { $0.amharic },
                correctText: exercise.amharic,
                bank: (correct + distractors).shuffled()
            )
        case .amharicToEnglish:
            let correct = exercise.englishTokens.map {
                Tile(text: $0, transliteration: nil, isAmharic: false)
            }
            let distractors = exercise.englishDistractors.map {
                Tile(text: $0, transliteration: nil, isAmharic: false)
            }
            return Question(
                id: "\(exercise.id)-am2en",
                direction: direction,
                promptText: exercise.amharic,
                promptTransliteration: exercise.transliteration,
                promptAudioText: exercise.amharic,
                tilesAreAmharic: false,
                answer: exercise.englishTokens,
                correctText: exercise.english,
                bank: (correct + distractors).shuffled()
            )
        }
    }
}
