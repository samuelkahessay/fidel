import Foundation
import os

/// Relaunch-surviving IDs for server changes that CKSyncEngine has already
/// acknowledged but the app has not yet applied. Payloads are deliberately not
/// persisted: an upsert retry refetches the record so CKAsset URLs are fresh.
@MainActor
public final class FailedRemoteChangeJournal {
    public private(set) var pendingUpserts: Set<SyncID> = []
    public private(set) var pendingDeletions: Set<SyncID> = []

    private let fileURL: URL
    private let logger = Logger(subsystem: "dev.skahessay.SyncKit", category: "remoteJournal")

    public init(fileURL: URL) {
        self.fileURL = fileURL
        load()
    }

    public func recordUpsert(_ id: SyncID) {
        pendingDeletions.remove(id)
        pendingUpserts.insert(id)
        persist()
    }

    public func recordDeletion(_ id: SyncID) {
        pendingUpserts.remove(id)
        pendingDeletions.insert(id)
        persist()
    }

    public func clearUpsert(_ id: SyncID) {
        guard pendingUpserts.remove(id) != nil else { return }
        persist()
    }

    public func clearDeletion(_ id: SyncID) {
        guard pendingDeletions.remove(id) != nil else { return }
        persist()
    }

    public func clearAll() {
        pendingUpserts.removeAll()
        pendingDeletions.removeAll()
        persist()
    }

    private struct Snapshot: Codable {
        var upserts: [SyncID]
        var deletions: [SyncID]
    }

    private func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            let snapshot = try JSONDecoder().decode(Snapshot.self, from: data)
            pendingUpserts = Set(snapshot.upserts)
            pendingDeletions = Set(snapshot.deletions)
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSCocoaErrorDomain, nsError.code == NSFileReadNoSuchFileError {
                return
            }
            logger.error("Failed to load remote journal at \(self.fileURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            preserveCorruptFile()
        }
    }

    private func preserveCorruptFile() {
        let corruptURL = fileURL.appendingPathExtension("corrupt")
        do {
            if FileManager.default.fileExists(atPath: corruptURL.path) {
                try FileManager.default.removeItem(at: corruptURL)
            }
            try FileManager.default.moveItem(at: fileURL, to: corruptURL)
        } catch {
            logger.error("Failed to preserve remote journal at \(self.fileURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private func persist() {
        do {
            let snapshot = Snapshot(
                upserts: pendingUpserts.sorted { $0.recordName < $1.recordName },
                deletions: pendingDeletions.sorted { $0.recordName < $1.recordName }
            )
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            logger.error("Failed to persist remote journal at \(self.fileURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}
