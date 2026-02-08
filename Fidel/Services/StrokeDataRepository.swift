import Foundation
import PencilKit

/// Loads, saves, and queries stroke data for Fidel characters.
/// Checks bundle resource first (production), then documents directory (recording).
final class StrokeDataRepository {
    static let shared = StrokeDataRepository()

    private let fileName = "fidel_stroke_data.json"
    private var store: StrokeDataStore

    private init() {
        store = Self.load(fileName: fileName)
    }

    // MARK: - Load

    private static func load(fileName: String) -> StrokeDataStore {
        // 1. Try documents directory (active recording overrides bundle)
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
        if let data = try? Data(contentsOf: documentsURL),
           let decoded = try? JSONDecoder().decode(StrokeDataStore.self, from: data) {
            return decoded
        }

        // 2. Try bundle resource (shipped with app)
        if let bundleURL = Bundle.main.url(forResource: "fidel_stroke_data", withExtension: "json"),
           let data = try? Data(contentsOf: bundleURL),
           let decoded = try? JSONDecoder().decode(StrokeDataStore.self, from: data) {
            return decoded
        }

        // 3. Empty store
        return StrokeDataStore(characters: [:])
    }

    // MARK: - Query

    func getStrokeData(for characterId: String) -> CharacterStrokeData? {
        store.characters[characterId]
    }

    func recordedCharacterIds() -> Set<String> {
        Set(store.characters.keys)
    }

    func hasStrokeData(for characterId: String) -> Bool {
        store.characters[characterId] != nil
    }

    // MARK: - Save

    func saveCharacterStrokes(_ data: CharacterStrokeData) {
        store.characters[data.characterId] = data
        persist()
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(store) else { return }

        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
        try? data.write(to: documentsURL, options: .atomic)
    }

    // MARK: - Normalize PencilKit Strokes

    func normalizeStrokes(from drawing: PKDrawing, canvasSize: CGSize) -> [RecordedStroke] {
        drawing.strokes.map { stroke in
            let points = stroke.path.interpolatedPoints(by: .distance(3)).map { point in
                StrokePoint(
                    x: Double(point.location.x / canvasSize.width),
                    y: Double(point.location.y / canvasSize.height)
                )
            }
            return RecordedStroke(points: points)
        }
    }

    // MARK: - Export

    func exportURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }
}
