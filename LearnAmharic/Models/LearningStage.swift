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
        case .scriptAndSounds: return .blue
        case .survivalPhrases: return AppTheme.primaryColor
        case .buildingSentences: return .orange
        case .fluency: return AppTheme.secondaryColor
        }
    }

    // MARK: - Content Mappings

    var availableLessonIds: Set<Int> {
        switch self {
        case .scriptAndSounds: return []
        case .survivalPhrases: return [1, 2]
        case .buildingSentences: return [1, 2, 3, 4, 5]
        case .fluency: return [1, 2, 3, 4, 5]
        }
    }

    var availableConversationIds: Set<Int> {
        switch self {
        case .scriptAndSounds: return []
        case .survivalPhrases: return [1, 5]
        case .buildingSentences: return Set(1...10)
        case .fluency: return Set(1...10)
        }
    }

    var availablePracticeModes: Set<PracticeMode> {
        switch self {
        case .scriptAndSounds: return [.flashcards, .quiz]
        case .survivalPhrases: return [.flashcards, .quiz, .pronunciation]
        case .buildingSentences: return Set(PracticeMode.allCases)
        case .fluency: return Set(PracticeMode.allCases)
        }
    }

    var showsFidel: Bool {
        true // Fidel chart is always available
    }

    // MARK: - Stage Criteria

    static func criteria(for stage: LearningStage) -> [StageCriterion] {
        switch stage {
        case .scriptAndSounds:
            return [] // Starting stage, no criteria needed
        case .survivalPhrases:
            return [
                StageCriterion(
                    id: "fidel_50",
                    description: "Recognize 50+ Fidel characters",
                    icon: "character.textbox",
                    evaluate: { $0.fidelCharactersRecognized.count >= 50 },
                    progressFraction: { min(Double($0.fidelCharactersRecognized.count) / 50.0, 1.0) }
                )
            ]
        case .buildingSentences:
            return [
                StageCriterion(
                    id: "lessons_1_2",
                    description: "Complete Lessons 1 & 2",
                    icon: "book.fill",
                    evaluate: { $0.lessonsCompleted.contains(1) && $0.lessonsCompleted.contains(2) },
                    progressFraction: { progress in
                        let count = [1, 2].filter { progress.lessonsCompleted.contains($0) }.count
                        return Double(count) / 2.0
                    }
                ),
                StageCriterion(
                    id: "vocab_30",
                    description: "Master 30+ vocabulary words",
                    icon: "textformat.abc",
                    evaluate: { $0.vocabularyMastered.count >= 30 },
                    progressFraction: { min(Double($0.vocabularyMastered.count) / 30.0, 1.0) }
                )
            ]
        case .fluency:
            return [
                StageCriterion(
                    id: "all_lessons",
                    description: "Complete all lessons",
                    icon: "book.fill",
                    evaluate: { Set($0.lessonsCompleted).isSuperset(of: [1, 2, 3, 4, 5]) },
                    progressFraction: { progress in
                        let count = Set([1, 2, 3, 4, 5]).intersection(progress.lessonsCompleted).count
                        return Double(count) / 5.0
                    }
                ),
                StageCriterion(
                    id: "vocab_100",
                    description: "Master 100+ vocabulary words",
                    icon: "textformat.abc",
                    evaluate: { $0.vocabularyMastered.count >= 100 },
                    progressFraction: { min(Double($0.vocabularyMastered.count) / 100.0, 1.0) }
                ),
                StageCriterion(
                    id: "conversations_5",
                    description: "Practice 5+ conversations",
                    icon: "bubble.left.and.bubble.right",
                    evaluate: { $0.conversationsPracticed.count >= 5 },
                    progressFraction: { min(Double($0.conversationsPracticed.count) / 5.0, 1.0) }
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
    let evaluate: (UserProgress) -> Bool
    let progressFraction: (UserProgress) -> Double
}
