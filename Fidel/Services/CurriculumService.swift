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

/// Display-only mastery tier for a lesson. Never gates progression — purely
/// informational, derived from how much of a lesson's content is learned.
enum MasteryTier: Int, Comparable, CaseIterable {
    case new, started, familiar, proficient, mastered
    static func < (l: MasteryTier, r: MasteryTier) -> Bool { l.rawValue < r.rawValue }
    var label: String {
        switch self {
        case .new: "New"
        case .started: "Started"
        case .familiar: "Familiar"
        case .proficient: "Proficient"
        case .mastered: "Mastered"
        }
    }
}

extension CurriculumService {
    /// Fraction of a lesson's items (vocab + phrases + its characters) that are
    /// "learned". Display only — never a gate.
    func mastery(
        for lesson: Lesson,
        learnedItemIds: Set<String>,
        recognizedCharIds: Set<String>
    ) -> (tier: MasteryTier, fraction: Double) {
        let vocabIds = lesson.vocabulary.map(\.id)
        let phraseIds = lesson.phrases.map { String($0.id) }
        let charIds = characterIds(in: lesson)
        let total = vocabIds.count + phraseIds.count + charIds.count
        guard total > 0 else { return (.new, 0) }

        let learnedVocabPhrase = (vocabIds + phraseIds).filter { learnedItemIds.contains($0) }.count
        let learnedChars = charIds.filter { recognizedCharIds.contains($0) }.count
        let fraction = Double(learnedVocabPhrase + learnedChars) / Double(total)

        let tier: MasteryTier
        switch fraction {
        case 1: tier = .mastered
        case 0.8..<1: tier = .proficient
        case 0.5..<0.8: tier = .familiar
        case let f where f > 0: tier = .started
        default: tier = .new
        }
        return (tier, fraction)
    }
}
