import SwiftUI
import SwiftData
import SyncKit
import os

@main
struct FidelApp: App {
    @Environment(\.scenePhase) private var scenePhase

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
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none  // entitlement flips the default to .automatic mirroring; SyncKit owns sync
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    // Synced models key on natural ids (ownerUserId, or ownerUserId + itemId /
    // characterId) rather than a generated syncUUID, so there is no migration
    // trap and no backfill pass needed here: every existing local record
    // already carries the identity CloudKit will use.
    @State private var syncEngine: SyncEngine

    private static let logger = Logger(subsystem: "dev.skahessay.learnamharic", category: "sync")
    private static let syncBootstrapVersionKey = "Fidel.syncBootstrapVersion"
    private static let currentSyncBootstrapVersion = 1

    init() {
        let syncStore = FidelSyncStore(context: sharedModelContainer.mainContext)
        let engine = SyncEngine(
            configuration: SyncConfiguration(
                containerIdentifier: "iCloud.dev.skahessay.learnamharic",
                zoneName: "FidelData"),
            store: syncStore)
        _syncEngine = State(initialValue: engine)

        // Existing installs may already carry SyncKit's generic first-enable
        // receipt from a staging build. Run a Fidel-owned migration once so
        // every durable pre-upgrade record is enqueued for the new schema.
        if UserDefaults.standard.integer(forKey: Self.syncBootstrapVersionKey)
            < Self.currentSyncBootstrapVersion {
            do {
                engine.markPending(try syncStore.allSyncIDs())
                UserDefaults.standard.set(
                    Self.currentSyncBootstrapVersion,
                    forKey: Self.syncBootstrapVersionKey
                )
                engine.syncNow()
            } catch {
                Self.logger.error("Fidel sync bootstrap failed: \(error, privacy: .public)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(syncEngine)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        syncEngine.appDidBecomeActive()
                    }
                }
                .task(priority: .utility) {
                    // Warm the 9.7MB stroke database off the main thread so the
                    // first tracing screen doesn't pay the JSON decode.
                    _ = StrokeDataRepository.shared.recordedCharacterIds()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
