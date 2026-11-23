import Foundation
import XCTest

@testable import Fidel___Learn_Amharic

private final class StubReadingRepository: LessonRepositoryProtocol {
    var passages: [ReadingPassage]
    init(passages: [ReadingPassage] = []) { self.passages = passages }

    func getReadingPassages() -> [ReadingPassage] { passages }

    // Unused — empties.
    func getLessons() -> [Lesson] { [] }
    func getLesson(by id: Int) -> Lesson? { nil }
    func getPatterns() -> [Pattern] { [] }
    func getSentenceExercises() -> [SentenceExercise] { [] }
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
}

@MainActor
final class ReadingViewModelTests: XCTestCase {

    func testLoadsPassagesFromRepository() {
        let fixture = ReadingPassage(
            id: "rp-test", title: "Test", cefr: "A2",
            sentences: [.init(amharic: "ሰላም", transliteration: "selam", english: "hello")],
            glossary: [.init(amharic: "ሰላም", english: "hello")],
            questions: [.init(question: "What is the greeting?", options: ["hello", "bye"], answerIndex: 0)]
        )
        let vm = ReadingViewModel(lessonRepository: StubReadingRepository(passages: [fixture]))
        XCTAssertEqual(vm.passages.count, 1)
        XCTAssertEqual(vm.passages.first?.id, "rp-test")
    }
}

/// Guards the fatalError-on-bad-JSON load path for the new bundled resource.
final class ReadingPassageDecodingTests: XCTestCase {

    func testBundledReadingPassagesDecodeAndAreWellFormed() throws {
        let url = try XCTUnwrap(
            Bundle(for: type(of: self)).url(forResource: "reading_passages", withExtension: "json")
                ?? Bundle.main.url(forResource: "reading_passages", withExtension: "json"),
            "reading_passages.json not found in the test or host-app bundle"
        )
        let passages = try JSONDecoder().decode([ReadingPassage].self, from: try Data(contentsOf: url))

        XCTAssertEqual(passages.count, 5)
        for p in passages {
            XCTAssertFalse(p.sentences.isEmpty, "\(p.id) has no sentences")
            XCTAssertFalse(p.questions.isEmpty, "\(p.id) has no questions")
            for q in p.questions {
                XCTAssertTrue(
                    q.options.indices.contains(q.answerIndex),
                    "\(p.id): answerIndex \(q.answerIndex) out of range for \(q.options.count) options")
            }
        }
    }
}
