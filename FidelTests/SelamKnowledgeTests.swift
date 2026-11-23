import XCTest
@testable import Fidel___Learn_Amharic

final class SelamKnowledgeTests: XCTestCase {
    private let knowledge = SelamKnowledge()

    func testExactEnglishWordRanksFirst() {
        XCTAssertEqual(knowledge.lookupWords("water").first?.amharic, "ውሃ")
        XCTAssertEqual(knowledge.lookupWords("Coffee?").first?.amharic, "ቡና")
    }

    func testAmharicAndTransliterationQueriesResolve() {
        XCTAssertEqual(knowledge.lookupWords("ውሃ").first?.english, "water")
        XCTAssertEqual(knowledge.lookupWords("buna").first?.english, "coffee")
    }

    func testPhrasesAreSearchedWithNotes() throws {
        let hello = try XCTUnwrap(knowledge.lookupWords("hello").first { $0.amharic == "ጤና ይስጥልኝ" })
        XCTAssertNotNil(hello.note)
    }

    func testResultsAreLimitedAndUnique() {
        let results = knowledge.lookupWords("you", limit: 5)
        XCTAssertLessThanOrEqual(results.count, 5)
        XCTAssertEqual(Set(results.map(\.amharic)).count, results.count)
    }

    func testUnknownQueryReturnsNothing() {
        XCTAssertTrue(knowledge.lookupWords("xylophonequark").isEmpty)
        XCTAssertTrue(knowledge.lookupWords("   ").isEmpty)
    }

    func testFidelRowByCharacterOrConsonant() throws {
        let byCharacter = try XCTUnwrap(knowledge.lookupFidelRow("ሉ"))
        XCTAssertEqual(byCharacter.count, 7)
        XCTAssertTrue(byCharacter.contains { $0.character == "ለ" })
        XCTAssertEqual(knowledge.lookupFidelRow("l")?.map(\.character), byCharacter.map(\.character))
        XCTAssertNil(knowledge.lookupFidelRow("ζ"))
    }

    func testGrammarRequiresEveryTerm() {
        let patterns = knowledge.lookupGrammar("question")
        XCTAssertFalse(patterns.isEmpty)
        XCTAssertTrue(knowledge.lookupGrammar("question xylophonequark").isEmpty)
    }

    func testDescribeKeepsAmharicVerbatim() {
        let text = SelamKnowledge.describe(knowledge.lookupWords("water", limit: 1))
        XCTAssertTrue(text.hasPrefix("ውሃ (wuha) - water"))
    }
}
