import Foundation

/// Drives the Cloze ("fill in the blank") exercise: one word is removed from an
/// Amharic sentence and the learner picks the missing word from options, with the
/// English translation shown for context. Teaching vocabulary *in context* is a
/// higher-value drill than isolated-word review.
///
/// Reuses the bundled `sentence_exercises.json` data verbatim — the sentence's
/// `amharicTokens` supply the sentence and the correct answer, and
/// `amharicDistractors` supply the wrong options. No new content is authored.
@MainActor
@Observable
final class ClozeViewModel {

    /// A selectable answer option (an Amharic word).
    struct Option: Identifiable, Hashable {
        let id = UUID()
        let amharic: String
        let transliteration: String?
    }

    /// One piece of the displayed sentence: a fixed word, or the blank to fill.
    struct Segment: Identifiable, Hashable {
        let id = UUID()
        let text: String     // token text, or "" for the blank
        let isBlank: Bool
    }

    /// A single cloze question: a sentence with exactly one token blanked.
    struct Question: Identifiable {
        let id: String
        let english: String                 // context prompt shown above the sentence
        let segments: [Segment]             // the sentence rendered with one blank
        let correctAnswer: String           // Amharic text of the missing word
        let correctTransliteration: String? // shown as a hint on reveal
        let fullAmharic: String             // complete sentence, shown on reveal
        let fullTransliteration: String
        let options: [Option]
    }

    private(set) var questions: [Question] = []
    var currentIndex = 0
    var selectedOption: Option?
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

    var earnedXP: Int { correctCount * 10 }

    // MARK: - Session lifecycle

    func startSession(count: Int = 8) {
        let usable = lessonRepository.getSentenceExercises()
            .filter { $0.amharicTokens.count >= 2 }   // need ≥2 tokens so blanking leaves context
            .shuffled()
            .prefix(count)
        questions = usable.compactMap { Self.makeQuestion(from: $0) }
        currentIndex = 0
        score = 0
        correctCount = 0
        didAwardXP = false
        selectedOption = nil
        showFeedback = false
        lastWasCorrect = false
        showResult = false
    }

    func restart() { startSession() }

    // MARK: - Interaction

    /// Selecting an option grades immediately (no separate Check step) — the
    /// canonical cloze/multiple-choice flow.
    func select(_ option: Option) {
        guard !showFeedback, let q = currentQuestion else { return }
        selectedOption = option
        lastWasCorrect = normalize(option.amharic) == normalize(q.correctAnswer)
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
            selectedOption = nil
            showFeedback = false
            lastWasCorrect = false
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

    /// Blanks the deterministic middle token (`count / 2`) so a fixture's blank is
    /// predictable in tests, then builds 2–4 options from the exercise's Amharic
    /// distractors, falling back to the sentence's other tokens when there aren't
    /// enough distractors to offer a real choice.
    private static func makeQuestion(from exercise: SentenceExercise) -> Question? {
        let tokens = exercise.amharicTokens
        guard tokens.count >= 2 else { return nil }

        let blankIndex = tokens.count / 2
        let answer = tokens[blankIndex]

        var segments: [Segment] = []
        for (index, token) in tokens.enumerated() {
            let isBlank = index == blankIndex
            segments.append(Segment(text: isBlank ? "" : token.amharic, isBlank: isBlank))
        }

        // Options: correct answer + up to 3 distinct distractors.
        var options: [Option] = [Option(amharic: answer.amharic, transliteration: answer.transliteration)]
        func addOption(amharic: String, transliteration: String?) {
            guard options.count < 4 else { return }
            guard !options.contains(where: { $0.amharic == amharic }) else { return }
            options.append(Option(amharic: amharic, transliteration: transliteration))
        }
        for distractor in exercise.amharicDistractors {
            addOption(amharic: distractor.amharic, transliteration: distractor.transliteration)
        }
        // Guarantee at least one wrong option even when the exercise has no distractors.
        if options.count < 2 {
            for token in tokens where token.amharic != answer.amharic {
                addOption(amharic: token.amharic, transliteration: token.transliteration)
            }
        }

        return Question(
            id: "\(exercise.id)-cloze",
            english: exercise.english,
            segments: segments,
            correctAnswer: answer.amharic,
            correctTransliteration: answer.transliteration,
            fullAmharic: exercise.amharic,
            fullTransliteration: exercise.transliteration,
            options: options.shuffled()
        )
    }
}
