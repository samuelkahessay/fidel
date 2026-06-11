import Foundation
import PencilKit
import SwiftUI
import UIKit

enum TracingLayout {
    static let canvasSize = CGSize(width: 300, height: 300)
    static let drawingGuideSize = canvasSize
    static let reviewThumbnailSize = CGSize(width: 130, height: 130)
}

enum TracingDrawingRenderer {
    static func thumbnail(from drawing: PKDrawing, sourceCanvasSize: CGSize, outputSize: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(size: outputSize, format: format)
        return renderer.image { _ in
            let sourceImage = drawing.image(
                from: CGRect(origin: .zero, size: sourceCanvasSize),
                scale: 1
            )
            sourceImage.draw(in: CGRect(origin: .zero, size: outputSize))
        }
    }
}

/// Which characters a tracing session covers.
enum TraceSessionPlan {
    /// A mixed practice session composed from mastery state: characters due
    /// for promotion plus new characters in curriculum order.
    case standard
    /// A single character, launched from the Fidel chart.
    case single(FidelCharacter)
}

/// Drives a guided tracing session: which character is up, what level it is
/// practiced at, scoring, XP, and persistence.
@MainActor
@Observable
final class TracingSessionViewModel {

    enum ItemPhase: Equatable {
        /// Stroke-order demo playback before the first trace of a character.
        case watching
        /// Guided stroke-by-stroke tracing (levels 1-2, or level-3 assist).
        case tracing
        /// Level 3: freehand writing from memory, checked by shape evaluation.
        case memoryDrawing
        /// Brief auto-advancing success state after completing a character.
        case celebrating
    }

    struct SessionItem {
        let character: FidelCharacter
        /// Mastery level being practiced (1 = full guide, 2 = faint, 3 = memory).
        let level: Int
    }

    /// The glyph occupied 58% of the canvas during admin stroke recording.
    static let recordingGlyphScale: Double = 0.58

    static let standardSessionSize = 8
    static let maxPromotionItems = 3

    // MARK: - Published state

    var items: [SessionItem] = []
    var currentIndex = 0
    var itemPhase: ItemPhase = .watching
    let engine = TraceEngine()
    var canvasSize = TracingLayout.canvasSize
    var showCompletion = false
    var completedCount = 0
    var skippedCount = 0
    var sessionXP = 0
    var lastStats: TraceEngine.TraceAttemptStats?

    // Level 3 (write from memory) state.
    var userDrawing = PKDrawing()
    var memoryRetryReason: DrawingRetryReason?
    var usedGuideAssist = false

    // MARK: - Dependencies

    private var progressRepository: ProgressRepositoryProtocol?
    private let evaluator = DrawingEvaluator.shared
    private var watchedCharacterIds: Set<String> = []
    private let strokeHaptic = UIImpactFeedbackGenerator(style: .light)
    private let missHaptic = UIImpactFeedbackGenerator(style: .soft)
    private let successHaptic = UINotificationFeedbackGenerator()

    // MARK: - Scoring

    /// Guided trace score: clean tracing is 100, each miss costs 10, each
    /// auto-played hint costs 15, floored at 50.
    static func guidedScore(misses: Int, hintsAutoPlayed: Int) -> Int {
        max(50, 100 - 10 * misses - 15 * hintsAutoPlayed)
    }

    /// Memory level score derived from the shape evaluator's harmonic-mean
    /// score; using the guide assist caps the score below promotion.
    static func memoryScore(evaluationScore: Double, usedAssist: Bool) -> Int {
        let base = min(100, max(50, Int((evaluationScore * 100).rounded()) + 25))
        return usedAssist ? min(base, 69) : base
    }

    // MARK: - Configuration

    func configure(progressRepository: ProgressRepositoryProtocol) {
        self.progressRepository = progressRepository
        engine.onEvent = { [weak self] event in
            self?.handleEngineEvent(event)
        }
    }

    func startSession(plan: TraceSessionPlan = .standard) {
        switch plan {
        case .standard:
            items = Self.composeStandardSession(
                mastery: progressRepository?.allTraceMastery() ?? []
            )
        case .single(let character):
            let level = progressRepository?.getTraceMastery(for: character.id)?.level ?? 0
            items = [SessionItem(character: character, level: min(level + 1, 3))]
        }

        currentIndex = 0
        completedCount = 0
        skippedCount = 0
        sessionXP = 0
        showCompletion = false
        watchedCharacterIds = []
        prepareCurrentItem()
    }

    /// Up to 3 characters due for promotion (oldest practice first, served at
    /// their next level) interleaved with new characters in curriculum order:
    /// first-order forms across all rows, then remaining vowel orders row-major.
    static func composeStandardSession(mastery: [CharacterTraceMastery]) -> [SessionItem] {
        let masteryById = Dictionary(uniqueKeysWithValues: mastery.map { ($0.characterId, $0) })

        let dueItems = mastery
            .filter { $0.level >= 1 && $0.level < 3 }
            .sorted { ($0.lastPracticedAt ?? .distantPast) < ($1.lastPracticedAt ?? .distantPast) }
            .prefix(maxPromotionItems)
            .compactMap { record -> SessionItem? in
                guard let character = characterById(record.characterId) else { return nil }
                return SessionItem(character: character, level: record.level + 1)
            }

        let newItems = curriculumOrderedCharacters()
            .filter { (masteryById[$0.id]?.level ?? 0) == 0 }
            .prefix(max(0, standardSessionSize - dueItems.count))
            .map { SessionItem(character: $0, level: 1) }

        // Interleave: lead with a fresh character, then alternate due reviews in.
        var result: [SessionItem] = []
        var newQueue = Array(newItems)
        var dueQueue = Array(dueItems)
        while result.count < standardSessionSize, !newQueue.isEmpty || !dueQueue.isEmpty {
            if !newQueue.isEmpty {
                result.append(newQueue.removeFirst())
            }
            if result.count < standardSessionSize, !dueQueue.isEmpty {
                result.append(dueQueue.removeFirst())
            }
        }
        return result
    }

    private static func characterById(_ id: String) -> FidelCharacter? {
        AmharicData.fidelChart.lazy.flatMap { $0 }.first { $0.id == id }
    }

    private static func curriculumOrderedCharacters() -> [FidelCharacter] {
        let chart = AmharicData.fidelChart
        let firstOrder = chart.compactMap { row in row.first(where: { $0.vowelOrder == 1 }) }
        let remaining = chart.flatMap { row in row.filter { $0.vowelOrder != 1 } }
        return (firstOrder + remaining).filter {
            StrokeDataRepository.shared.hasStrokeData(for: $0.id)
        }
    }

    // MARK: - Current item

    var currentItem: SessionItem? {
        guard currentIndex < items.count else { return nil }
        return items[currentIndex]
    }

    var progress: String {
        "\(min(currentIndex + 1, items.count)) of \(items.count)"
    }

    var progressFraction: Double {
        guard !items.isEmpty else { return 0 }
        return Double(currentIndex + 1) / Double(items.count)
    }

    var hasMemoryDrawing: Bool {
        !userDrawing.strokes.isEmpty
    }

    var memoryRetryMessage: String {
        switch memoryRetryReason {
        case .blankDrawing:
            return "Write the character from memory, then check."
        case .tooLittleCoverage:
            return "Almost - try writing the full character."
        case .tooMuchOutsideGuide:
            return "Close! Keep your writing a bit more compact."
        case nil:
            return "Try writing the character again."
        }
    }

    // MARK: - Phase transitions

    func finishWatching() {
        guard let item = currentItem else { return }
        watchedCharacterIds.insert(item.character.id)
        configureEngine(for: item)
        itemPhase = .tracing
    }

    func rewatchDemo() {
        itemPhase = .watching
    }

    func skipCharacter() {
        skippedCount += 1
        advanceToNextItem()
    }

    func advanceAfterCelebration() {
        advanceToNextItem()
    }

    // MARK: - Level 3 (memory)

    func evaluateMemoryDrawing() {
        guard let item = currentItem else { return }

        let referencePath = PathExtractor.shared.extractCGPath(
            for: item.character.character,
            size: canvasSize
        )
        let result = evaluator.evaluate(
            drawing: userDrawing,
            referencePath: referencePath,
            canvasSize: canvasSize
        )

        switch result {
        case .passedForReview(let evaluation):
            memoryRetryReason = nil
            completeCharacter(score: Self.memoryScore(
                evaluationScore: evaluation.score,
                usedAssist: usedGuideAssist
            ), misses: 0)
        case .needsRetry(let evaluation):
            memoryRetryReason = evaluation.retryReason ?? .tooLittleCoverage
            missHaptic.impactOccurred()
        }
    }

    func clearMemoryDrawing() {
        userDrawing = PKDrawing()
        memoryRetryReason = nil
    }

    /// Drops a memory-level attempt back to a guided trace. Completing with
    /// the assist caps the score below promotion, so mastery stays honest.
    func showGuideAssist() {
        guard let item = currentItem, itemPhase == .memoryDrawing else { return }
        usedGuideAssist = true
        memoryRetryReason = nil
        userDrawing = PKDrawing()
        configureEngine(for: item)
        itemPhase = .tracing
    }

    func updateCanvasSize(_ newSize: CGSize) {
        guard newSize.width > 0, newSize.height > 0 else { return }
        guard abs(canvasSize.width - newSize.width) > 1 || abs(canvasSize.height - newSize.height) > 1 else { return }
        canvasSize = newSize
        userDrawing = PKDrawing()
        // Geometry changed under an in-flight trace: rebuild the engine's
        // stroke space and restart the current character's trace.
        if itemPhase == .tracing, let item = currentItem {
            configureEngine(for: item)
        }
    }

    // MARK: - Engine events

    private func handleEngineEvent(_ event: TraceEngine.EngineEvent) {
        switch event {
        case .strokeStarted:
            strokeHaptic.impactOccurred(intensity: 0.55)

        case .strokeCompleted:
            strokeHaptic.impactOccurred()

        case .miss:
            missHaptic.impactOccurred()
            Task { [missHaptic] in
                try? await Task.sleep(for: .milliseconds(60))
                missHaptic.impactOccurred(intensity: 0.7)
            }

        case .hintAutoPlayed:
            break

        case .characterCompleted(let stats):
            lastStats = stats
            let base = Self.guidedScore(misses: stats.misses, hintsAutoPlayed: stats.hintsAutoPlayed)
            completeCharacter(
                score: usedGuideAssist ? min(base, 69) : base,
                misses: stats.misses
            )
        }
    }

    // MARK: - Private

    private func completeCharacter(score: Int, misses: Int) {
        guard let item = currentItem else { return }

        completedCount += 1
        successHaptic.notificationOccurred(.success)

        if let outcome = progressRepository?.recordTraceCompletion(
            characterId: item.character.id,
            completedLevel: item.level,
            score: score,
            misses: misses
        ) {
            sessionXP += outcome.xpAwarded
        }

        itemPhase = .celebrating
    }

    private func prepareCurrentItem() {
        guard let item = currentItem else {
            showCompletion = true
            return
        }

        userDrawing = PKDrawing()
        memoryRetryReason = nil
        usedGuideAssist = false

        if item.level >= 3 {
            itemPhase = .memoryDrawing
        } else if watchedCharacterIds.contains(item.character.id) || item.level >= 2 {
            configureEngine(for: item)
            itemPhase = .tracing
        } else {
            itemPhase = .watching
        }
    }

    private func configureEngine(for item: SessionItem) {
        let strokeData = StrokeDataRepository.shared.getStrokeData(for: item.character.id)
        engine.configure(
            strokes: strokeData?.strokes ?? [],
            canvasSize: canvasSize,
            glyphStrokeWidth: PathExtractor.shared.glyphStrokeWidth(for: item.character.character, size: canvasSize),
            recordingGlyphScale: Self.recordingGlyphScale,
            tuning: item.level >= 2 && !usedGuideAssist ? .level2() : .standard
        )
    }

    private func advanceToNextItem() {
        if currentIndex < items.count - 1 {
            currentIndex += 1
            prepareCurrentItem()
        } else {
            currentIndex = items.count
            showCompletion = true
        }
    }
}
