import Foundation
import SwiftData

// MARK: - Selam AI Tutor Data Models

/// Represents a conversation with Selam AI tutor
@Model
final class SelamConversation {
    var id: UUID = UUID()
    var title: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    @Relationship(deleteRule: .cascade, inverse: \SelamMessage.conversation)
    var messages: [SelamMessage]? = []

    /// Entry context - where the conversation was started from
    var entryContextType: String?  // "lesson", "vocabulary", "practice", "general"
    var entryContextId: String?  // The ID of the lesson/vocabulary item

    init(title: String? = nil, entryContextType: String? = nil, entryContextId: String? = nil) {
        self.title = title
        self.entryContextType = entryContextType
        self.entryContextId = entryContextId
    }

    /// Returns messages sorted by timestamp
    var sortedMessages: [SelamMessage] {
        (messages ?? []).sorted { $0.timestamp < $1.timestamp }
    }

    /// Preview text for conversation list
    var preview: String {
        if let lastMessage = sortedMessages.last {
            return String(lastMessage.content.prefix(100))
        }
        return "New conversation"
    }

    /// Auto-generate title from first user message
    func generateTitle() {
        if title == nil, let firstUserMessage = sortedMessages.first(where: { $0.role == .user }) {
            let words = firstUserMessage.content.split(separator: " ").prefix(6)
            title = words.joined(separator: " ") + (words.count >= 6 ? "..." : "")
        }
    }
}

/// Represents a single message in a Selam conversation
@Model
final class SelamMessage {
    var id: UUID = UUID()
    var content: String = ""
    var role: MessageRole = MessageRole.user
    var timestamp: Date = Date()
    var conversation: SelamConversation?

    /// Suggested actions returned by AI (stored as JSON string)
    var suggestedActionsJSON: String?

    /// For streaming responses - marks if message is complete
    var isComplete: Bool = false

    /// Optional metadata for the message (stored as JSON string)
    var metadataJSON: String?

    init(content: String, role: MessageRole, isComplete: Bool = true) {
        self.content = content
        self.role = role
        self.isComplete = isComplete
    }

    /// Parsed suggested actions
    var suggestedActions: [String] {
        get {
            guard let json = suggestedActionsJSON,
                let data = json.data(using: .utf8),
                let actions = try? JSONDecoder().decode([String].self, from: data)
            else {
                return []
            }
            return actions
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
                let json = String(data: data, encoding: .utf8)
            {
                suggestedActionsJSON = json
            }
        }
    }
}

/// Role of a message sender
enum MessageRole: String, Codable {
    case user
    case assistant
    case system
}

// MARK: - Selam Context for AI

/// Aggregates user progress data to provide context to the AI
struct SelamContext: Codable {
    let lessonsCompleted: [Int]
    let patternsLearned: [String]
    let vocabularyMastered: [String]
    let conversationsPracticed: [Int]
    let currentStreak: Int
    let totalXP: Int
    let level: Int
    let weakAreas: [String]

    /// Create context from UserProgress
    static func from(userProgress: UserProgress?) -> SelamContext {
        guard let progress = userProgress else {
            return SelamContext(
                lessonsCompleted: [],
                patternsLearned: [],
                vocabularyMastered: [],
                conversationsPracticed: [],
                currentStreak: 0,
                totalXP: 0,
                level: 1,
                weakAreas: []
            )
        }

        return SelamContext(
            lessonsCompleted: progress.lessonsCompleted,
            patternsLearned: progress.patternsLearned,
            vocabularyMastered: progress.vocabularyMastered,
            conversationsPracticed: progress.conversationsPracticed,
            currentStreak: progress.currentStreak,
            totalXP: progress.totalXP,
            level: progress.totalXP / 100 + 1,
            weakAreas: identifyWeakAreas(from: progress)
        )
    }

    /// Identify areas where user may be struggling
    private static func identifyWeakAreas(from progress: UserProgress) -> [String] {
        var weakAreas: [String] = []

        // If user has completed lessons but mastered few vocabulary words
        if progress.lessonsCompleted.count > 2 && progress.vocabularyMastered.count < 20 {
            weakAreas.append("vocabulary retention")
        }

        // If user hasn't practiced conversations
        if progress.lessonsCompleted.count > 1 && progress.conversationsPracticed.isEmpty {
            weakAreas.append("conversational practice")
        }

        // If few patterns learned relative to lessons
        if progress.lessonsCompleted.count > 2 && progress.patternsLearned.count < 5 {
            weakAreas.append("sentence patterns")
        }

        return weakAreas
    }

    /// Convert to dictionary for API request
    func toDictionary() -> [String: Any] {
        return [
            "lessonsCompleted": lessonsCompleted,
            "patternsLearned": patternsLearned,
            "vocabularyMastered": vocabularyMastered.count,  // Just count to reduce payload
            "conversationsPracticed": conversationsPracticed,
            "currentStreak": currentStreak,
            "totalXP": totalXP,
            "level": level,
            "weakAreas": weakAreas,
        ]
    }
}

// MARK: - Entry Context

/// Describes where a Selam conversation was initiated from
struct SelamEntryContext: Codable {
    let type: EntryContextType
    let itemId: String?
    let itemTitle: String?
    let additionalContext: String?

    enum EntryContextType: String, Codable {
        case general  // From Selam tab
        case lesson  // From a lesson
        case vocabulary  // Long-press on vocabulary word
        case pattern  // From a sentence pattern
        case conversation  // From a conversation practice
        case quiz  // After a quiz
        case flashcard  // During flashcard practice
    }

    /// Generate prompt prefix based on entry context
    func toPromptContext() -> String? {
        switch type {
        case .general:
            return nil
        case .lesson:
            if let title = itemTitle {
                return "The user is currently studying: \(title)"
            }
            return nil
        case .vocabulary:
            if let word = itemTitle {
                return "The user is asking about the vocabulary word: \(word)"
            }
            return nil
        case .pattern:
            if let pattern = itemTitle {
                return "The user is studying the sentence pattern: \(pattern)"
            }
            return nil
        case .conversation:
            if let title = itemTitle {
                return "The user just practiced the conversation: \(title)"
            }
            return nil
        case .quiz:
            if let context = additionalContext {
                return "The user just completed a quiz. \(context)"
            }
            return "The user just completed a quiz."
        case .flashcard:
            return "The user is practicing flashcards."
        }
    }
}

// MARK: - Coaching Settings

/// User preferences for Selam coaching behavior
struct SelamCoachingSettings: Codable {
    var coachingFrequency: CoachingFrequency
    var languagePreference: LanguagePreference
    var snoozedUntil: Date?

    enum CoachingFrequency: String, Codable, CaseIterable {
        case high = "High"
        case medium = "Medium"
        case low = "Low"
        case off = "Off"

        var description: String {
            switch self {
            case .high: return "Proactive tips after every lesson"
            case .medium: return "Occasional suggestions"
            case .low: return "Only when I ask"
            case .off: return "No coaching messages"
            }
        }
    }

    enum LanguagePreference: String, Codable, CaseIterable {
        case english = "English"
        case amharic = "Amharic"
        case mixed = "Mixed"

        var description: String {
            switch self {
            case .english: return "Respond in English"
            case .amharic: return "Respond in Amharic"
            case .mixed: return "Mix both languages"
            }
        }
    }

    static var `default`: SelamCoachingSettings {
        SelamCoachingSettings(
            coachingFrequency: .medium,
            languagePreference: .mixed,
            snoozedUntil: nil
        )
    }

    /// Check if coaching is currently snoozed
    var isSnoozed: Bool {
        if let snoozedUntil = snoozedUntil {
            return Date.now < snoozedUntil
        }
        return false
    }
}

// MARK: - API Request/Response Models

/// Request body for Selam AI chat endpoint
struct SelamChatRequest: Codable {
    let message: String
    let conversationId: String
    let userContext: SelamContext
    let history: [SelamHistoryMessage]
    let entryContext: SelamEntryContext?
    let settings: SelamCoachingSettings
}

/// Simplified message for API history
struct SelamHistoryMessage: Codable {
    let role: String
    let content: String

    init(from message: SelamMessage) {
        self.role = message.role.rawValue
        self.content = message.content
    }
}

/// Streaming response token
struct SelamStreamToken: Codable {
    let content: String?
    let suggestedActions: [String]?
    let done: Bool?
}
