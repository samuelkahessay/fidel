import Foundation

/// Supplies graded reading passages for the Reading (comprehensible-input)
/// lesson type. Comprehension reading is the core 0->proficiency input engine the
/// drill modes don't provide.
@MainActor
@Observable
final class ReadingViewModel {

    let passages: [ReadingPassage]

    init(lessonRepository: LessonRepositoryProtocol = LessonRepository.shared) {
        self.passages = lessonRepository.getReadingPassages()
    }
}
