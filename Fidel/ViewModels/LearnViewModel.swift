import Foundation

@Observable
final class LearnViewModel {
    var selectedLesson: Lesson?
    var currentPatternIndex = 0

    private let lessonRepository: LessonRepositoryProtocol

    init(lessonRepository: LessonRepositoryProtocol = LessonRepository.shared) {
        self.lessonRepository = lessonRepository
    }

    var lessons: [Lesson] {
        lessonRepository.getLessons()
    }

    var fidelChart: [[FidelCharacter]] {
        lessonRepository.getFidelChart()
    }

    var currentPattern: Pattern? {
        guard let lesson = selectedLesson,
              currentPatternIndex < lesson.patterns.count else { return nil }
        return lesson.patterns[currentPatternIndex]
    }

    func selectLesson(_ lesson: Lesson) {
        selectedLesson = lesson
        currentPatternIndex = 0
    }

    func nextPattern() {
        guard let lesson = selectedLesson else { return }
        if currentPatternIndex < lesson.patterns.count - 1 {
            currentPatternIndex += 1
        }
    }

    func previousPattern() {
        if currentPatternIndex > 0 {
            currentPatternIndex -= 1
        }
    }

    func getLesson(by id: Int) -> Lesson? {
        lessonRepository.getLesson(by: id)
    }
}
