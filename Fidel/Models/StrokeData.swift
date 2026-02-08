import Foundation

/// A single point in normalized coordinates (0...1).
struct StrokePoint: Codable {
    let x: Double
    let y: Double
}

/// One continuous pen-down to pen-up stroke.
struct RecordedStroke: Codable {
    let points: [StrokePoint]
}

/// All strokes for a single Fidel character.
struct CharacterStrokeData: Codable {
    let characterId: String    // FidelCharacter.id e.g. "h-1"
    let character: String      // e.g. "ሀ" (human-readable in JSON)
    let strokes: [RecordedStroke]
}

/// Top-level container for all recorded stroke data.
struct StrokeDataStore: Codable {
    var characters: [String: CharacterStrokeData]
}
