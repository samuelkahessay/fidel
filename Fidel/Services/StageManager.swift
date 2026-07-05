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

    // MARK: - Content

    // The learning path is fully open: every lesson, conversation, practice
    // mode, word, and phrase is available at all times. These accessors return
    // all content unconditionally — nothing is stage-gated anymore.

    func availableLessons() -> [Lesson] {
        lessonRepository.getLessons()
    }

    func availableConversations() -> [Conversation] {
        lessonRepository.getConversations()
    }

    func availablePracticeModes() -> [PracticeMode] {
        PracticeMode.allCases
    }

    func availableVocabulary() -> [VocabularyWord] {
        lessonRepository.getLessons().flatMap { $0.vocabulary }
    }

    func availablePhrases() -> [Phrase] {
        lessonRepository.getLessons().flatMap { $0.phrases }
    }
}
