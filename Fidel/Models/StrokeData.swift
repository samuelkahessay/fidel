import Foundation

/// A single point in normalized coordinates (0...1).
struct StrokePoint: Codable {
    let x: Double
    let y: Double
}

/// One continuous pen-down to pen-up stroke.
struct RecordedStroke: Codable {
    let points: [StrokePoint]
    let penWidth: Double  // normalized (0...1) relative to canvas size
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

// MARK: - Mask Width Configuration

/// Shared constants for the glyph-reveal mask width calculation.
/// Used by both the stroke recorder (admin) and animation playback.
enum StrokeMaskConfig {
    static let revealWidthMultiplier: CGFloat = 4.0
    static let minRevealWidthRatio: CGFloat = 0.30
    static let maxRevealWidthRatio: CGFloat = 0.55
    static let minEnvelopeWidthRatio: CGFloat = 0.06
    static let maxEnvelopeWidthRatio: CGFloat = 0.45
    static let envelopePenMultiplier: CGFloat = 3.0
    static let envelopeGlyphMultiplier: CGFloat = 3.0

    /// Computes mask line width from a normalized pen width and canvas dimension.
    static func maskWidth(penWidth: CGFloat, canvasWidth: CGFloat) -> CGFloat {
        let scaled = penWidth * canvasWidth * revealWidthMultiplier
        let minW = canvasWidth * minRevealWidthRatio
        let maxW = canvasWidth * maxRevealWidthRatio
        return min(max(scaled, minW), maxW)
    }

    /// Computes the envelope width for per-stroke clipping.
    /// Envelope width is intentionally independent from reveal mask width so
    /// ownership stays close to glyph geometry instead of inheriting a wide brush.
    static func envelopeWidth(penWidth: CGFloat, canvasWidth: CGFloat, glyphStrokeWidth: CGFloat) -> CGFloat {
        let penBased = penWidth * envelopePenMultiplier
        let glyphBased = glyphStrokeWidth > 0 ? glyphStrokeWidth * envelopeGlyphMultiplier : 0
        let base = max(penBased, glyphBased)
        let minW = canvasWidth * minEnvelopeWidthRatio
        let maxW = canvasWidth * maxEnvelopeWidthRatio
        return min(max(base, minW), maxW)
    }

}
