import Foundation
import SwiftUI
import PencilKit

/// Manages state for a character tracing practice session.
/// Presents 10 random first-order (ግዕዝ) Fidel characters for the user to trace.
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

    // MARK: - Dependencies

    private var progressRepository: ProgressRepositoryProtocol?
    private let pathExtractor = PathExtractor.shared
    private let evaluator = DrawingEvaluator.shared
    let canvasSize = CGSize(width: 300, height: 300)

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
        return Double(currentIndex) / Double(characters.count)
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

        switch result {
        case .passedForReview(let score):
            lastScore = score
            needsRetry = false
            phase = .reviewing
        case .needsRetry(let score):
            lastScore = score
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

    // MARK: - Navigation

    private func nextCharacter() {
        if currentIndex < characters.count - 1 {
            currentIndex += 1
            phase = .watching
            userDrawing = PKDrawing()
            lastScore = 0
            needsRetry = false
        } else {
            showCompletion = true
        }
    }

    func earnedXP() -> Int {
        completedCount * 5
    }
}
