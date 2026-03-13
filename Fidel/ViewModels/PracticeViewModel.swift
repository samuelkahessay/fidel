import Foundation

@MainActor
@Observable
final class PracticeViewModel {
    var currentMode: PracticeMode = .flashcards
    var isSessionActive = false
    var sessionScore = 0
    var sessionTotal = 0

    func startSession(mode: PracticeMode) {
        currentMode = mode
        isSessionActive = true
        sessionScore = 0
        sessionTotal = 0
    }

    func endSession() {
        isSessionActive = false
    }

    func recordAnswer(correct: Bool) {
        sessionTotal += 1
        if correct {
            sessionScore += 1
        }
    }

    var accuracy: Double {
        sessionTotal > 0 ? Double(sessionScore) / Double(sessionTotal) : 0
    }
}
