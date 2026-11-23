import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class SelamViewModel {

    private(set) var messages: [SelamMessage] = []
    private(set) var currentConversation: SelamConversation?
    private(set) var isLoading = false
    private(set) var streamingContent = ""
    private(set) var error: SelamError?
    var showError = false

    var inputText = ""
    var showSettings = false
    var showHistory = false

    private let aiService: SelamAIServiceProtocol
    private var repository: SelamRepositoryProtocol?
    private var progressRepository: ProgressRepositoryProtocol?
    private var entryContext: SelamEntryContext?

    private let dailyMessageLimit = 100
    private var streamingTask: Task<Void, Never>?

    init(aiService: SelamAIServiceProtocol? = nil) {
        self.aiService = aiService ?? OnDeviceSelamService()
    }

    func configure(
        repository: SelamRepositoryProtocol,
        progressRepository: ProgressRepositoryProtocol,
        entryContext: SelamEntryContext? = nil
    ) {
        self.repository = repository
        self.progressRepository = progressRepository
        self.entryContext = entryContext
        loadOrCreateConversation()
    }

    var canSendMessage: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
            && (repository?.canSendMessage(dailyLimit: dailyMessageLimit) ?? true)
    }

    var messageCountToday: Int {
        repository?.getMessageCountToday() ?? 0
    }

    var remainingMessages: Int {
        max(0, dailyMessageLimit - messageCountToday)
    }

    var coachingSettings: SelamCoachingSettings {
        repository?.getCoachingSettings() ?? .default
    }

    func loadOrCreateConversation() {
        guard let repository else { return }

        if let active = repository.getActiveConversation() {
            currentConversation = active
            messages = repository.getMessages(for: active, limit: nil)
        } else {
            let newConversation = repository.createConversation(entryContext: entryContext)
            currentConversation = newConversation
            messages = repository.getMessages(for: newConversation, limit: nil)
        }
    }

    func startNewConversation() {
        guard let repository else { return }
        let newConversation = repository.createConversation(entryContext: nil)
        currentConversation = newConversation
        messages = repository.getMessages(for: newConversation, limit: nil)
    }

    func loadConversation(_ conversation: SelamConversation) {
        guard let repository else { return }
        currentConversation = conversation
        messages = repository.getMessages(for: conversation, limit: nil)
        showHistory = false
    }

    func sendMessage() {
        guard canSendMessage, let conversation = currentConversation else { return }

        let messageText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        inputText = ""

        let userMessage = SelamMessage(content: messageText, role: .user)
        repository?.addMessage(userMessage, to: conversation)
        messages.append(userMessage)

        let placeholderMessage = SelamMessage(content: "", role: .assistant, isComplete: false)
        repository?.addMessage(placeholderMessage, to: conversation)
        messages.append(placeholderMessage)

        isLoading = true
        streamingContent = ""
        error = nil

        streamingTask = Task { @MainActor in
            await streamResponse(for: messageText, placeholderMessage: placeholderMessage)
        }
    }

    func sendSuggestedAction(_ action: String) {
        inputText = action
        sendMessage()
    }

    func retryLastMessage() {
        guard let lastUserMessage = messages.last(where: { $0.role == .user }) else { return }

        if let lastAssistant = messages.last, lastAssistant.role == .assistant && !lastAssistant.isComplete {
            messages.removeLast()
        }

        inputText = lastUserMessage.content
        messages.removeAll { $0.id == lastUserMessage.id }

        sendMessage()
    }

    func cancelStreaming() {
        streamingTask?.cancel()
        streamingTask = nil
        isLoading = false

        if let lastMessage = messages.last, !lastMessage.isComplete {
            repository?.updateMessage(lastMessage, content: streamingContent, isComplete: true)
            if let index = messages.firstIndex(where: { $0.id == lastMessage.id }) {
                messages[index].content = streamingContent
                messages[index].isComplete = true
            }
        }
        streamingContent = ""
    }

    func updateCoachingSettings(_ settings: SelamCoachingSettings) {
        repository?.saveCoachingSettings(settings)
    }

    func snoozeCoaching(for hours: Int) {
        var settings = coachingSettings
        settings.snoozedUntil = Date.now.addingTimeInterval(TimeInterval(hours * 3600))
        repository?.saveCoachingSettings(settings)
    }

    private func streamResponse(for message: String, placeholderMessage: SelamMessage) async {
        guard let conversation = currentConversation else {
            isLoading = false
            return
        }

        let context = SelamContext.from(userProgress: progressRepository?.getUserProgress())
        let history =
            messages
            .filter { $0.role != .system && $0.id != placeholderMessage.id }
            .suffix(10)
            .map { SelamHistoryMessage(from: $0) }

        let settings = coachingSettings

        do {
            let stream = aiService.streamMessage(
                message,
                conversationId: conversation.id.uuidString,
                context: context,
                history: Array(history),
                entryContext: entryContext,
                settings: settings
            )

            for try await token in stream {
                if Task.isCancelled { break }

                if let content = token.content {
                    streamingContent += content
                    if let index = messages.firstIndex(where: { $0.id == placeholderMessage.id }) {
                        messages[index].content = streamingContent
                    }
                }

                if token.done {
                    if let index = messages.firstIndex(where: { $0.id == placeholderMessage.id }) {
                        messages[index].isComplete = true
                        if let actions = token.suggestedActions {
                            messages[index].suggestedActions = actions
                        }
                    }

                    repository?.updateMessage(
                        placeholderMessage,
                        content: streamingContent,
                        isComplete: true
                    )
                    placeholderMessage.suggestedActions = token.suggestedActions ?? []
                }
            }
        } catch {
            self.error = error as? SelamError ?? SelamError(error)
            self.showError = true

            if let index = messages.firstIndex(where: { $0.id == placeholderMessage.id }) {
                messages.remove(at: index)
            }
            repository?.deleteMessage(placeholderMessage)
        }

        isLoading = false
        streamingContent = ""
    }

    var suggestedActions: [String] {
        if let lastMessage = messages.last, lastMessage.role == .assistant, lastMessage.isComplete {
            return lastMessage.suggestedActions
        }
        return []
    }
}
