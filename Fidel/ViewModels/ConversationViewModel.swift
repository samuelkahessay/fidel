import Foundation

@MainActor
@Observable
final class ConversationViewModel {
    var selectedConversation: Conversation?
    var currentLineIndex = 0
    var isPlaying = false
    var selectedRole: String?

    private let lessonRepository: LessonRepositoryProtocol

    init(lessonRepository: LessonRepositoryProtocol = LessonRepository.shared) {
        self.lessonRepository = lessonRepository
    }

    var conversations: [Conversation] {
        lessonRepository.getConversations()
    }

    var currentLine: Conversation.DialogueLine? {
        guard let conversation = selectedConversation,
              currentLineIndex < conversation.lines.count else { return nil }
        return conversation.lines[currentLineIndex]
    }

    func selectConversation(_ conversation: Conversation) {
        selectedConversation = conversation
        currentLineIndex = 0
        selectedRole = nil
    }

    func nextLine() {
        guard let conversation = selectedConversation else { return }
        if currentLineIndex < conversation.lines.count - 1 {
            currentLineIndex += 1
        }
    }

    func previousLine() {
        if currentLineIndex > 0 {
            currentLineIndex -= 1
        }
    }

    func reset() {
        currentLineIndex = 0
        isPlaying = false
    }

    func getConversation(by id: Int) -> Conversation? {
        lessonRepository.getConversation(by: id)
    }
}
