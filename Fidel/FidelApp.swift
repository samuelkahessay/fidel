import SwiftUI
import SwiftData

@main
struct FidelApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            UserProgress.self,
            FlashcardProgress.self,
            SelamConversation.self,
            SelamMessage.self,
            CharacterTraceMastery.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task(priority: .utility) {
                    // Warm the 9.7MB stroke database off the main thread so the
                    // first tracing screen doesn't pay the JSON decode.
                    _ = StrokeDataRepository.shared.recordedCharacterIds()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
