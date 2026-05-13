import Foundation

/// Facade over bundled JSON data.
/// Raw content lives in Fidel/Data/*.json; derived content (lessons, categories) is computed here.
struct AmharicData {

    // MARK: - Raw Data (loaded from JSON)

    static let fidelChart: [[FidelCharacter]] = AmharicDataLoader.fidelChart
    static let patterns: [Pattern] = AmharicDataLoader.patterns
    static let conversations: [Conversation] = AmharicDataLoader.conversations
    static let phrases: [Phrase] = AmharicDataLoader.phrases
    static let vocabulary: [VocabularyWord] = AmharicDataLoader.vocabulary
    static let culturalNotes: [CulturalNote] = AmharicDataLoader.culturalNotes
    static let numbers: [AmharicNumber] = AmharicDataLoader.numbers
    static let ethiopianMonths: [EthiopianMonth] = AmharicDataLoader.ethiopianMonths
    static let ordinalNumbers: [OrdinalNumber] = AmharicDataLoader.ordinalNumbers
    static let fractions: [AmharicFraction] = AmharicDataLoader.fractions
    static let audioAssets: [AudioAsset] = AmharicDataLoader.audioAssets
    static let audioCatalog: [AudioAsset] = AmharicDataLoader.audioCatalog

    // MARK: - Derived Data (computed in Swift)

    static var vocabularyCategories: [String] {
        Array(Set(vocabulary.map { $0.category })).sorted()
    }

    static func vocabularyByCategory(_ category: String) -> [VocabularyWord] {
        vocabulary.filter { $0.category == category }
    }

    static let lessons: [Lesson] = [
        Lesson(
            id: 1,
            title: "Greetings & Introductions",
            description: "Learn basic greetings and how to introduce yourself",
            patterns: patterns.filter { $0.unit == 1 },
            vocabulary: vocabulary.filter { ["Family", "Common Adjectives"].contains($0.category) },
            phrases: Array(phrases.prefix(15))
        ),
        Lesson(
            id: 2,
            title: "Possessives & Family",
            description: "Talk about your family and possessions",
            patterns: patterns.filter { $0.unit == 2 },
            vocabulary: vocabulary.filter { $0.category == "Family" },
            phrases: phrases.filter { $0.id >= 16 && $0.id <= 25 }
        ),
        Lesson(
            id: 3,
            title: "Questions & Directions",
            description: "Ask questions and find your way around",
            patterns: patterns.filter { $0.unit == 3 },
            vocabulary: vocabulary.filter { ["Directions", "Places"].contains($0.category) },
            phrases: phrases.filter { $0.id >= 20 && $0.id <= 30 }
        ),
        Lesson(
            id: 4,
            title: "Food & Shopping",
            description: "Order food, shop at markets, and handle money",
            patterns: patterns.filter { $0.unit == 4 || $0.unit == 5 },
            vocabulary: vocabulary.filter { $0.category == "Food & Drink" },
            phrases: phrases.filter { $0.id >= 31 && $0.id <= 40 }
        ),
        Lesson(
            id: 5,
            title: "Making Plans & Time",
            description: "Talk about time, make plans, and schedule activities",
            patterns: patterns.filter { $0.unit == 5 },
            vocabulary: vocabulary.filter { ["Time", "Days"].contains($0.category) },
            phrases: phrases.filter { $0.id >= 41 && $0.id <= 50 }
        ),
        Lesson(
            id: 6,
            title: "Health & Body",
            description: "Describe symptoms, visit the doctor, and discuss health",
            patterns: patterns.filter { $0.unit == 6 || $0.unit == 7 },
            vocabulary: vocabulary.filter { ["Body Parts", "Emotions", "Occupations"].contains($0.category) },
            phrases: phrases.filter { $0.id >= 59 && $0.id <= 65 }
        ),
        Lesson(
            id: 7,
            title: "Travel & Transportation",
            description: "Navigate airports, take taxis, and travel around Ethiopia",
            patterns: patterns.filter { $0.unit == 8 || $0.unit == 9 },
            vocabulary: vocabulary.filter { ["Transportation", "Clothing", "Weather & Nature"].contains($0.category) },
            phrases: phrases.filter { ($0.id >= 51 && $0.id <= 58) || ($0.id >= 81 && $0.id <= 85) }
        ),
        Lesson(
            id: 8,
            title: "Ethiopian Culture & Celebrations",
            description: "Experience holidays, ceremonies, and cultural traditions",
            patterns: patterns.filter { $0.unit == 10 },
            vocabulary: vocabulary.filter { ["Household", "Animals", "Food & Drink"].contains($0.category) },
            phrases: phrases.filter { ($0.id >= 71 && $0.id <= 80) || ($0.id >= 86 && $0.id <= 90) }
        )
    ]
}
