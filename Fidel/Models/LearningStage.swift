import Foundation
import SwiftUI

// MARK: - Learning Stage

enum LearningStage: Int, CaseIterable, Comparable, Identifiable {
    case scriptAndSounds = 0
    case survivalPhrases = 1
    case buildingSentences = 2
    case fluency = 3

    var id: Int { rawValue }

    static func < (lhs: LearningStage, rhs: LearningStage) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .scriptAndSounds: return "Script & Sounds"
        case .survivalPhrases: return "Survival Phrases"
        case .buildingSentences: return "Building Sentences"
        case .fluency: return "Fluency"
        }
    }

    var stageDescription: String {
        switch self {
        case .scriptAndSounds: return "Master the Fidel alphabet and character recognition"
        case .survivalPhrases: return "Learn essential greetings and everyday phrases"
        case .buildingSentences: return "Build sentences and hold real conversations"
        case .fluency: return "Free practice with all content unlocked"
        }
    }

    var icon: String {
        switch self {
        case .scriptAndSounds: return "character.textbox"
        case .survivalPhrases: return "bubble.left.and.text.bubble.right"
        case .buildingSentences: return "text.word.spacing"
        case .fluency: return "sparkles"
        }
    }

    var amharicTitle: String {
        switch self {
        case .scriptAndSounds: return "ፊደል"
        case .survivalPhrases: return "ሰላምታ"
        case .buildingSentences: return "ዓረፍተ ነገር"
        case .fluency: return "ብቃት"
        }
    }

    var color: Color {
        switch self {
        case .scriptAndSounds: return AppTheme.infoColor
        case .survivalPhrases: return AppTheme.primaryColor
        case .buildingSentences: return AppTheme.warningColor
        case .fluency: return AppTheme.secondaryColor
        }
    }

    // MARK: - Content Mappings

    var availableLessonIds: Set<Int> {
        switch self {
        case .scriptAndSounds: return []
        case .survivalPhrases: return [1, 2]
        case .buildingSentences: return [1, 2, 3, 4, 5]
        case .fluency: return [1, 2, 3, 4, 5, 6, 7, 8]
        }
    }

    var availableConversationIds: Set<Int> {
        switch self {
        case .scriptAndSounds: return []
        case .survivalPhrases: return [1, 5]
        case .buildingSentences: return Set(1...10)
        case .fluency: return Set(1...24)
        }
    }

    var availablePracticeModes: Set<PracticeMode> {
        switch self {
        case .scriptAndSounds: return [.flashcards, .quiz, .tracing]
        case .survivalPhrases: return [.flashcards, .quiz, .pronunciation, .wordOrder, .matchPairs]
        case .buildingSentences: return Set(PracticeMode.allCases)
        case .fluency: return Set(PracticeMode.allCases)
        }
    }

    var showsFidel: Bool {
        true // Fidel chart is always available
    }

    /// Number of recognized Fidel characters that unlocks Survival Phrases.
    /// Single source of truth shared by the `fidel_50` criterion and the
    /// stage-0 "Practice Fidel" activity progress so the two cannot drift.
    static let fidelRecognitionTarget = 50

    // MARK: - Stage Criteria

    static func criteria(for stage: LearningStage) -> [StageCriterion] {
        switch stage {
        case .scriptAndSounds:
            return [] // Starting stage, no criteria needed
        case .survivalPhrases:
            return [
                StageCriterion(
                    id: "fidel_50",
                    description: "Recognize \(fidelRecognitionTarget)+ Fidel characters",
                    icon: "character.textbox",
                    evaluate: { $0.fidelCharactersRecognized.count >= fidelRecognitionTarget },
                    current: { $0.fidelCharactersRecognized.count },
                    target: fidelRecognitionTarget
                )
            ]
        case .buildingSentences:
            return [
                StageCriterion(
                    id: "lessons_1_2",
                    description: "Complete Lessons 1 & 2",
                    icon: "book.fill",
                    evaluate: { $0.lessonsCompleted.contains(1) && $0.lessonsCompleted.contains(2) },
                    current: { [1, 2].filter($0.lessonsCompleted.contains).count },
                    target: 2
                ),
                StageCriterion(
                    id: "vocab_30",
                    description: "Master 30+ vocabulary words",
                    icon: "textformat.abc",
                    evaluate: { $0.vocabularyMastered.count >= 30 },
                    current: { $0.vocabularyMastered.count },
                    target: 30
                )
            ]
        case .fluency:
            return [
                StageCriterion(
                    id: "all_lessons",
                    description: "Complete core lessons (1-5)",
                    icon: "book.fill",
                    evaluate: { Set($0.lessonsCompleted).isSuperset(of: [1, 2, 3, 4, 5]) },
                    current: { Set([1, 2, 3, 4, 5]).intersection($0.lessonsCompleted).count },
                    target: 5
                ),
                StageCriterion(
                    id: "vocab_100",
                    description: "Master 100+ vocabulary words",
                    icon: "textformat.abc",
                    evaluate: { $0.vocabularyMastered.count >= 100 },
                    current: { $0.vocabularyMastered.count },
                    target: 100
                ),
                StageCriterion(
                    id: "conversations_5",
                    description: "Practice 5+ conversations",
                    icon: "bubble.left.and.bubble.right",
                    evaluate: { $0.conversationsPracticed.count >= 5 },
                    current: { $0.conversationsPracticed.count },
                    target: 5
                )
            ]
        }
    }
}

// MARK: - Stage Criterion

struct StageCriterion: Identifiable {
    let id: String
    let description: String
    let icon: String
    /// Authoritative gate used by `StageManager.checkAndAdvanceStage`. Kept
    /// independent of `current`/`target` so set-style checks (e.g. superset of
    /// lessons 1-5) keep their exact semantics.
    let evaluate: (UserProgress) -> Bool
    /// Current count toward `target`, used for progress display and `remaining`.
    let current: (UserProgress) -> Int
    let target: Int

    func progressFraction(_ progress: UserProgress) -> Double {
        guard target > 0 else { return evaluate(progress) ? 1 : 0 }
        return min(Double(current(progress)) / Double(target), 1)
    }

    /// How many more units are needed to satisfy `target` (never negative).
    func remaining(_ progress: UserProgress) -> Int {
        max(target - current(progress), 0)
    }
}
