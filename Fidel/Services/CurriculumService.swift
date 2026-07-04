// CurriculumService — implemented across Tasks 2 & 4 of the open-learning-path plan.
import Foundation

/// Derives which Fidel characters a lesson "owns" from the characters that
/// actually appear in its vocabulary and phrases — the interleave map is
/// self-maintaining (add a word, its characters are covered automatically).
struct CurriculumService {
    static let shared = CurriculumService()
    private let lessonRepository: LessonRepositoryProtocol
    init(lessonRepository: LessonRepositoryProtocol = LessonRepository.shared) {
        self.lessonRepository = lessonRepository
    }

    /// Glyph string -> FidelCharacter, built once from the chart.
    private func glyphIndex() -> [String: FidelCharacter] {
        var index: [String: FidelCharacter] = [:]
        for row in lessonRepository.getFidelChart() {
            for char in row { index[char.character] = char }
        }
        return index
    }

    /// Fidel characters that appear in this lesson's vocabulary and phrases,
    /// in first-seen order and de-duplicated by character id. Combining marks
    /// and punctuation that aren't in the chart are silently skipped.
    func characters(in lesson: Lesson) -> [FidelCharacter] {
        let index = glyphIndex()
        var seen = Set<String>()
        var result: [FidelCharacter] = []
        let strings = lesson.vocabulary.map(\.amharic) + lesson.phrases.map(\.amharic)
        for string in strings {
            for scalarChar in string.map(String.init) {
                if let fidel = index[scalarChar], seen.insert(fidel.id).inserted {
                    result.append(fidel)
                }
            }
        }
        return result
    }

    func characterIds(in lesson: Lesson) -> [String] { characters(in: lesson).map(\.id) }
}
