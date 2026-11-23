import Foundation
import XCTest

@testable import Fidel___Learn_Amharic

// MARK: - Stub repository

/// Minimal `LessonRepositoryProtocol` stub backing only `getPatterns()`.
private final class StubGrammarRepository: LessonRepositoryProtocol {
    var patterns: [Pattern]
    init(patterns: [Pattern] = []) { self.patterns = patterns }

    func getPatterns() -> [Pattern] { patterns }

    // Unused — return empties.
    func getLessons() -> [Lesson] { [] }
    func getLesson(by id: Int) -> Lesson? { nil }
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
    func getReadingPassages() -> [ReadingPassage] { [] }
}

private enum GrammarFixtures {
    static func pattern(_ id: String, _ category: String, _ unit: Int) -> Pattern {
        Pattern(
            id: id,
            category: category,
            unit: unit,
            description: "rule \(id)",
            structure: "structure \(id)",
            template: "template \(id)",
            examples: [.init(amharic: "አማርኛ", transliteration: "amarNa", english: "Amharic")],
            substitutions: []
        )
    }
}

// MARK: - Tests

@MainActor
final class GrammarExplainerViewModelTests: XCTestCase {

    private func makeViewModel(_ patterns: [Pattern]) -> GrammarExplainerViewModel {
        GrammarExplainerViewModel(lessonRepository: StubGrammarRepository(patterns: patterns))
    }

    func testGroupsPatternsByCategory() {
        let vm = makeViewModel([
            GrammarFixtures.pattern("1.1", "BASIC PRESENT TENSE (Subject + Verb)", 1),
            GrammarFixtures.pattern("1.2", "BASIC PRESENT TENSE (Subject + Verb)", 1),
            GrammarFixtures.pattern("6.1", "PAST TENSE", 6),
        ])

        XCTAssertEqual(vm.topics.count, 2)
        let present = vm.topics.first { $0.id == "BASIC PRESENT TENSE (Subject + Verb)" }
        XCTAssertEqual(present?.patterns.count, 2)
    }

    func testTopicsOrderedByLowestUnit() {
        let vm = makeViewModel([
            GrammarFixtures.pattern("6.1", "PAST TENSE", 6),
            GrammarFixtures.pattern("1.1", "BASIC PRESENT TENSE (Subject + Verb)", 1),
        ])
        // Present tense (unit 1) must sort before Past tense (unit 6).
        XCTAssertEqual(vm.topics.map { $0.title }, ["Basic Present Tense", "Past Tense"])
    }

    func testTitleIsTitleCasedWithoutParenthetical() {
        let vm = makeViewModel([GrammarFixtures.pattern("1.1", "BASIC PRESENT TENSE (Subject + Verb)", 1)])
        XCTAssertEqual(vm.topics.first?.title, "Basic Present Tense")
    }

    func testKnownCategoryUsesCuratedBlurb() {
        let vm = makeViewModel([GrammarFixtures.pattern("1.1", "BASIC PRESENT TENSE (Subject + Verb)", 1)])
        let blurb = vm.topics.first?.blurb ?? ""
        XCTAssertTrue(blurb.contains("to be"), "expected the curated present-tense blurb, got: \(blurb)")
    }

    func testUnknownCategoryFallsBackToDefaultBlurb() {
        let vm = makeViewModel([GrammarFixtures.pattern("99.1", "MADE UP CATEGORY", 99)])
        let topic = vm.topics.first
        XCTAssertEqual(topic?.title, "Made Up Category")
        XCTAssertFalse(topic?.blurb.isEmpty ?? true)
    }

    func testPatternsWithinTopicSortedById() {
        let vm = makeViewModel([
            GrammarFixtures.pattern("1.3", "BASIC PRESENT TENSE (Subject + Verb)", 1),
            GrammarFixtures.pattern("1.1", "BASIC PRESENT TENSE (Subject + Verb)", 1),
            GrammarFixtures.pattern("1.2", "BASIC PRESENT TENSE (Subject + Verb)", 1),
        ])
        XCTAssertEqual(vm.topics.first?.patterns.map { $0.id }, ["1.1", "1.2", "1.3"])
    }
}
