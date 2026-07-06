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
        XCTAssertEqual(TracingSessionViewModel().canvasSize, TracingLayout.canvasSize)
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

    func testTracingSessionViewModelUpdatesCanvasGeometryForAdaptiveLayout() {
        let viewModel = TracingSessionViewModel()

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

    func testAudioAssetKeyMatchesPhraseContent() {
        let asset = AudioAsset(
            id: "phrase-12",
            contentType: .phrase,
            contentId: "12",
            language: "am-ET",
            provider: "azure",
            voice: "am-ET-AmehaNeural",
            assetRole: "active",
            assetSet: "all-phrases-v1",
            format: "mp3",
            file: "Audio/phrases/azure/am-ET-AmehaNeural/phrase-012-thank-you.mp3",
            englishSlug: "thank-you",
            text: "አመሰግናለሁ",
            sourceTextHash: "abc123"
        )

        XCTAssertEqual(asset.contentKey, AudioContentKey(contentType: .phrase, contentId: "12"))
    }

    func testBundledAudioManifestLoads() {
        XCTAssertTrue(AmharicData.audioAssets.allSatisfy { !$0.id.isEmpty && !$0.file.isEmpty })
    }

    func testBundledAudioManifestFilesExist() {
        let repository = AudioAssetRepository()
        let placeholderIds: Set<String> = ["17", "19", "55"]
        let phraseAssets = AmharicData.audioAssets.filter { $0.contentType == .phrase }

        XCTAssertEqual(phraseAssets.count, 171)
        XCTAssertEqual(Set(AmharicData.audioAssets.map(\.voice)), ["am-ET-AmehaNeural"])
        XCTAssertTrue(AmharicData.audioAssets.allSatisfy { $0.assetRole == "active" })
        XCTAssertTrue(phraseAssets.allSatisfy { $0.assetSet == "all-phrases-v1" })
        XCTAssertTrue(phraseAssets.allSatisfy { !placeholderIds.contains($0.contentId) })
        for asset in phraseAssets {
            XCTAssertTrue(asset.file.contains("/am-ET-AmehaNeural/"), asset.file)
            XCTAssertNotNil(
                asset.file.range(of: #"phrase-\d{3}-[a-z0-9-]+\.mp3$"#, options: .regularExpression),
                asset.file
            )
            XCTAssertTrue(asset.englishSlug.map { asset.file.contains("-\($0).mp3") } ?? false, asset.file)
            XCTAssertNotNil(repository.audioURL(for: asset), "Missing bundled audio file: \(asset.file)")
        }
    }

    func testBundledFidelCharacterAudioIsCompleteWhenPresent() {
        let repository = AudioAssetRepository()
        let fidelAssets = AmharicData.audioAssets.filter { $0.contentType == .fidelCharacter }

        // The manifest only carries fidel rows once their mp3s are generated;
        // when present, the library must cover every character completely.
        XCTAssertTrue(
            fidelAssets.isEmpty || fidelAssets.count == 238,
            "Partial fidel audio library: \(fidelAssets.count) of 238 rows"
        )

        for asset in fidelAssets {
            XCTAssertEqual(asset.assetSet, "fidel-characters-v1")
            XCTAssertTrue(asset.file.hasPrefix("Audio/fidel/azure/"), asset.file)
            XCTAssertNotNil(
                asset.file.range(of: #"fidel-\d{2}-\d-[a-z0-9-]+\.mp3$"#, options: .regularExpression),
                asset.file
            )
            XCTAssertNotNil(repository.audioURL(for: asset), "Missing bundled audio file: \(asset.file)")
        }

        if !fidelAssets.isEmpty {
            let sample = repository.asset(for: .fidelCharacter, contentId: "0-1")
            XCTAssertNotNil(sample, "Expected fidel audio asset for character 0-1")
        }
    }

    func testBundledAudioCatalogIncludesFemaleRowsWithoutMakingThemActive() {
        let repository = AudioAssetRepository()
        let maleAssets = AmharicData.audioCatalog.filter { $0.voice == "am-ET-AmehaNeural" }
        let femaleAssets = AmharicData.audioCatalog.filter { $0.voice == "am-ET-MekdesNeural" }

        XCTAssertGreaterThanOrEqual(AmharicData.audioCatalog.count, 171)
        XCTAssertEqual(maleAssets.count, 171)
        XCTAssertLessThanOrEqual(femaleAssets.count, 171)
        XCTAssertTrue(maleAssets.allSatisfy { $0.assetRole == "active" })
        XCTAssertTrue(femaleAssets.allSatisfy { $0.assetRole == "alternate" })
        XCTAssertTrue(femaleAssets.allSatisfy { $0.file.contains("/am-ET-MekdesNeural/") })
        for asset in AmharicData.audioCatalog {
            XCTAssertNotNil(repository.audioURL(for: asset), "Missing bundled catalog audio file: \(asset.file)")
        }
    }

    func testAudioAssetRepositoryFindsPhraseAsset() {
        let asset = AudioAsset(
            id: "phrase-12",
            contentType: .phrase,
            contentId: "12",
            language: "am-ET",
            provider: "azure",
            voice: "am-ET-AmehaNeural",
            assetRole: "active",
            assetSet: "all-phrases-v1",
            format: "mp3",
            file: "Audio/phrases/azure/am-ET-AmehaNeural/phrase-012-thank-you.mp3",
            englishSlug: "thank-you",
            text: "አመሰግናለሁ",
            sourceTextHash: "abc123"
        )
        let repository = AudioAssetRepository(assets: [asset])

        XCTAssertEqual(repository.asset(for: .phrase, contentId: "12"), asset)
        XCTAssertNil(repository.asset(for: .phrase, contentId: "13"))
    }

    func testAudioRepositoryRequiresTenPlayablePhraseAssetsForPronunciationPractice() {
        let nineAssets = makePhraseAudioAssets(count: 9)
        let tenAssets = makePhraseAudioAssets(count: 10)

        XCTAssertFalse(
            AudioAssetRepository(assets: nineAssets, fileExists: { _ in true }).hasPronunciationPracticeContent
        )
        XCTAssertTrue(
            AudioAssetRepository(assets: tenAssets, fileExists: { _ in true }).hasPronunciationPracticeContent
        )
        XCTAssertFalse(
            AudioAssetRepository(assets: tenAssets, fileExists: { _ in false }).hasPronunciationPracticeContent
        )
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

        XCTAssertEqual(AmharicData.vocabulary.count, 1038)

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

    /// Mirrors `AccountChangeSheet.adoptRemote()`'s wipe step
    /// (`Fidel/ContentView.swift`): deletes the three synced progress models
    /// but must leave Selam chat records untouched, since those are
    /// device-local AI tutor conversations unrelated to the account's synced
    /// learning data.
    func testAccountChangeWipeDeletesSyncedModelsButLeavesSelamIntact() throws {
        let container = try makeContainer()
        let context = container.mainContext

        context.insert(UserProgress(ownerUserId: "user-1"))
        context.insert(FlashcardProgress(itemId: "word-1", itemType: "vocabulary", ownerUserId: "user-1"))
        context.insert(CharacterTraceMastery(characterId: "0-1", ownerUserId: "user-1"))
        let conversation = SelamConversation(title: "Greetings")
        context.insert(conversation)
        context.insert(SelamMessage(content: "Selam!", role: .user))
        try context.save()

        try context.delete(model: UserProgress.self)
        try context.delete(model: FlashcardProgress.self)
        try context.delete(model: CharacterTraceMastery.self)
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<UserProgress>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FlashcardProgress>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CharacterTraceMastery>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<SelamConversation>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<SelamMessage>()), 1)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            UserProgress.self,
            FlashcardProgress.self,
            SelamConversation.self,
            SelamMessage.self,
            CharacterTraceMastery.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
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

    private func makePhraseAudioAssets(count: Int) -> [AudioAsset] {
        (1...count).map { id in
            AudioAsset(
                id: "phrase-\(id)",
                contentType: .phrase,
                contentId: "\(id)",
                language: "am-ET",
                provider: "azure",
                voice: "am-ET-AmehaNeural",
                assetRole: "active",
                assetSet: "all-phrases-v1",
                format: "mp3",
                file: "Audio/phrases/azure/am-ET-AmehaNeural/phrase-\(String(format: "%03d", id))-sample.mp3",
                englishSlug: "sample",
                text: "sample",
                sourceTextHash: "hash-\(id)"
            )
        }
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
