import Foundation
import PencilKit

/// Manages the admin stroke recording session — iterates all 238 Fidel characters,
/// captures PencilKit drawings, normalizes strokes, and persists to JSON.
@Observable
final class StrokeRecorderViewModel {

    // MARK: - State

    var characters: [FidelCharacter] = []
    var currentIndex: Int = 0
    var userDrawing = PKDrawing()
    var recordedIds: Set<String> = []

    let canvasSize: CGFloat = 320

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

    var hasData: Bool {
        guard let char = currentCharacter else { return false }
        return recordedIds.contains(char.id)
    }

    // MARK: - Actions

    func saveAndNext() {
        guard let character = currentCharacter else { return }
        guard !userDrawing.strokes.isEmpty else { return }

        let size = CGSize(width: canvasSize, height: canvasSize)
        let strokes = repository.normalizeStrokes(from: userDrawing, canvasSize: size)
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

    // MARK: - Export

    var exportURL: URL {
        repository.exportURL()
    }
}
