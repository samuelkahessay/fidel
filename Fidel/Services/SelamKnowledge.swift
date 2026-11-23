import Foundation

/// Searches Fidel's bundled curriculum so Selam can quote real Amharic instead
/// of generating it. Apple's on-device model does not support Amharic, so every
/// Amharic string Selam shows must come from here.
struct SelamKnowledge: Sendable {
    struct Entry: Equatable {
        let amharic: String
        let transliteration: String
        let english: String
        let note: String?
    }

    private let vocabulary: [VocabularyWord]
    private let phrases: [Phrase]
    private let patterns: [Pattern]
    private let fidelChart: [[FidelCharacter]]

    init(repository: LessonRepositoryProtocol = LessonRepository.shared) {
        vocabulary = repository.getVocabulary()
        phrases = repository.getPhrases()
        patterns = repository.getPatterns()
        fidelChart = repository.getFidelChart()
    }

    /// Vocabulary and phrases whose English, Amharic or transliteration match `query`,
    /// best matches first.
    func lookupWords(_ query: String, limit: Int = 5) -> [Entry] {
        let needle = Self.normalize(query)
        guard !needle.isEmpty else { return [] }

        let words = vocabulary.map {
            Entry(amharic: $0.amharic, transliteration: $0.transliteration, english: $0.english, note: nil)
        }
        let phrases = phrases.map {
            Entry(amharic: $0.amharic, transliteration: $0.transliteration, english: $0.english,
                  note: $0.notes.isEmpty ? nil : $0.notes)
        }

        var seen = Set<String>()
        return (words + phrases)
            .compactMap { entry -> (Entry, Int)? in
                let score = Self.score(entry, needle: needle)
                return score > 0 ? (entry, score) : nil
            }
            .sorted { lhs, rhs in
                lhs.1 != rhs.1 ? lhs.1 > rhs.1 : lhs.0.english.count < rhs.0.english.count
            }
            .map(\.0)
            .filter { seen.insert($0.amharic).inserted }
            .prefix(limit)
            .map { $0 }
    }

    /// Grammar patterns whose description, category or structure mention every word of `query`.
    func lookupGrammar(_ query: String, limit: Int = 3) -> [Pattern] {
        let terms = Self.normalize(query).split(separator: " ").map(String.init)
        guard !terms.isEmpty else { return [] }
        return patterns
            .filter { pattern in
                let haystack = Self.normalize("\(pattern.category) \(pattern.description) \(pattern.structure)")
                return terms.allSatisfy { haystack.contains($0) }
            }
            .prefix(limit)
            .map { $0 }
    }

    /// The seven vowel forms of the row containing `query`, which may be a fidel
    /// character ("ለ", "ሉ") or a consonant romanization ("l").
    func lookupFidelRow(_ query: String) -> [FidelCharacter]? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = trimmed.lowercased()
        return fidelChart.first { row in
            row.contains { $0.character == trimmed } || row.first?.consonant.lowercased() == lowered
        }
    }

    // MARK: - Formatting for the model

    static func describe(_ entries: [Entry]) -> String {
        entries.map { entry in
            var line = "\(entry.amharic) (\(entry.transliteration)) - \(entry.english)"
            if let note = entry.note { line += " [note: \(note)]" }
            return line
        }.joined(separator: "\n")
    }

    static func describe(_ patterns: [Pattern]) -> String {
        patterns.map { pattern in
            let examples = pattern.examples.prefix(2)
                .map { "  \($0.amharic) (\($0.transliteration)) - \($0.english)" }
                .joined(separator: "\n")
            return "\(pattern.description)\nStructure: \(pattern.structure)\nExamples:\n\(examples)"
        }.joined(separator: "\n\n")
    }

    static func describe(_ row: [FidelCharacter]) -> String {
        row.sorted { $0.vowelOrder < $1.vowelOrder }
            .map { "\($0.vowelOrder). \($0.character) (\($0.romanization))" }
            .joined(separator: "\n")
    }

    // MARK: - Matching

    static func normalize(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: #"[^\p{L}\p{M}\p{N}' ]+"#, with: " ", options: .regularExpression)
            .split(separator: " ")
            .joined(separator: " ")
    }

    private static func score(_ entry: Entry, needle: String) -> Int {
        let english = normalize(entry.english)
        let englishSenses = english
            .replacingOccurrences(of: #"^(to|the|a|an) "#, with: "", options: .regularExpression)
        let amharic = normalize(entry.amharic)
        let translit = normalize(entry.transliteration)

        if english == needle || englishSenses == needle || amharic == needle || translit == needle { return 4 }
        if (" \(english) ").contains(" \(needle) ") || amharic.contains(needle) { return 3 }
        if (" \(translit) ").contains(" \(needle) ") { return 2 }
        if needle.count >= 4, english.contains(needle) { return 1 }
        return 0
    }
}
