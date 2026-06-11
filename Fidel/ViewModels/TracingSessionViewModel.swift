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
    /// A mixed practice session composed by the view model.
    case standard
    /// A single character, launched from the Fidel chart.
    case single(FidelCharacter)
}

/// Drives a guided tracing session: which character is up, whether the user is
/// watching the demo or tracing, scoring, XP, and persistence.
@MainActor
@Observable
final class TracingSessionViewModel {

    enum ItemPhase: Equatable {
        /// Stroke-order demo playback before the first trace of a character.
        case watching
        /// Guided stroke-by-stroke tracing.
        case tracing
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

    // MARK: - Dependencies

    private var progressRepository: ProgressRepositoryProtocol?
    private var watchedCharacterIds: Set<String> = []
    private let strokeHaptic = UIImpactFeedbackGenerator(style: .light)
    private let missHaptic = UIImpactFeedbackGenerator(style: .soft)
    private let successHaptic = UINotificationFeedbackGenerator()

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
            let firstOrder = AmharicData.fidelChart
                .compactMap { row in row.first(where: { $0.vowelOrder == 1 }) }
                .filter { StrokeDataRepository.shared.hasStrokeData(for: $0.id) }
            items = Array(firstOrder.shuffled().prefix(8)).map { SessionItem(character: $0, level: 1) }
        case .single(let character):
            items = [SessionItem(character: character, level: 1)]
        }

        currentIndex = 0
        completedCount = 0
        skippedCount = 0
        sessionXP = 0
        showCompletion = false
        watchedCharacterIds = []
        prepareCurrentItem()
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

    func updateCanvasSize(_ newSize: CGSize) {
        guard newSize.width > 0, newSize.height > 0 else { return }
        guard abs(canvasSize.width - newSize.width) > 1 || abs(canvasSize.height - newSize.height) > 1 else { return }
        canvasSize = newSize
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
            completedCount += 1
            successHaptic.notificationOccurred(.success)
            if let item = currentItem {
                progressRepository?.traceCharacter(item.character.id)
                sessionXP += 5
            }
            itemPhase = .celebrating
        }
    }

    // MARK: - Private

    private func prepareCurrentItem() {
        guard let item = currentItem else {
            showCompletion = true
            return
        }

        if watchedCharacterIds.contains(item.character.id) {
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
            tuning: item.level >= 2 ? .level2() : .standard
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
