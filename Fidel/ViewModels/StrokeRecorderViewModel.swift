import Foundation
import PencilKit
import CoreGraphics

#if DEBUG
/// Manages the admin stroke recording session — iterates all 238 Fidel characters,
/// captures PencilKit drawings, normalizes strokes, and persists to JSON.
@MainActor
@Observable
final class StrokeRecorderViewModel {

    // MARK: - State

    var characters: [FidelCharacter] = []
    var currentIndex: Int = 0
    var userDrawing = PKDrawing() {
        didSet { updateCoverage() }
    }
    var recordedIds: Set<String> = []
    var penWidth: CGFloat = 26 {
        didSet { updateCoverage() }
    }
    var fillCoverage: Double = 0

    var canvasSize: CGFloat = 320 {
        didSet { updateCoverage() }
    }
    /// Mask line width for the glyph-reveal overlay and coverage calculation.
    /// Scales from pen width so widening the brush also increases fill coverage.
    var maskLineWidth: CGFloat {
        StrokeMaskConfig.maskWidth(penWidth: penWidth, canvasWidth: canvasSize)
    }
    /// Scale of the reference glyph relative to the canvas (0…1).
    let glyphScale: CGFloat = 0.58

    private let repository = StrokeDataRepository.shared

    // MARK: - Setup

    func load() {
        characters = AmharicData.fidelChart.flatMap { $0 }
        recordedIds = repository.recordedCharacterIds()
        // Resume at the first unrecorded character
        if let firstUnrecorded = characters.firstIndex(where: { !recordedIds.contains($0.id) }) {
            currentIndex = firstUnrecorded
        }
    }

    // MARK: - Current Character

    var currentCharacter: FidelCharacter? {
        guard currentIndex < characters.count else { return nil }
        return characters[currentIndex]
    }

    var totalCount: Int { characters.count }

    var strokeCount: Int { userDrawing.strokes.count }

    /// Point counts per stroke for the data info display.
    var strokePointCounts: [Int] {
        userDrawing.strokes.map { stroke in
            Array(stroke.path.interpolatedPoints(by: .distance(3))).count
        }
    }

    var hasData: Bool {
        guard let char = currentCharacter else { return false }
        return recordedIds.contains(char.id)
    }

    // MARK: - Actions

    func saveAndNext() {
        guard let character = currentCharacter else { return }
        guard !userDrawing.strokes.isEmpty else { return }

        let size = CGSize(width: canvasSize, height: canvasSize)
        let strokes = repository.normalizeStrokes(from: userDrawing, canvasSize: size, penWidth: penWidth)
        let data = CharacterStrokeData(
            characterId: character.id,
            character: character.character,
            strokes: strokes
        )
        repository.saveCharacterStrokes(data)
        recordedIds.insert(character.id)
        advance()
    }

    func skip() {
        advance()
    }

    func clearCanvas() {
        userDrawing = PKDrawing()
    }

    func undoLastStroke() {
        guard !userDrawing.strokes.isEmpty else { return }
        let remaining = Array(userDrawing.strokes.dropLast())
        userDrawing = PKDrawing(strokes: remaining)
    }

    // MARK: - Navigation

    private func advance() {
        // Find the next unrecorded character, wrapping around if needed
        let start = currentIndex + 1
        for i in 0..<characters.count {
            let idx = (start + i) % characters.count
            if !recordedIds.contains(characters[idx].id) {
                currentIndex = idx
                userDrawing = PKDrawing()
                return
            }
        }
        // All recorded — just move to next sequentially
        currentIndex = (currentIndex + 1) % max(characters.count, 1)
        userDrawing = PKDrawing()
    }

    func jumpTo(index: Int) {
        guard index >= 0, index < characters.count else { return }
        currentIndex = index
        userDrawing = PKDrawing()
    }

    // MARK: - Coverage

    private func updateCoverage() {
        guard let character = currentCharacter, !userDrawing.strokes.isEmpty else {
            fillCoverage = 0
            return
        }

        let size = max(Int(canvasSize), 1)
        let glyphDim = canvasSize * glyphScale
        let glyphOffset = (canvasSize - glyphDim) / 2
        let smallPath = PathExtractor.shared.extractCGPath(
            for: character.character,
            size: CGSize(width: glyphDim, height: glyphDim)
        )
        var offsetTransform = CGAffineTransform(translationX: glyphOffset, y: glyphOffset)
        let cgPath = smallPath.copy(using: &offsetTransform) ?? smallPath

        let colorSpace = CGColorSpaceCreateDeviceGray()

        // Render filled glyph (scaled down and centered)
        guard let glyphCtx = CGContext(
            data: nil, width: size, height: size,
            bitsPerComponent: 8, bytesPerRow: size,
            space: colorSpace, bitmapInfo: 0
        ) else { return }
        glyphCtx.setFillColor(gray: 1, alpha: 1)
        glyphCtx.addPath(cgPath)
        glyphCtx.fillPath()

        // Render stroke mask (same line width as visual overlay)
        guard let maskCtx = CGContext(
            data: nil, width: size, height: size,
            bitsPerComponent: 8, bytesPerRow: size,
            space: colorSpace, bitmapInfo: 0
        ) else { return }
        maskCtx.setStrokeColor(gray: 1, alpha: 1)
        maskCtx.setLineWidth(maskLineWidth)
        maskCtx.setLineCap(.round)
        maskCtx.setLineJoin(.round)

        for pkStroke in userDrawing.strokes {
            let path = pkStroke.path
            guard path.count > 0 else { continue }
            maskCtx.move(to: path.interpolatedLocation(at: 0))
            var dist: CGFloat = 1.0
            while dist < CGFloat(path.count - 1) {
                maskCtx.addLine(to: path.interpolatedLocation(at: dist))
                dist += 1.0
            }
            maskCtx.addLine(to: path.interpolatedLocation(at: CGFloat(path.count - 1)))
        }
        maskCtx.strokePath()

        // Count pixel overlap
        guard let glyphData = glyphCtx.data, let maskData = maskCtx.data else { return }
        let glyphPixels = glyphData.assumingMemoryBound(to: UInt8.self)
        let maskPixels = maskData.assumingMemoryBound(to: UInt8.self)

        var glyphCount = 0
        var coveredCount = 0
        let totalPixels = size * size

        for i in 0..<totalPixels {
            if glyphPixels[i] > 0 {
                glyphCount += 1
                if maskPixels[i] > 0 {
                    coveredCount += 1
                }
            }
        }

        fillCoverage = glyphCount > 0 ? Double(coveredCount) / Double(glyphCount) : 0
    }

    // MARK: - Export

    var exportURL: URL {
        repository.exportURL()
    }
}
#endif
