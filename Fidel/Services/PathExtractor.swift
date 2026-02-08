import Foundation
import CoreText
import SwiftUI

/// Extracts vector paths from Unicode characters using CoreText.
/// Used to render Fidel character outlines for tracing practice.
final class PathExtractor {
    static let shared = PathExtractor()

    private var pathCache: [String: Path] = [:]
    private var cgPathCache: [String: CGPath] = [:]

    private init() {}

    /// Extract a SwiftUI Path for the given character, normalized to fit within `size`.
    func extractPath(for character: String, size: CGSize) -> Path {
        let key = "\(character)-\(Int(size.width))x\(Int(size.height))"
        if let cached = pathCache[key] {
            return cached
        }
        let cgPath = extractCGPath(for: character, size: size)
        let path = Path(cgPath)
        pathCache[key] = path
        return path
    }

    /// Extract a CGPath for the given character, normalized to fit within `size`.
    func extractCGPath(for character: String, size: CGSize) -> CGPath {
        let key = "\(character)-\(Int(size.width))x\(Int(size.height))"
        if let cached = cgPathCache[key] {
            return cached
        }

        let fontSize: CGFloat = 256

        // Use bundled Noto Sans Ethiopic — a sans-serif with uniform stroke width
        // and clean outlines, much better for tracing than the system Kefa (slab-serif).
        let ctFont = CTFontCreateWithName("NotoSansEthiopic-Regular" as CFString, fontSize, nil)

        // Get glyph for the character
        var chars = Array(character.utf16)
        var glyphs = [CGGlyph](repeating: 0, count: chars.count)
        guard CTFontGetGlyphsForCharacters(ctFont, &chars, &glyphs, chars.count),
              glyphs[0] != 0 else {
            let empty = CGMutablePath()
            cgPathCache[key] = empty
            return empty
        }

        guard let rawPath = CTFontCreatePathForGlyph(ctFont, glyphs[0], nil) else {
            let empty = CGMutablePath()
            cgPathCache[key] = empty
            return empty
        }

        // Normalize the path to fit within the target size with padding
        let padding: CGFloat = 10
        let targetRect = CGRect(
            x: padding,
            y: padding,
            width: size.width - padding * 2,
            height: size.height - padding * 2
        )

        let boundingBox = rawPath.boundingBox
        guard !boundingBox.isEmpty, boundingBox.width > 0, boundingBox.height > 0 else {
            let empty = CGMutablePath()
            cgPathCache[key] = empty
            return empty
        }

        // Calculate scale to fit the glyph within the target rect (uniform scale)
        let scaleX = targetRect.width / boundingBox.width
        let scaleY = targetRect.height / boundingBox.height
        let scale = min(scaleX, scaleY)

        // Center the scaled glyph in the target rect
        let scaledWidth = boundingBox.width * scale
        let scaledHeight = boundingBox.height * scale
        let centerOffsetX = targetRect.minX + (targetRect.width - scaledWidth) / 2
        let centerOffsetY = targetRect.minY + (targetRect.height - scaledHeight) / 2

        // CoreText glyphs have Y-axis going up (origin at baseline, bottom-left).
        // SwiftUI has Y-axis going down. We flip by scaling Y by -1 and translating.
        var transform = CGAffineTransform.identity
        // Step 1: Move glyph origin to (0,0)
        transform = transform.translatedBy(x: -boundingBox.minX, y: -boundingBox.minY)
        // Step 2: Scale (with Y flip)
        transform = CGAffineTransform(scaleX: scale, y: -scale).concatenating(
            CGAffineTransform(translationX: 0, y: scaledHeight)
        ).concatenating(
            CGAffineTransform(translationX: centerOffsetX, y: centerOffsetY)
        ).concatenating(
            CGAffineTransform(translationX: -boundingBox.minX * scale, y: boundingBox.minY * scale)
        )

        // Simpler approach: translate to origin, scale with Y-flip, then position
        transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: centerOffsetX, y: centerOffsetY + scaledHeight)
        transform = transform.scaledBy(x: scale, y: -scale)
        transform = transform.translatedBy(x: -boundingBox.minX, y: -boundingBox.minY)

        guard let normalizedPath = rawPath.copy(using: &transform) else {
            let empty = CGMutablePath()
            cgPathCache[key] = empty
            return empty
        }

        cgPathCache[key] = normalizedPath
        return normalizedPath
    }
}
