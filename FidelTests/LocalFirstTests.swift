import SwiftData
import SwiftUI
import PencilKit
import UIKit
import XCTest
@testable import Fidel___Learn_Amharic

@MainActor
final class LocalFirstTests: XCTestCase {
    func testProgressRepositoryCreatesLocalDeviceProgress() throws {
        let container = try makeContainer()
        let repository = ProgressRepository(modelContext: container.mainContext)

        let progress = repository.ensureUserProgress()

        XCTAssertEqual(progress.ownerUserId, LocalLearner.userId)
    }

    func testSettingsStorePersistsDailyGoal() {
        let defaults = makeDefaults()
        var store = AppSettingsStore(defaults: defaults)

        store.dailyXPGoal = 120

        XCTAssertEqual(AppSettingsStore(defaults: defaults).dailyXPGoal, 120)
    }

    func testSettingsStoreClampsDailyGoal() {
        let defaults = makeDefaults()
        var store = AppSettingsStore(defaults: defaults)

        store.dailyXPGoal = -5

        XCTAssertEqual(store.dailyXPGoal, 10)
    }

    func testTracingCharacterAlsoCountsAsRecognized() {
        let progress = UserProgress(ownerUserId: LocalLearner.userId)

        progress.traceCharacter("0-1")

        XCTAssertEqual(progress.charactersTraced, ["0-1"])
        XCTAssertEqual(progress.fidelCharactersRecognized, ["0-1"])
    }

    func testDueCardsAreSortedBeforeFutureCards() {
        let now = Date.now
        let oldestDue = FlashcardProgress(itemId: "old", itemType: "vocabulary", ownerUserId: LocalLearner.userId)
        oldestDue.nextReviewDate = now.addingTimeInterval(-120)
        let newestDue = FlashcardProgress(itemId: "new", itemType: "vocabulary", ownerUserId: LocalLearner.userId)
        newestDue.nextReviewDate = now.addingTimeInterval(-30)
        let future = FlashcardProgress(itemId: "future", itemType: "vocabulary", ownerUserId: LocalLearner.userId)
        future.nextReviewDate = now.addingTimeInterval(120)

        let dueCards = FSRSAlgorithm.getDueCards(from: [future, newestDue, oldestDue])

        XCTAssertEqual(dueCards.map(\.itemId), ["old", "new"])
    }

    func testBlankTracingDrawingCannotPass() {
        let referencePath = PathExtractor.shared.extractCGPath(for: "ሀ", size: TracingLayout.canvasSize)

        let result = DrawingEvaluator.shared.evaluate(
            drawing: PKDrawing(),
            referencePath: referencePath,
            canvasSize: TracingLayout.canvasSize
        )

        XCTAssertFalse(result.evaluation.passed)
        XCTAssertEqual(result.evaluation.retryReason, .blankDrawing)
    }

    func testTracingUsesOneCanvasGeometryForGuideAndEvaluation() {
        XCTAssertEqual(TracingViewModel.canvasSize, TracingLayout.canvasSize)
        XCTAssertEqual(TracingLayout.drawingGuideSize, TracingLayout.canvasSize)
    }

    func testAdaptivePracticeCanvasFitsNarrowWidths() {
        let fitted = AdaptivePracticeCanvas<EmptyView>.fittedSize(
            for: 260,
            idealSize: CGSize(width: 300, height: 300)
        )

        XCTAssertEqual(fitted.width, 260)
        XCTAssertEqual(fitted.height, 260)
    }

    func testFidelChartLayoutFitsPhoneWidthWithoutHorizontalScroll() {
        let metrics = FidelChartLayoutMetrics(containerWidth: 402)

        XCTAssertLessThanOrEqual(metrics.totalWidth, 402)
        XCTAssertGreaterThanOrEqual(metrics.cellWidth, 44)
    }

    func testTracingViewModelUpdatesCanvasGeometryForAdaptiveLayout() {
        let viewModel = TracingViewModel()

        viewModel.updateCanvasSize(CGSize(width: 260, height: 260))

        XCTAssertEqual(viewModel.canvasSize, CGSize(width: 260, height: 260))
    }

    func testDrawingThumbnailUsesFullSourceCanvas() {
        let drawing = makeDrawing(points: [
            CGPoint(x: 250, y: 250),
            CGPoint(x: 285, y: 285)
        ])

        let thumbnail = TracingDrawingRenderer.thumbnail(
            from: drawing,
            sourceCanvasSize: TracingLayout.canvasSize,
            outputSize: TracingLayout.reviewThumbnailSize
        )

        XCTAssertTrue(imageContainsVisiblePixel(thumbnail))
    }

    func testBundledStrokeDataIncludesSampledCharacters() {
        for characterId in ["0-1", "12-1", "33-7"] {
            XCTAssertTrue(
                StrokeDataRepository.shared.hasStrokeData(for: characterId),
                "Expected bundled stroke data for \(characterId)"
            )
        }
    }

    func testBundledVocabularyIncludesReviewedImportBatch() {
        let expectedWords: [(category: String, amharic: String, transliteration: String, english: String)] = [
            ("Directions", "ከኋላ", "kahuala", "at the back"),
            ("Places", "ጓሮ", "guaro", "backyard"),
            ("Common Nouns", "ጦር", "tor", "army"),
            ("Body Parts", "የሰውነት አካል", "yasawinat akal", "body parts"),
            ("Food & Drink", "ስኒ", "sini", "coffee cup"),
            ("Directions", "በመጽሃፎቹ መሃል", "bamets'hafochu mahal", "between the books"),
            ("Food & Drink", "አምቦ ውሃ", "ambo wuha", "sparkling water"),
            ("Common Nouns", "መርዝ", "mariz", "poison"),
            ("Occupations", "የቤት እመቤት", "yabet imebet", "homemaker"),
            ("Directions", "በር ጋር", "bar gar", "at the door"),
            ("Directions", "ከሶፋው ኋላ", "kasofaw huala", "behind the sofa"),
            ("Directions", "ጠረጴዛ ላይ", "tarapeza lay", "on the table"),
            ("Directions", "ጠረጴዛ ስር", "tarapeza sir", "under the table"),
            ("Common Nouns", "አዋቂ", "awaki", "adult"),
            ("Common Adjectives", "የተጨናነቀ", "yatachananaka", "crowded"),
            ("Technology", "ኔትዎርክ", "network", "network/service area")
        ]

        XCTAssertEqual(AmharicData.vocabulary.count, 436)

        for expectedWord in expectedWords {
            let word = AmharicData.vocabulary.first { $0.amharic == expectedWord.amharic }

            XCTAssertEqual(word?.category, expectedWord.category, expectedWord.amharic)
            XCTAssertEqual(word?.transliteration, expectedWord.transliteration, expectedWord.amharic)
            XCTAssertEqual(word?.english, expectedWord.english, expectedWord.amharic)
        }
    }

    func testBundledVocabularyHasNoDuplicateAmharicEnglishPairs() {
        let keys = AmharicData.vocabulary.map { word in
            "\(normalizedVocabularyField(word.amharic))|\(normalizedVocabularyField(word.english))"
        }

        XCTAssertEqual(Set(keys).count, keys.count)
    }

    func testRecordedStrokeShapePassesTracingEvaluation() throws {
        let characterId = "0-1"
        let strokeData = try XCTUnwrap(StrokeDataRepository.shared.getStrokeData(for: characterId))
        let drawing = makeDrawing(from: strokeData)
        let referencePath = PathExtractor.shared.extractCGPath(
            for: strokeData.character,
            size: TracingLayout.canvasSize
        )

        let result = DrawingEvaluator.shared.evaluate(
            drawing: drawing,
            referencePath: referencePath,
            canvasSize: TracingLayout.canvasSize
        )

        XCTAssertTrue(
            result.evaluation.passed,
            "Expected recorded stroke drawing to pass, got \(result.evaluation)"
        )
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            UserProgress.self,
            FlashcardProgress.self,
            SelamConversation.self,
            SelamMessage.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "FidelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func normalizedVocabularyField(_ value: String) -> String {
        value
            .precomposedStringWithCanonicalMapping
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func makeDrawing(points: [CGPoint]) -> PKDrawing {
        let strokePoints = points.enumerated().map { index, point in
            PKStrokePoint(
                location: point,
                timeOffset: TimeInterval(index) * 0.05,
                size: CGSize(width: 18, height: 18),
                opacity: 1,
                force: 1,
                azimuth: 0,
                altitude: .pi / 2
            )
        }
        let path = PKStrokePath(controlPoints: strokePoints, creationDate: Date())
        let stroke = PKStroke(ink: PKInk(.marker, color: .systemIndigo), path: path)
        return PKDrawing(strokes: [stroke])
    }

    private func makeDrawing(from data: CharacterStrokeData) -> PKDrawing {
        let recordingGlyphScale = 0.58
        let offset = (1.0 - recordingGlyphScale) / 2.0
        let canvasSize = TracingLayout.canvasSize

        let strokes = data.strokes.map { recordedStroke in
            let strokePoints = recordedStroke.points.enumerated().map { index, point in
                PKStrokePoint(
                    location: CGPoint(
                        x: ((point.x - offset) / recordingGlyphScale) * canvasSize.width,
                        y: ((point.y - offset) / recordingGlyphScale) * canvasSize.height
                    ),
                    timeOffset: TimeInterval(index) * 0.04,
                    size: CGSize(width: 18, height: 18),
                    opacity: 1,
                    force: 1,
                    azimuth: 0,
                    altitude: .pi / 2
                )
            }
            return PKStroke(
                ink: PKInk(.marker, color: .systemIndigo),
                path: PKStrokePath(controlPoints: strokePoints, creationDate: Date())
            )
        }

        return PKDrawing(strokes: strokes)
    }

    private func imageContainsVisiblePixel(_ image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else { return false }
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return false
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 10 }
    }
}
