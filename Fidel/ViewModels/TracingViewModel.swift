import Foundation
import SwiftUI
import PencilKit
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

/// Manages state for a character tracing practice session.
/// Presents 10 random first-order (ግዕዝ) Fidel characters for the user to trace.
@MainActor
@Observable
final class TracingViewModel {

    enum Phase {
        case watching
        case drawing
        case reviewing
    }

    // MARK: - Published State

    var characters: [FidelCharacter] = []
    var currentIndex: Int = 0
    var phase: Phase = .watching
    var userDrawing = PKDrawing()
    var lastScore: Double = 0
    var showCompletion = false
    var completedCount = 0
    var skippedCount = 0
    var needsRetry = false
    var lastEvaluation = DrawingEvaluation(score: 0, coverage: 0, precision: 0, retryReason: nil)

    // MARK: - Dependencies

    private var progressRepository: ProgressRepositoryProtocol?
    private let pathExtractor = PathExtractor.shared
    private let evaluator = DrawingEvaluator.shared
    static let canvasSize = TracingLayout.canvasSize
    var canvasSize = TracingLayout.canvasSize

    // MARK: - Configuration

    func configure(progressRepository: ProgressRepositoryProtocol) {
        self.progressRepository = progressRepository
    }

    // MARK: - Session Management

    func startSession() {
        // Pick first-order characters (vowelOrder == 1) from all consonant rows
        let firstOrder = AmharicData.fidelChart.compactMap { row in
            row.first(where: { $0.vowelOrder == 1 })
        }
        characters = Array(firstOrder.shuffled().prefix(10))
        currentIndex = 0
        phase = .watching
        userDrawing = PKDrawing()
        lastScore = 0
        lastEvaluation = DrawingEvaluation(score: 0, coverage: 0, precision: 0, retryReason: nil)
        showCompletion = false
        completedCount = 0
        skippedCount = 0
        needsRetry = false
    }

    // MARK: - Current Character

    var currentCharacter: FidelCharacter? {
        guard currentIndex < characters.count else { return nil }
        return characters[currentIndex]
    }

    var progress: String {
        "\(currentIndex + 1) of \(characters.count)"
    }

    var progressFraction: Double {
        guard !characters.isEmpty else { return 0 }
        return Double(currentIndex + 1) / Double(characters.count)
    }

    var hasDrawing: Bool {
        !userDrawing.strokes.isEmpty
    }

    var retryMessage: String {
        switch lastEvaluation.retryReason {
        case .blankDrawing:
            return "Draw the character before checking."
        case .tooLittleCoverage:
            return "Cover more of the guide before checking."
        case .tooMuchOutsideGuide:
            return "Stay closer to the guide."
        case nil:
            return "Try to follow the guide more closely."
        }
    }

    var reviewMessage: String {
        let percent = Int((lastEvaluation.score * 100).rounded())
        return "Guide match \(percent)%"
    }

    // MARK: - Phase Transitions

    func finishWatching() {
        phase = .drawing
        userDrawing = PKDrawing()
        needsRetry = false
    }

    func evaluateDrawing() {
        guard let character = currentCharacter else { return }

        let referencePath = pathExtractor.extractCGPath(for: character.character, size: canvasSize)
        let result = evaluator.evaluate(drawing: userDrawing, referencePath: referencePath, canvasSize: canvasSize)
        lastEvaluation = result.evaluation

        switch result {
        case .passedForReview(let evaluation):
            lastScore = evaluation.score
            needsRetry = false
            phase = .reviewing
        case .needsRetry(let evaluation):
            lastScore = evaluation.score
            needsRetry = true
        }
    }

    func submitRating(stars: Int) {
        guard let character = currentCharacter else { return }

        completedCount += 1
        progressRepository?.traceCharacter(character.id)
        nextCharacter()
    }

    func retryDrawing() {
        userDrawing = PKDrawing()
        needsRetry = false
        phase = .drawing
    }

    func skipCharacter() {
        skippedCount += 1
        nextCharacter()
    }

    func clearCanvas() {
        userDrawing = PKDrawing()
    }

    func updateCanvasSize(_ newSize: CGSize) {
        guard newSize.width > 0, newSize.height > 0 else { return }
        if abs(canvasSize.width - newSize.width) > 1 || abs(canvasSize.height - newSize.height) > 1 {
            canvasSize = newSize
            userDrawing = PKDrawing()
            needsRetry = false
        }
    }

    // MARK: - Navigation

    private func nextCharacter() {
        if currentIndex < characters.count - 1 {
            currentIndex += 1
            phase = .watching
            userDrawing = PKDrawing()
            lastScore = 0
            lastEvaluation = DrawingEvaluation(score: 0, coverage: 0, precision: 0, retryReason: nil)
            needsRetry = false
        } else {
            showCompletion = true
        }
    }

    func earnedXP() -> Int {
        completedCount * 5
    }
}
