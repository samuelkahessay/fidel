import SwiftData
import XCTest

@testable import Fidel___Learn_Amharic

@MainActor
final class SelamViewModelTests: XCTestCase {
    private struct FailingService: SelamAIServiceProtocol {
        func streamMessage(
            _ message: String,
            conversationId: String,
            context: SelamContext,
            history: [SelamHistoryMessage],
            entryContext: SelamEntryContext?,
            settings: SelamCoachingSettings
        ) -> AsyncThrowingStream<SelamStreamToken, Error> {
            AsyncThrowingStream { $0.finish(throwing: SelamError.unavailable) }
        }
    }

    func testFailedReplyLeavesNoEmptyMessageInStore() async throws {
        let schema = Schema([
            UserProgress.self,
            FlashcardProgress.self,
            SelamConversation.self,
            SelamMessage.self,
            CharacterTraceMastery.self,
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)]
        )
        let context = container.mainContext
        let defaults = try XCTUnwrap(UserDefaults(suiteName: #function))
        defaults.removePersistentDomain(forName: #function)

        let repository = SelamRepository(modelContext: context, userDefaults: defaults)
        let viewModel = SelamViewModel(aiService: FailingService())
        viewModel.configure(repository: repository, progressRepository: ProgressRepository(modelContext: context))

        viewModel.inputText = "How do I say water?"
        viewModel.sendMessage()
        while viewModel.isLoading { await Task.yield() }

        XCTAssertTrue(viewModel.showError)
        let stored = try context.fetch(FetchDescriptor<SelamMessage>())
        XCTAssertFalse(
            stored.contains { $0.role == .assistant && !$0.isComplete },
            "a failed reply must not leave an empty assistant bubble behind")
        XCTAssertEqual(viewModel.messages.count, stored.count)
    }
}
