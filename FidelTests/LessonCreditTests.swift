// LessonCreditTests — implemented in Task 3 of the open-learning-path plan.
import SwiftData
import XCTest
@testable import Fidel___Learn_Amharic

/// Tests that completing a lesson credits the Fidel characters it introduces
/// (as derived by `CurriculumService`) into the user's recognized-characters
/// set — the interleave payoff: script recognition grows through content.
@MainActor
final class LessonCreditTests: XCTestCase {

    /// Containers must outlive the repositories using their contexts.
    private var retainedContainers: [ModelContainer] = []

    override func tearDown() {
        retainedContainers.removeAll()
        super.tearDown()
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            UserProgress.self,
            FlashcardProgress.self,
            SelamConversation.self,
            SelamMessage.self,
            CharacterTraceMastery.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func makeRepository() throws -> ProgressRepository {
        let container = try makeContainer()
        retainedContainers.append(container)
        return ProgressRepository(modelContext: container.mainContext)
    }

    func testCompletingLessonCreditsItsCharacters() throws {
        let repository = try makeRepository()
        let lesson = try XCTUnwrap(LessonRepository.shared.getLessons().first { $0.id == 1 })
        let expected = Set(CurriculumService.shared.characterIds(in: lesson))
        XCTAssertFalse(expected.isEmpty)

        repository.completeLesson(1)

        let recognized = Set(repository.getUserProgress()?.fidelCharactersRecognized ?? [])
        XCTAssertTrue(recognized.isSuperset(of: expected))
    }

    func testCompletingLessonDoesNotDuplicateAnAlreadyRecognizedCharacter() throws {
        let repository = try makeRepository()
        let lesson = try XCTUnwrap(LessonRepository.shared.getLessons().first { $0.id == 1 })
        let firstCharacter = try XCTUnwrap(CurriculumService.shared.characterIds(in: lesson).first)
        repository.recognizeFidelCharacter(firstCharacter)

        repository.completeLesson(1)

        let recognized = repository.getUserProgress()?.fidelCharactersRecognized ?? []
        XCTAssertEqual(
            recognized.filter { $0 == firstCharacter }.count, 1,
            "crediting must be idempotent for characters already recognized"
        )
    }

    func testCompletingLessonStillTracksCompletionAndAwardsItsOwnXP() throws {
        let repository = try makeRepository()

        repository.completeLesson(1)

        let progress = try XCTUnwrap(repository.getUserProgress())
        XCTAssertTrue(progress.lessonsCompleted.contains(1), "existing completion tracking must be preserved")
        XCTAssertGreaterThanOrEqual(progress.totalXP, 25, "existing lesson-completion XP must be preserved")
    }

    // MARK: - In-progress lesson tracking (UserProgress model level)

    func testMarkLessonStartedAddsToInProgressAndCompleteLessonRemovesIt() {
        let progress = UserProgress()

        progress.markLessonStarted(3)
        XCTAssertEqual(progress.lessonsInProgress, [3])

        progress.completeLesson(3)
        XCTAssertFalse(progress.lessonsInProgress.contains(3), "completing a lesson must clear it from lessonsInProgress")
    }
}
