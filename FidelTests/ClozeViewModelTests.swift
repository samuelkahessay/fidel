import XCTest
import Foundation
@testable import Fidel___Learn_Amharic

// MARK: - Stub repository

/// Minimal `LessonRepositoryProtocol` stub: only `getSentenceExercises` is backed
/// by fixtures (the only accessor the cloze exercise reads); everything else
/// returns empty so the protocol conformance compiles without real content.
private final class StubClozeRepository: LessonRepositoryProtocol {
    var sentenceExercises: [SentenceExercise]

    init(sentenceExercises: [SentenceExercise] = []) {
        self.sentenceExercises = sentenceExercises
    }

    func getSentenceExercises() -> [SentenceExercise] { sentenceExercises }

    // Unused by the cloze exercise — return empties.
    func getLessons() -> [Lesson] { [] }
    func getLesson(by id: Int) -> Lesson? { nil }
    func getPatterns() -> [Pattern] { [] }
    func getConversations() -> [Conversation] { [] }
    func getConversation(by id: Int) -> Conversation? { nil }
    func getPhrases() -> [Phrase] { [] }
    func getVocabulary() -> [VocabularyWord] { [] }
    func getVocabulary(for category: String) -> [VocabularyWord] { [] }
    func getVocabularyCategories() -> [String] { [] }
    func getFidelChart() -> [[FidelCharacter]] { [] }
    func getNumbers() -> [AmharicNumber] { [] }
    func getEthiopianMonths() -> [EthiopianMonth] { [] }
    func getOrdinalNumbers() -> [OrdinalNumber] { [] }
    func getFractions() -> [AmharicFraction] { [] }
    func getCulturalNotes() -> [CulturalNote] { [] }
    func getCulturalNotes(forLesson lessonId: Int) -> [CulturalNote] { [] }
    func getCulturalNotes(forConversation conversationId: Int) -> [CulturalNote] { [] }
    func getReadingPassages() -> [ReadingPassage] { [] }
}

// MARK: - Fixtures

private enum ClozeFixtures {
    /// Two-token sentence: blanking the middle index (2 / 2 == 1) makes ነኝ the
    /// answer, with two distinct distractors for a real multiple-choice.
    static func twoToken() -> SentenceExercise {
        SentenceExercise(
            id: "cloze-2",
            unit: 1,
            english: "I am fine",
            amharic: "ደህና ነኝ",
            transliteration: "dehna negn",
            amharicTokens: [
                .init(amharic: "ደህና", transliteration: "dehna", english: "fine"),
                .init(amharic: "ነኝ", transliteration: "negn", english: "I am"),
            ],
            englishTokens: ["i", "am", "fine"],
            amharicDistractors: [
                .init(amharic: "ነህ", transliteration: "neh", english: "you are"),
                .init(amharic: "ናት", transliteration: "nat", english: "she is"),
            ],
            englishDistractors: ["you", "are"]
        )
    }

    /// Single-token sentence — must be filtered out (blanking it would leave no
    /// context).
    static func oneToken() -> SentenceExercise {
        SentenceExercise(
            id: "cloze-1",
            unit: 1,
            english: "Yes",
            amharic: "አዎ",
            transliteration: "awo",
            amharicTokens: [.init(amharic: "አዎ", transliteration: "awo", english: "yes")],
            englishTokens: ["yes"],
            amharicDistractors: [],
            englishDistractors: []
        )
    }
}

// MARK: - Tests

@MainActor
final class ClozeViewModelTests: XCTestCase {

    private func makeViewModel(_ exercises: [SentenceExercise]) -> ClozeViewModel {
        ClozeViewModel(lessonRepository: StubClozeRepository(sentenceExercises: exercises))
    }

    func testBlanksMiddleTokenAndBuildsOptions() throws {
        let vm = makeViewModel([ClozeFixtures.twoToken()])
        vm.startSession(count: 1)

        XCTAssertEqual(vm.questions.count, 1)
        let question = try XCTUnwrap(vm.currentQuestion)
        XCTAssertEqual(question.correctAnswer, "ነኝ")

        // Exactly one blank segment, in the middle (index 1 of 2).
        XCTAssertEqual(question.segments.filter { $0.isBlank }.count, 1)

        // Options include the answer plus the two distractors, none duplicated.
        XCTAssertEqual(Set(question.options.map { $0.amharic }), ["ነኝ", "ነህ", "ናት"])
    }

    func testSelectingCorrectOptionScores() throws {
        let vm = makeViewModel([ClozeFixtures.twoToken()])
        vm.startSession(count: 1)
        let question = try XCTUnwrap(vm.currentQuestion)

        let correct = try XCTUnwrap(question.options.first { $0.amharic == question.correctAnswer })
        vm.select(correct)

        XCTAssertTrue(vm.showFeedback)
        XCTAssertTrue(vm.lastWasCorrect)
        XCTAssertEqual(vm.score, 1)
        XCTAssertEqual(vm.earnedXP, 10)
    }

    func testSelectingWrongOptionDoesNotScore() throws {
        let vm = makeViewModel([ClozeFixtures.twoToken()])
        vm.startSession(count: 1)
        let question = try XCTUnwrap(vm.currentQuestion)

        let wrong = try XCTUnwrap(question.options.first { $0.amharic != question.correctAnswer })
        vm.select(wrong)

        XCTAssertTrue(vm.showFeedback)
        XCTAssertFalse(vm.lastWasCorrect)
        XCTAssertEqual(vm.score, 0)
        XCTAssertEqual(vm.earnedXP, 0)
    }

    func testSelectIsIgnoredAfterFeedback() throws {
        let vm = makeViewModel([ClozeFixtures.twoToken()])
        vm.startSession(count: 1)
        let question = try XCTUnwrap(vm.currentQuestion)
        let correct = try XCTUnwrap(question.options.first { $0.amharic == question.correctAnswer })
        let wrong = try XCTUnwrap(question.options.first { $0.amharic != question.correctAnswer })

        vm.select(correct)
        vm.select(wrong) // second selection must be a no-op once feedback is showing
        XCTAssertTrue(vm.lastWasCorrect)
        XCTAssertEqual(vm.score, 1)
    }

    func testSessionCompletesAndReportsResults() throws {
        let vm = makeViewModel([ClozeFixtures.twoToken(), ClozeFixtures.twoToken()])
        vm.startSession(count: 2)
        XCTAssertEqual(vm.questions.count, 2)

        // Answer both correctly.
        for _ in 0..<2 {
            let question = try XCTUnwrap(vm.currentQuestion)
            let correct = try XCTUnwrap(question.options.first { $0.amharic == question.correctAnswer })
            vm.select(correct)
            vm.advance()
        }

        XCTAssertTrue(vm.showResult)
        XCTAssertEqual(vm.score, 2)
        XCTAssertEqual(vm.earnedXP, 20)
    }

    func testSingleTokenExerciseIsFilteredOut() {
        let vm = makeViewModel([ClozeFixtures.oneToken()])
        vm.startSession(count: 8)
        XCTAssertTrue(vm.questions.isEmpty)
        XCTAssertNil(vm.currentQuestion)
    }
}
