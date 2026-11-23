import XCTest
@testable import Fidel___Learn_Amharic

final class CurriculumServiceTests: XCTestCase {
    func testCharactersDerivedFromLessonWordsExistInChart() {
        let lessons = LessonRepository.shared.getLessons()
        let lesson = try! XCTUnwrap(lessons.first { $0.id == 1 })
        let ids = CurriculumService.shared.characterIds(in: lesson)
        XCTAssertFalse(ids.isEmpty, "Lesson 1 words should contain Fidel characters")
        // Every derived id must be a real chart character id ("row-vowel").
        let chartIds = Set(LessonRepository.shared.getFidelChart().flatMap { $0 }.map(\.id))
        for id in ids { XCTAssertTrue(chartIds.contains(id), "\(id) not in chart") }
    }

    func testDerivationIsDeduplicatedAndStable() {
        let lesson = try! XCTUnwrap(LessonRepository.shared.getLessons().first { $0.id == 1 })
        let ids = CurriculumService.shared.characterIds(in: lesson)
        XCTAssertEqual(ids.count, Set(ids).count, "ids should be unique")
    }

    func testMasteryTierBoundaries() {
        let lesson = try! XCTUnwrap(LessonRepository.shared.getLessons().first { $0.id == 1 })
        let vocabIds = lesson.vocabulary.map(\.id)
        let phraseIds = lesson.phrases.map { String($0.id) }
        let charIds = CurriculumService.shared.characterIds(in: lesson)
        let allItemIds = vocabIds + phraseIds
        let allCharIds = charIds

        // Nothing learned -> .new, fraction 0
        let none = CurriculumService.shared.mastery(for: lesson, learnedItemIds: [], recognizedCharIds: [])
        XCTAssertEqual(none.tier, .new)
        XCTAssertEqual(none.fraction, 0, accuracy: 0.001)

        // Everything learned -> .mastered, fraction 1
        let all = CurriculumService.shared.mastery(
            for: lesson, learnedItemIds: Set(allItemIds), recognizedCharIds: Set(allCharIds))
        XCTAssertEqual(all.tier, .mastered)
        XCTAssertEqual(all.fraction, 1, accuracy: 0.001)

        // A single learned item -> .started (any progress, below familiar)
        if let first = allItemIds.first {
            let started = CurriculumService.shared.mastery(
                for: lesson, learnedItemIds: [first], recognizedCharIds: [])
            XCTAssertEqual(started.tier, .started)
        }
    }
}
