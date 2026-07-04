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
}
