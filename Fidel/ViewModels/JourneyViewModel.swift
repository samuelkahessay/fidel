import Foundation
import SwiftUI

// MARK: - Journey Activity Types

enum ActivityType: Hashable {
    case fidel
    case lesson(Int)
    case practiceMode(PracticeMode)
    case conversation(Int)
}

/// Optional measurable progress shown on an activity card (e.g. recognized
/// characters toward the unlock target). Nil when the activity has no
/// meaningful count to display.
struct ActivityProgress: Equatable {
    let current: Int
    let target: Int
    let unit: String

    var fraction: Double {
        target > 0 ? min(Double(current) / Double(target), 1) : 0
    }
    var isComplete: Bool { current >= target }
}

struct JourneyActivity: Identifiable {
    let id: String
    let type: ActivityType
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    var isCompleted: Bool
    var progress: ActivityProgress? = nil
}

// MARK: - Next-Action Hero

/// What the hero's primary CTA does. Maps onto the existing Journey navigation.
enum HeroAction: Equatable {
    case practiceTracing
    case lesson(Int)
    case flashcards
    case matchPairs
    case conversation(Int)
    case browseChart
}

enum HeroStyle {
    /// Actionable requirement toward the next stage.
    case action
    /// Every next-stage criterion is met but the stage has not advanced yet.
    case ready
    /// No further stage to unlock (Fluency) — open-ended practice.
    case freePractice
}

/// The single most important next step, derived from the gating criteria.
struct NextActionHero {
    let eyebrow: String
    let title: String
    let detail: String
    let progress: Double
    let ctaLabel: String
    let ctaIcon: String
    let action: HeroAction
    let style: HeroStyle
    /// The hero bar shows only when it fully represents the gate (a single
    /// next-stage criterion). With multiple criteria the stage ring and the
    /// "Next stage" checklist carry progress, so the hero stays text + CTA only.
    var showsProgressBar: Bool = false
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

    // MARK: - Next-Action Hero

    /// The single clearest next step toward unlocking the next stage. Reads live
    /// progress each access (like `nextStageCriteria`) so it stays in sync after
    /// the view refreshes on return from an activity.
    var nextActionHero: NextActionHero? {
        guard let stageManager,
              let progress = progressRepository?.getUserProgress() else { return nil }

        // Fluency / no next stage: open-ended practice, never a fidel target.
        guard let criteria = stageManager.criteriaForNextStage(), !criteria.isEmpty else {
            return NextActionHero(
                eyebrow: "Keep practicing",
                title: "You've unlocked everything",
                detail: "Free practice with every lesson, drill, and conversation.",
                progress: 1,
                ctaLabel: "Review with flashcards",
                ctaIcon: "rectangle.stack.fill",
                action: .flashcards,
                style: .freePractice
            )
        }

        let nextStageName = LearningStage(rawValue: currentStage.rawValue + 1)?.displayName ?? "the next stage"

        // All criteria met but not advanced yet (transient until checkAdvancement).
        guard let unmet = criteria.first(where: { !$0.evaluate(progress) }) else {
            return NextActionHero(
                eyebrow: "Almost there",
                title: "Stage complete!",
                detail: "Unlocking \(nextStageName)…",
                progress: 1,
                ctaLabel: "Continue",
                ctaIcon: "checkmark.circle.fill",
                action: .practiceTracing, // unused: the .ready CTA calls refreshAfterReturn()
                style: .ready
            )
        }

        let plan = heroPlan(for: unmet, progress: progress)
        return NextActionHero(
            eyebrow: "Up next",
            title: plan.title(unmet.remaining(progress)),
            detail: "to unlock \(nextStageName)",
            progress: unmet.progressFraction(progress),
            ctaLabel: plan.ctaLabel,
            ctaIcon: plan.ctaIcon,
            action: plan.action,
            style: .action,
            showsProgressBar: criteria.count == 1
        )
    }

    func performHeroAction(_ action: HeroAction) {
        switch action {
        case .practiceTracing:
            selectedPracticeMode = .tracing
        case .lesson(let id):
            selectedLesson = lessonRepository.getLessons().first(where: { $0.id == id })
        case .flashcards:
            selectedPracticeMode = .flashcards
        case .matchPairs:
            selectedPracticeMode = .matchPairs
        case .conversation(let id):
            selectedConversation = lessonRepository.getConversations().first(where: { $0.id == id })
        case .browseChart:
            showFidelChart = true
        }
    }

    private struct HeroPlan {
        let title: (Int) -> String
        let ctaLabel: String
        let ctaIcon: String
        let action: HeroAction
    }

    /// Maps a gating criterion to hero copy + CTA using prefix-tolerant id
    /// matching, with a safe default for any unrecognized criterion id.
    private func heroPlan(for criterion: StageCriterion, progress: UserProgress) -> HeroPlan {
        func more(_ n: Int, _ noun: String) -> String {
            "\(n) more \(noun)\(n == 1 ? "" : "s")"
        }
        let id = criterion.id
        if id.contains("fidel") {
            return HeroPlan(
                title: { "Recognize \(more($0, "character"))" },
                ctaLabel: "Practice Fidel",
                ctaIcon: "scribble.variable",
                action: .practiceTracing
            )
        }
        if id.contains("lesson") {
            let lessonId = stageManager?.availableLessons()
                .first { !progress.lessonsCompleted.contains($0.id) }?.id
            return HeroPlan(
                title: { "Complete \(more($0, "lesson"))" },
                ctaLabel: "Continue lesson",
                ctaIcon: "book.fill",
                action: lessonId.map { .lesson($0) } ?? .flashcards
            )
        }
        if id.contains("vocab") {
            // Match Pairs is the mode that actually masters vocabulary; plain
            // flashcards only reschedule FSRS reviews and never advance the gate.
            return HeroPlan(
                title: { "Master \(more($0, "word"))" },
                ctaLabel: "Match word pairs",
                ctaIcon: "square.on.square",
                action: .matchPairs
            )
        }
        if id.contains("conversation") {
            let convId = stageManager?.availableConversations()
                .first { !progress.conversationsPracticed.contains($0.id) }?.id
            return HeroPlan(
                title: { _ in "Practice a conversation" },
                ctaLabel: "Practice a conversation",
                ctaIcon: "bubble.left.and.bubble.right",
                action: convId.map { .conversation($0) } ?? .flashcards
            )
        }
        // Unknown criterion id: fall back to the current stage's primary activity.
        return HeroPlan(
            title: { _ in criterion.description },
            ctaLabel: "Continue",
            ctaIcon: "arrow.right",
            action: primaryActivityAction()
        )
    }

    private func primaryActivityAction() -> HeroAction {
        switch activities.first?.type {
        case .fidel: return .browseChart
        case .practiceMode(.tracing): return .practiceTracing
        case .practiceMode: return .flashcards
        case .lesson(let id): return .lesson(id)
        case .conversation(let id): return .conversation(id)
        case .none: return .practiceTracing
        }
    }

    // MARK: - Activity Building

    private func buildActivities() -> [JourneyActivity] {
        guard let stageManager else { return [] }
        let progress = progressRepository?.getUserProgress()

        var result: [JourneyActivity] = []

        switch currentStage {
        case .scriptAndSounds:
            let recognized = progress?.fidelCharactersRecognized.count ?? 0
            let recognitionTarget = LearningStage.fidelRecognitionTarget
            // Primary: the adaptive tracing session (TraceSessionPlan.standard),
            // which serves new + due-for-review characters and marks recognition.
            result.append(JourneyActivity(
                id: "practice_fidel",
                type: .practiceMode(.tracing),
                title: "Practice Fidel",
                subtitle: "Trace characters to learn them — adapts to what you know",
                icon: "scribble.variable",
                color: AppTheme.practiceColor,
                isCompleted: recognized >= recognitionTarget,
                progress: ActivityProgress(
                    current: min(recognized, recognitionTarget),
                    target: recognitionTarget,
                    unit: "recognized"
                )
            ))
            // Secondary: the chart as a lookup tool (does not mark recognition).
            result.append(JourneyActivity(
                id: "fidel_chart",
                type: .fidel,
                title: "Browse the chart",
                subtitle: "Look up any letter, sound, and vowel form",
                icon: "character.book.closed",
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
