import Foundation
import SwiftUI

// MARK: - Journey Activity Types

enum ActivityType: Hashable {
    case fidel
    case lesson(Int)
    case practiceMode(PracticeMode)
    case conversation(Int)
}

struct JourneyActivity: Identifiable {
    let id: String
    let type: ActivityType
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    var isCompleted: Bool
}

// MARK: - Journey ViewModel

@MainActor
@Observable
final class JourneyViewModel {
    var stageManager: StageManager?
    var currentStage: LearningStage = .scriptAndSounds
    var activities: [JourneyActivity] = []
    var lockedStages: [LearningStage] = []
    var progressToNextStage: Double = 0
    var showFidelChart = false
    var selectedLesson: Lesson?
    var selectedConversation: Conversation?
    var selectedPracticeMode: PracticeMode?
    var tappedLockedStage: LearningStage?
    var showStageAdvancement = false
    var advancedToStage: LearningStage?

    private var progressRepository: ProgressRepositoryProtocol?
    private let lessonRepository: LessonRepositoryProtocol
    private let audioAssetRepository: AudioAssetRepository

    init(
        lessonRepository: LessonRepositoryProtocol = LessonRepository.shared,
        audioAssetRepository: AudioAssetRepository = .shared
    ) {
        self.lessonRepository = lessonRepository
        self.audioAssetRepository = audioAssetRepository
    }

    func configure(stageManager: StageManager, progressRepository: ProgressRepositoryProtocol) {
        self.stageManager = stageManager
        self.progressRepository = progressRepository
        refresh()
    }

    func refresh() {
        guard let stageManager else { return }
        currentStage = stageManager.currentStage
        progressToNextStage = stageManager.progressToNextStage()
        activities = buildActivities()
        lockedStages = LearningStage.allCases.filter { !stageManager.isStageUnlocked($0) }
    }

    func checkAdvancement() {
        guard let stageManager else { return }
        if stageManager.checkAndAdvanceStage() {
            advancedToStage = stageManager.currentStage
            showStageAdvancement = true
            refresh()
        }
    }

    func selectCurrentStagePrimaryActivity() {
        guard let primaryActivity = activities.first else { return }
        selectActivity(primaryActivity)
    }

    func selectActivity(_ activity: JourneyActivity) {
        switch activity.type {
        case .fidel:
            showFidelChart = true
        case .lesson(let id):
            selectedLesson = lessonRepository.getLessons().first(where: { $0.id == id })
        case .practiceMode(let mode):
            selectedPracticeMode = mode
        case .conversation(let id):
            selectedConversation = lessonRepository.getConversations().first(where: { $0.id == id })
        }
    }

    // MARK: - Activity Building

    private func buildActivities() -> [JourneyActivity] {
        guard let stageManager else { return [] }
        let progress = progressRepository?.getUserProgress()

        var result: [JourneyActivity] = []

        switch currentStage {
        case .scriptAndSounds:
            result.append(JourneyActivity(
                id: "fidel_chart",
                type: .fidel,
                title: "Explore the Fidel Chart",
                subtitle: "Learn the Ethiopic script characters",
                icon: "character.textbox",
                color: AppTheme.infoColor,
                isCompleted: false
            ))
            result.append(JourneyActivity(
                id: "fidel_flashcards",
                type: .practiceMode(.flashcards),
                title: "Fidel Flashcards",
                subtitle: "Practice character recognition",
                icon: "rectangle.stack.fill",
                color: AppTheme.infoColor,
                isCompleted: false
            ))
            result.append(JourneyActivity(
                id: "character_quiz",
                type: .practiceMode(.quiz),
                title: "Character Quiz",
                subtitle: "Test your Fidel knowledge",
                icon: "questionmark.circle.fill",
                color: AppTheme.practiceColor,
                isCompleted: false
            ))
            result.append(JourneyActivity(
                id: "character_tracing",
                type: .practiceMode(.tracing),
                title: "Character Tracing",
                subtitle: "Practice writing Fidel characters",
                icon: "scribble.variable",
                color: AppTheme.practiceColor,
                isCompleted: false
            ))

        case .survivalPhrases:
            let lessons = stageManager.availableLessons()
            let conversations = stageManager.availableConversations()

            if let lesson1 = lessons.first(where: { $0.id == 1 }) {
                result.append(JourneyActivity(
                    id: "lesson_1",
                    type: .lesson(1),
                    title: lesson1.title,
                    subtitle: lesson1.description,
                    icon: "book.fill",
                    color: AppTheme.primaryColor,
                    isCompleted: progress?.lessonsCompleted.contains(1) ?? false
                ))
            }

            result.append(JourneyActivity(
                id: "flashcards_s1",
                type: .practiceMode(.flashcards),
                title: "Flashcards",
                subtitle: "Review vocabulary with spaced repetition",
                icon: "rectangle.stack.fill",
                color: AppTheme.infoColor,
                isCompleted: false
            ))

            appendPronunciationPracticeIfAvailable(to: &result, id: "pronunciation_s1")

            if let lesson2 = lessons.first(where: { $0.id == 2 }) {
                result.append(JourneyActivity(
                    id: "lesson_2",
                    type: .lesson(2),
                    title: lesson2.title,
                    subtitle: lesson2.description,
                    icon: "book.fill",
                    color: AppTheme.primaryColor,
                    isCompleted: progress?.lessonsCompleted.contains(2) ?? false
                ))
            }

            result.append(JourneyActivity(
                id: "quiz_s1",
                type: .practiceMode(.quiz),
                title: "Quiz",
                subtitle: "Test your knowledge",
                icon: "questionmark.circle.fill",
                color: AppTheme.practiceColor,
                isCompleted: false
            ))

            for conv in conversations {
                result.append(JourneyActivity(
                    id: "conversation_\(conv.id)",
                    type: .conversation(conv.id),
                    title: conv.title,
                    subtitle: "\(conv.lines.count) lines",
                    icon: "bubble.left.and.bubble.right",
                    color: AppTheme.practiceColor,
                    isCompleted: progress?.conversationsPracticed.contains(conv.id) ?? false
                ))
            }

        case .buildingSentences:
            let lessons = stageManager.availableLessons()
            let conversations = stageManager.availableConversations()

            for lesson in lessons {
                result.append(JourneyActivity(
                    id: "lesson_\(lesson.id)",
                    type: .lesson(lesson.id),
                    title: lesson.title,
                    subtitle: lesson.description,
                    icon: "book.fill",
                    color: AppTheme.primaryColor,
                    isCompleted: progress?.lessonsCompleted.contains(lesson.id) ?? false
                ))
            }

            for mode in visiblePracticeModes(stageManager.availablePracticeModes()) {
                result.append(JourneyActivity(
                    id: "practice_\(mode.rawValue)",
                    type: .practiceMode(mode),
                    title: mode.rawValue,
                    subtitle: mode.description,
                    icon: mode.icon,
                    color: mode.color,
                    isCompleted: false
                ))
            }

            for conv in conversations {
                result.append(JourneyActivity(
                    id: "conversation_\(conv.id)",
                    type: .conversation(conv.id),
                    title: conv.title,
                    subtitle: "\(conv.lines.count) lines",
                    icon: "bubble.left.and.bubble.right",
                    color: AppTheme.practiceColor,
                    isCompleted: progress?.conversationsPracticed.contains(conv.id) ?? false
                ))
            }

        case .fluency:
            // All content available
            for lesson in lessonRepository.getLessons() {
                result.append(JourneyActivity(
                    id: "lesson_\(lesson.id)",
                    type: .lesson(lesson.id),
                    title: lesson.title,
                    subtitle: lesson.description,
                    icon: "book.fill",
                    color: AppTheme.primaryColor,
                    isCompleted: progress?.lessonsCompleted.contains(lesson.id) ?? false
                ))
            }

            for mode in visiblePracticeModes(PracticeMode.allCases) {
                result.append(JourneyActivity(
                    id: "practice_\(mode.rawValue)",
                    type: .practiceMode(mode),
                    title: mode.rawValue,
                    subtitle: mode.description,
                    icon: mode.icon,
                    color: mode.color,
                    isCompleted: false
                ))
            }

            for conv in lessonRepository.getConversations() {
                result.append(JourneyActivity(
                    id: "conversation_\(conv.id)",
                    type: .conversation(conv.id),
                    title: conv.title,
                    subtitle: "\(conv.lines.count) lines",
                    icon: "bubble.left.and.bubble.right",
                    color: AppTheme.practiceColor,
                    isCompleted: progress?.conversationsPracticed.contains(conv.id) ?? false
                ))
            }
        }

        return result
    }

    private func appendPronunciationPracticeIfAvailable(to result: inout [JourneyActivity], id: String) {
        guard audioAssetRepository.hasPronunciationPracticeContent else { return }
        result.append(JourneyActivity(
            id: id,
            type: .practiceMode(.pronunciation),
            title: "Pronunciation Practice",
            subtitle: "Listen to generated pronunciation",
            icon: "waveform",
            color: AppTheme.primaryColor,
            isCompleted: false
        ))
    }

    private func visiblePracticeModes(_ modes: [PracticeMode]) -> [PracticeMode] {
        modes.filter { mode in
            mode != .pronunciation || audioAssetRepository.hasPronunciationPracticeContent
        }
    }
}
