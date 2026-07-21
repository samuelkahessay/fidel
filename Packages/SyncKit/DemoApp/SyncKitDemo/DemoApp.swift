import SwiftUI
import SwiftData
import CloudKit
import SyncKit

@Model
final class Note {
    var syncUUID: String = UUID().uuidString
    var text: String = ""
    var syncModifiedAt: Date = Date.now
    var cloudSystemFields: Data?
    init(text: String = "") { self.text = text }
}

extension Note {
    static let recordType = "Note"
    var syncID: SyncID { SyncID(recordType: Self.recordType, id: syncUUID) }
    func encode(onto record: CKRecord) {
        record["text"] = text
        record[SyncKeys.modifiedAt] = syncModifiedAt as NSDate
        record[SyncKeys.schemaVersion] = 1
    }
    func apply(record: CKRecord) {
        text = record["text"] as? String ?? text
        syncModifiedAt = record[SyncKeys.modifiedAt] as? Date ?? syncModifiedAt
    }
}

@MainActor
final class DemoSyncStore: SyncStore {
    private let context: ModelContext
    init(context: ModelContext) { self.context = context }

    private func find(_ id: SyncID) throws -> Note? {
        let key = id.id
        var d = FetchDescriptor<Note>(predicate: #Predicate { $0.syncUUID == key })
        d.fetchLimit = 1
        return try context.fetch(d).first
    }
    func recordToSave(for id: SyncID, in zoneID: CKRecordZone.ID) throws -> CKRecord? {
        guard let note = try find(id) else { return nil }
        let record = CKRecordFactory.baseRecord(for: id, systemFields: note.cloudSystemFields, zoneID: zoneID)
        note.encode(onto: record)
        return record
    }
    func applyRemoteRecord(_ record: CKRecord) throws -> RemoteApplyResult {
        guard let id = SyncID(recordName: record.recordID.recordName) else { return .applied }
        if let note = try find(id) {
            let remote = record[SyncKeys.modifiedAt] as? Date ?? .distantFuture
            if ConflictResolution.winner(localModifiedAt: note.syncModifiedAt, serverModifiedAt: remote) == .local {
                return .localNewer
            }
            note.apply(record: record)
        } else {
            let note = Note()
            note.syncUUID = id.id
            note.apply(record: record)
            context.insert(note)
        }
        try context.save()
        return .applied
    }
    func applyRemoteDeletion(of id: SyncID) throws {
        if let note = try find(id) { context.delete(note); try context.save() }
    }
    func didSaveRecord(_ record: CKRecord) {
        guard let id = SyncID(recordName: record.recordID.recordName),
              let note = try? find(id) else { return }
        note.cloudSystemFields = CKRecordFactory.systemFieldsData(from: record)
        try? context.save()
    }
    func allSyncIDs() -> [SyncID] {
        ((try? context.fetch(FetchDescriptor<Note>())) ?? []).map(\.syncID)
    }
    func resetAllSystemFields() {
        (try? context.fetch(FetchDescriptor<Note>()))?.forEach { $0.cloudSystemFields = nil }
        try? context.save()
    }
}

@main
struct SyncKitDemoApp: App {
    let container: ModelContainer
    @State private var sync: SyncEngine

    init() {
        let schema = Schema([Note.self])
        let config = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        container = try! ModelContainer(for: schema, configurations: config)
        _sync = State(initialValue: SyncEngine(
            configuration: SyncConfiguration(containerIdentifier: "iCloud.dev.skahessay.synckit-demo",
                                             zoneName: "DemoData"),
            store: DemoSyncStore(context: container.mainContext)))
    }

    var body: some Scene {
        WindowGroup { NotesView().environment(sync) }
            .modelContainer(container)
    }
}

struct NotesView: View {
    @Environment(\.modelContext) private var context
    @Environment(SyncEngine.self) private var sync
    @Query(sort: \Note.syncModifiedAt, order: .reverse) private var notes: [Note]
    @State private var draft = ""

    var body: some View {
        NavigationStack {
            Form {
                SyncSettingsSection(engine: sync)
                Section("Notes") {
                    HStack {
                        TextField("New note", text: $draft)
                        Button("Add") {
                            let note = Note(text: draft)
                            context.insert(note)
                            sync.markPending(note.syncID)
                            draft = ""
                        }.disabled(draft.isEmpty)
                    }
                    ForEach(notes) { note in
                        Text(note.text)
                            .swipeActions {
                                Button("Delete", role: .destructive) {
                                    sync.markPendingDeletion(note.syncID)
                                    context.delete(note)
                                }
                            }
                    }
                }
            }
            .navigationTitle("SyncKit Demo")
        }
    }
}
