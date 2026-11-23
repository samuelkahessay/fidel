import Foundation
import SwiftData

// MARK: - SelamRepository Protocol

// `@MainActor`-isolated to match its only conformer (`SelamRepository`, a
// `@MainActor @Observable` type wrapping a main-actor `ModelContext`) and its
// consumer (`SelamViewModel` is `@MainActor`). Without this the conformance
// crosses actor boundaries — a data-race warning today, an error in Swift 6.
@MainActor
protocol SelamRepositoryProtocol {
    func getConversations() -> [SelamConversation]
    func getConversation(by id: UUID) -> SelamConversation?
    func getActiveConversation() -> SelamConversation?
    func createConversation(entryContext: SelamEntryContext?) -> SelamConversation
    func deleteConversation(_ conversation: SelamConversation)
    func deleteAllConversations()

    func addMessage(_ message: SelamMessage, to conversation: SelamConversation)
    func updateMessage(_ message: SelamMessage, content: String, isComplete: Bool)
    func deleteMessage(_ message: SelamMessage)
    func getMessages(for conversation: SelamConversation, limit: Int?) -> [SelamMessage]

    func getCoachingSettings() -> SelamCoachingSettings
    func saveCoachingSettings(_ settings: SelamCoachingSettings)

    func getMessageCountToday() -> Int
    func canSendMessage(dailyLimit: Int) -> Bool
}

// MARK: - SelamRepository Implementation

@MainActor
@Observable
final class SelamRepository: SelamRepositoryProtocol {

    private let modelContext: ModelContext
    private let userDefaults: UserDefaults

    private let coachingSettingsKey = "selam_coaching_settings"
    private let dailyMessageCountKey = "selam_daily_message_count"
    private let lastMessageDateKey = "selam_last_message_date"

    init(modelContext: ModelContext, userDefaults: UserDefaults = .standard) {
        self.modelContext = modelContext
        self.userDefaults = userDefaults
    }

    func getConversations() -> [SelamConversation] {
        let descriptor = FetchDescriptor<SelamConversation>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func getConversation(by id: UUID) -> SelamConversation? {
        let descriptor = FetchDescriptor<SelamConversation>(
            predicate: #Predicate { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first
    }

    func getActiveConversation() -> SelamConversation? {
        let oneDayAgo = Date.now.addingTimeInterval(-24 * 60 * 60)
        let descriptor = FetchDescriptor<SelamConversation>(
            predicate: #Predicate { $0.updatedAt > oneDayAgo },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try? modelContext.fetch(descriptor).first
    }

    func createConversation(entryContext: SelamEntryContext?) -> SelamConversation {
        let conversation = SelamConversation(
            title: nil,
            entryContextType: entryContext?.type.rawValue,
            entryContextId: entryContext?.itemId
        )
        modelContext.insert(conversation)

        let welcomeMessage = createWelcomeMessage(for: entryContext)
        welcomeMessage.conversation = conversation
        modelContext.insert(welcomeMessage)

        return conversation
    }

    func deleteConversation(_ conversation: SelamConversation) {
        modelContext.delete(conversation)
    }

    func deleteAllConversations() {
        let descriptor = FetchDescriptor<SelamConversation>()
        if let conversations = try? modelContext.fetch(descriptor) {
            for conversation in conversations {
                modelContext.delete(conversation)
            }
        }
    }

    func addMessage(_ message: SelamMessage, to conversation: SelamConversation) {
        message.conversation = conversation
        modelContext.insert(message)
        conversation.updatedAt = Date.now
        conversation.generateTitle()

        if message.role == .user {
            incrementDailyMessageCount()
        }
    }

    func updateMessage(_ message: SelamMessage, content: String, isComplete: Bool) {
        message.content = content
        message.isComplete = isComplete
    }

    func deleteMessage(_ message: SelamMessage) {
        modelContext.delete(message)
    }

    func getMessages(for conversation: SelamConversation, limit: Int?) -> [SelamMessage] {
        var messages = conversation.sortedMessages
        if let limit = limit {
            messages = Array(messages.suffix(limit))
        }
        return messages
    }

    func getCoachingSettings() -> SelamCoachingSettings {
        guard let data = userDefaults.data(forKey: coachingSettingsKey),
            let settings = try? JSONDecoder().decode(SelamCoachingSettings.self, from: data)
        else {
            return .default
        }
        return settings
    }

    func saveCoachingSettings(_ settings: SelamCoachingSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            userDefaults.set(data, forKey: coachingSettingsKey)
        }
    }

    func getMessageCountToday() -> Int {
        resetDailyCountIfNeeded()
        return userDefaults.integer(forKey: dailyMessageCountKey)
    }

    func canSendMessage(dailyLimit: Int) -> Bool {
        return getMessageCountToday() < dailyLimit
    }

    private func incrementDailyMessageCount() {
        resetDailyCountIfNeeded()
        let currentCount = userDefaults.integer(forKey: dailyMessageCountKey)
        userDefaults.set(currentCount + 1, forKey: dailyMessageCountKey)
        userDefaults.set(Date.now, forKey: lastMessageDateKey)
    }

    private func resetDailyCountIfNeeded() {
        guard let lastDate = userDefaults.object(forKey: lastMessageDateKey) as? Date else {
            userDefaults.set(0, forKey: dailyMessageCountKey)
            return
        }

        if !Calendar.current.isDateInToday(lastDate) {
            userDefaults.set(0, forKey: dailyMessageCountKey)
        }
    }

    private func createWelcomeMessage(for entryContext: SelamEntryContext?) -> SelamMessage {
        let welcomeContent: String

        switch entryContext?.type {
        case .lesson:
            welcomeContent = """
                ሰላም! I see you're working on \(entryContext?.itemTitle ?? "a lesson"). How can I help?

                I can explain grammar, vocabulary, or practice with you. What would you like to focus on?
                """
        case .vocabulary:
            if let word = entryContext?.itemTitle {
                welcomeContent = """
                    ሰላም! You're curious about "\(word)" - great choice!

                    What would you like to know? I can explain its meaning, show examples, or help you use it in sentences.
                    """
            } else {
                welcomeContent = defaultWelcome
            }
        case .quiz:
            welcomeContent = """
                ሰላም! How did your quiz go?

                I'm here to help you review anything you found tricky. What would you like to work on?
                """
        case .conversation:
            welcomeContent = """
                ሰላም! Great job practicing that conversation!

                Would you like to try a free-form conversation with me, or review specific phrases?
                """
        default:
            welcomeContent = defaultWelcome
        }

        let message = SelamMessage(content: welcomeContent, role: .assistant)
        message.suggestedActions = defaultSuggestedActions(for: entryContext)
        return message
    }

    private var defaultWelcome: String {
        """
        ሰላም! (selam!) I'm Selam, your Amharic tutor.

        I can answer questions, help you practice conversations, and give you personalized tips. What would you like to work on today?
        """
    }

    private func defaultSuggestedActions(for entryContext: SelamEntryContext?) -> [String] {
        switch entryContext?.type {
        case .lesson:
            return ["Explain the grammar", "Quiz me on vocabulary", "Practice speaking"]
        case .vocabulary:
            return ["Show more examples", "How do I pronounce it?", "Related words"]
        case .quiz:
            return ["Review my mistakes", "Practice more", "Try a harder quiz"]
        case .conversation:
            return ["Practice with me", "Teach me new phrases", "Cultural context"]
        default:
            return ["Teach me greetings", "Help with vocabulary", "Practice a conversation"]
        }
    }
}
