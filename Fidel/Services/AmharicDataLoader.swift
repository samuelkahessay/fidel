import Foundation

/// Loads Amharic content data from bundled JSON resources.
/// Uses lazy static properties so each file is decoded only once, on first access.
enum AmharicDataLoader {

    // MARK: - Public Data

    static let fidelChart: [[FidelCharacter]] = {
        let flat: [FidelCharacter] = load("fidel_chart")
        let grouped = Dictionary(grouping: flat) { $0.rowIndex }
        return grouped.keys.sorted().map { key in
            grouped[key]!.sorted { $0.vowelOrder < $1.vowelOrder }
        }
    }()

    static let patterns: [Pattern] = load("patterns")
    static let conversations: [Conversation] = load("conversations")
    static let phrases: [Phrase] = load("phrases")
    static let vocabulary: [VocabularyWord] = load("vocabulary")
    static let culturalNotes: [CulturalNote] = load("cultural_notes")
    static let audioAssets: [AudioAsset] = load("audio_manifest")
    static let audioCatalog: [AudioAsset] = load("audio_catalog")

    static let numericData: NumericReferenceData = load("numbers")

    static var numbers: [AmharicNumber] { numericData.numbers }
    static var ethiopianMonths: [EthiopianMonth] { numericData.months }
    static var ordinalNumbers: [OrdinalNumber] { numericData.ordinals }
    static var fractions: [AmharicFraction] { numericData.fractions }

    // MARK: - Generic Loader

    private static func load<T: Decodable>(_ resource: String) -> T {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "json") else {
            fatalError("Missing bundled resource: \(resource).json")
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            fatalError("Failed to decode \(resource).json: \(error)")
        }
    }
}
