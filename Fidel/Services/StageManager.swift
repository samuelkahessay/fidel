import Foundation
import SwiftUI

@MainActor
@Observable
final class StageManager {
    private let progressRepository: ProgressRepositoryProtocol
    private let lessonRepository: LessonRepositoryProtocol

    private(set) var currentStage: LearningStage

    init(progressRepository: ProgressRepositoryProtocol,
         lessonRepository: LessonRepositoryProtocol = LessonRepository.shared) {
        self.progressRepository = progressRepository
        self.lessonRepository = lessonRepository
        self.currentStage = LearningStage(rawValue: progressRepository.getCurrentStage()) ?? .scriptAndSounds
    }

    // MARK: - Content Filtering

    func availableLessons() -> [Lesson] {
        let ids = currentStage.availableLessonIds
        return lessonRepository.getLessons().filter { ids.contains($0.id) }
    }

    func availableConversations() -> [Conversation] {
        let ids = currentStage.availableConversationIds
        return lessonRepository.getConversations().filter { ids.contains($0.id) }
    }

    func availablePracticeModes() -> [PracticeMode] {
        PracticeMode.allCases.filter { currentStage.availablePracticeModes.contains($0) }
    }

    func availableVocabulary() -> [VocabularyWord] {
        let lessonIds = currentStage.availableLessonIds
        if lessonIds.isEmpty {
            // Stage 0: return Fidel-related vocab only (empty for now — flashcards use Fidel chars)
            return []
        }
        return lessonRepository.getLessons()
            .filter { lessonIds.contains($0.id) }
            .flatMap { $0.vocabulary }
    }

    func availablePhrases() -> [Phrase] {
        let lessonIds = currentStage.availableLessonIds
        if lessonIds.isEmpty {
            return []
        }
        return lessonRepository.getLessons()
            .filter { lessonIds.contains($0.id) }
            .flatMap { $0.phrases }
    }

    // MARK: - Stage Progress

    func criteriaForNextStage() -> [StageCriterion]? {
        guard let next = nextStage() else { return nil }
        return LearningStage.criteria(for: next)
    }

    func progressToNextStage() -> Double {
        guard let criteria = criteriaForNextStage(),
              !criteria.isEmpty,
              let progress = progressRepository.getUserProgress() else {
            return currentStage == .fluency ? 1.0 : 0.0
        }
        let total = criteria.reduce(0.0) { $0 + $1.progressFraction(progress) }
        return total / Double(criteria.count)
    }

    func isStageUnlocked(_ stage: LearningStage) -> Bool {
        stage <= currentStage
    }

    /// Checks if the user meets criteria for the next stage and advances if so.
    /// Returns `true` if the stage was advanced.
    @discardableResult
    func checkAndAdvanceStage() -> Bool {
        guard let next = nextStage(),
              let progress = progressRepository.getUserProgress() else {
            return false
        }

        let criteria = LearningStage.criteria(for: next)
        let allMet = criteria.allSatisfy { $0.evaluate(progress) }

        if allMet {
            currentStage = next
            progressRepository.setCurrentStage(next.rawValue)
            return true
        }
        return false
    }

    // MARK: - Helpers

    private func nextStage() -> LearningStage? {
        LearningStage(rawValue: currentStage.rawValue + 1)
    }
}
