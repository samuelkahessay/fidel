import XCTest
import Foundation
@testable import Fidel___Learn_Amharic

// MARK: - Stub repository

/// Minimal `LessonRepositoryProtocol` stub: only the two accessors the word-bank
/// and match-pairs exercises read are backed by fixtures; everything else returns
/// empty so the protocol conformance compiles without dragging in real content.
private final class StubLessonRepository: LessonRepositoryProtocol {
    var sentenceExercises: [SentenceExercise]
    var vocabulary: [VocabularyWord]

    init(sentenceExercises: [SentenceExercise] = [], vocabulary: [VocabularyWord] = []) {
        self.sentenceExercises = sentenceExercises
        self.vocabulary = vocabulary
    }

    func getSentenceExercises() -> [SentenceExercise] { sentenceExercises }
    func getVocabulary() -> [VocabularyWord] { vocabulary }

    // Unused by the exercises under test — return empties.
    func getLessons() -> [Lesson] { [] }
    func getLesson(by id: Int) -> Lesson? { nil }
    func getPatterns() -> [Pattern] { [] }
    func getPatterns(for unit: Int) -> [Pattern] { [] }
    func getConversations() -> [Conversation] { [] }
    func getConversation(by id: Int) -> Conversation? { nil }
    func getPhrases() -> [Phrase] { [] }
    func getVocabulary(for category: String) -> [VocabularyWord] { vocabulary }
    func getVocabularyCategories() -> [String] { [] }
    func getShuffledVocabulary(count: Int) -> [VocabularyWord] { Array(vocabulary.prefix(count)) }
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

private enum Fixtures {
    /// One fully-formed word-bank exercise. Token texts and distractor texts are
    /// kept distinct in both languages so "place the answer tiles" is unambiguous
    /// and a reversed order is guaranteed to differ from the answer.
    static func wordOrderExercise() -> SentenceExercise {
        SentenceExercise(
            id: "wo-fixture",
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

    /// Five vocabulary words with distinct English meanings and Amharic spellings,
    /// so de-duplication keeps all five and the session is exactly one round.
    static func vocabulary() -> [VocabularyWord] {
        [
            VocabularyWord(category: "test", amharic: "ውሃ", transliteration: "wuha", english: "water"),
            VocabularyWord(category: "test", amharic: "እንጀራ", transliteration: "injera", english: "injera"),
            VocabularyWord(category: "test", amharic: "ቡና", transliteration: "buna", english: "coffee"),
            VocabularyWord(category: "test", amharic: "ቤት", transliteration: "bet", english: "house"),
            VocabularyWord(category: "test", amharic: "መኪና", transliteration: "mekina", english: "car"),
        ]
    }
}

// MARK: - SentenceExercise JSON decoding

final class SentenceExerciseDecodingTests: XCTestCase {

    func testBundledSentenceExercisesDecode() throws {
        let url = try XCTUnwrap(
            Bundle(for: type(of: self)).url(forResource: "sentence_exercises", withExtension: "json")
                ?? Bundle.main.url(forResource: "sentence_exercises", withExtension: "json"),
            "sentence_exercises.json not found in the test or host-app bundle"
        )

        let data = try Data(contentsOf: url)
        let exercises = try JSONDecoder().decode([SentenceExercise].self, from: data)

        XCTAssertEqual(exercises.count, 24)
        for exercise in exercises {
            XCTAssertFalse(exercise.amharicTokens.isEmpty, "\(exercise.id) has empty amharicTokens")
            XCTAssertFalse(exercise.englishTokens.isEmpty, "\(exercise.id) has empty englishTokens")
        }
    }
}

// MARK: - WordOrderViewModel

@MainActor
final class WordOrderViewModelTests: XCTestCase {

    /// Injecting the same fixture twice makes direction deterministic: a session
    /// alternates `index.isMultiple(of: 2)`, so question 0 is English→Amharic and
    /// question 1 is Amharic→English regardless of the internal shuffle.
    private func makeViewModel() -> WordOrderViewModel {
        let exercise = Fixtures.wordOrderExercise()
        let repo = StubLessonRepository(sentenceExercises: [exercise, exercise])
        return WordOrderViewModel(lessonRepository: repo)
    }

    /// Places, in order, the bank tile whose text matches each answer token.
    private func placeAnswer(_ vm: WordOrderViewModel, reversed: Bool) {
        guard let answer = vm.currentQuestion?.answer else {
            return XCTFail("no current question")
        }
        for token in (reversed ? answer.reversed() : answer) {
            guard let tile = vm.bank.first(where: { $0.text == token }) else {
                return XCTFail("no bank tile for token \(token)")
            }
            vm.placeTile(tile)
        }
    }

    func testCorrectOrderScoresInBothDirections() {
        let vm = makeViewModel()
        let fixture = Fixtures.wordOrderExercise()
        vm.startSession(count: 2)

        // Question 0: English prompt, Amharic answer tiles.
        XCTAssertEqual(vm.currentQuestion?.direction, .englishToAmharic)
        XCTAssertEqual(vm.currentQuestion?.answer, fixture.amharicTokens.map(\.amharic))
        placeAnswer(vm, reversed: false)
        vm.check()
        XCTAssertTrue(vm.lastWasCorrect)
        XCTAssertEqual(vm.score, 1)

        vm.advance()

        // Question 1: Amharic prompt, English answer tiles.
        XCTAssertEqual(vm.currentQuestion?.direction, .amharicToEnglish)
        XCTAssertEqual(vm.currentQuestion?.answer, fixture.englishTokens)
        placeAnswer(vm, reversed: false)
        vm.check()
        XCTAssertTrue(vm.lastWasCorrect)
        XCTAssertEqual(vm.score, 2)
    }

    func testWrongOrderFailsEnglishToAmharic() {
        let vm = makeViewModel()
        vm.startSession(count: 2)

        XCTAssertEqual(vm.currentQuestion?.direction, .englishToAmharic)
        placeAnswer(vm, reversed: true)
        vm.check()

        XCTAssertFalse(vm.lastWasCorrect)
        XCTAssertEqual(vm.score, 0)
    }

    func testWrongOrderFailsAmharicToEnglish() {
        let vm = makeViewModel()
        vm.startSession(count: 2)
        vm.advance() // move to the Amharic→English question

        XCTAssertEqual(vm.currentQuestion?.direction, .amharicToEnglish)
        placeAnswer(vm, reversed: true)
        vm.check()

        XCTAssertFalse(vm.lastWasCorrect)
        XCTAssertEqual(vm.score, 0)
    }
}

// MARK: - MatchPairsViewModel

@MainActor
final class MatchPairsViewModelTests: XCTestCase {

    private func makeViewModel() -> MatchPairsViewModel {
        let repo = StubLessonRepository(vocabulary: Fixtures.vocabulary())
        return MatchPairsViewModel(lessonRepository: repo)
    }

    func testCorrectPairMatchesBothTilesAndCounts() throws {
        let vm = makeViewModel()
        vm.startSession()

        let amharic = vm.amharicTiles[0]
        let english = try XCTUnwrap(vm.englishTiles.first { $0.wordId == amharic.wordId })

        vm.select(amharic)
        vm.select(english)

        XCTAssertEqual(vm.totalMatched, 1)
        XCTAssertEqual(vm.mistakes, 0)
        XCTAssertTrue(vm.amharicTiles.first { $0.id == amharic.id }?.isMatched ?? false)
        XCTAssertTrue(vm.englishTiles.first { $0.id == english.id }?.isMatched ?? false)
    }

    func testWrongPairCountsMistakeAndFlagsTilesWithoutMatching() throws {
        let vm = makeViewModel()
        vm.startSession()

        let amharic = vm.amharicTiles[0]
        let wrongEnglish = try XCTUnwrap(vm.englishTiles.first { $0.wordId != amharic.wordId })

        vm.select(amharic)
        vm.select(wrongEnglish)

        XCTAssertEqual(vm.mistakes, 1)
        XCTAssertEqual(vm.totalMatched, 0)
        XCTAssertTrue(vm.wrongTileIds.contains(amharic.id))
        XCTAssertTrue(vm.wrongTileIds.contains(wrongEnglish.id))
        XCTAssertFalse(vm.amharicTiles.first { $0.id == amharic.id }?.isMatched ?? true)
        XCTAssertFalse(vm.englishTiles.first { $0.id == wrongEnglish.id }?.isMatched ?? true)
    }
}
