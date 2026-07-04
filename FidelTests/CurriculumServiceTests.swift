// CurriculumServiceTests — implemented across Tasks 2 & 4 of the open-learning-path plan.
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
}
