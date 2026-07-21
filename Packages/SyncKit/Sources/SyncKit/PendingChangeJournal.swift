import Foundation
import os

/// Relaunch-surviving set of record IDs that need uploading (or deleting server-side).
/// Journals IDs only — record payloads are re-read fresh from the `SyncStore`
/// at send time, so stale snapshots can never be uploaded.
@MainActor
public final class PendingChangeJournal {
    public private(set) var pendingSaves: Set<SyncID> = []
    public private(set) var pendingDeletes: Set<SyncID> = []

    private let fileURL: URL
    private let logger = Logger(subsystem: "dev.skahessay.SyncKit", category: "journal")

    public init(fileURL: URL) {
        self.fileURL = fileURL
        load()
    }

    public func recordSave(_ id: SyncID) {
        pendingDeletes.remove(id)
        pendingSaves.insert(id)
        persist()
    }

    /// Batch variant: one disk write for the whole set. Bulk callers
    /// (imports of thousands of records) must not pay one atomic file
    /// write per record.
    public func recordSaves(_ ids: some Sequence<SyncID>) {
        var changed = false
        for id in ids {
            pendingDeletes.remove(id)
            let (inserted, _) = pendingSaves.insert(id)
            changed = changed || inserted
        }
        if changed { persist() }
    }

    public func recordDelete(_ id: SyncID) {
        pendingSaves.remove(id)
        pendingDeletes.insert(id)
        persist()
    }

    /// Batch variant: one disk write for the whole set. Bulk callers
    /// (erase-all flows deleting thousands of records) must not pay one
    /// atomic file write per record.
    public func recordDeletes(_ ids: some Sequence<SyncID>) {
        var changed = false
        for id in ids {
            pendingSaves.remove(id)
            let (inserted, _) = pendingDeletes.insert(id)
            changed = changed || inserted
        }
        if changed { persist() }
    }

    public func clearSave(_ id: SyncID) {
        pendingSaves.remove(id)
        persist()
    }

    public func clearDelete(_ id: SyncID) {
        pendingDeletes.remove(id)
        persist()
    }

    public func clearAll() {
        pendingSaves = []
        pendingDeletes = []
        persist()
    }

    // MARK: - Persistence

    private struct Snapshot: Codable {
        var saves: [SyncID]
        var deletes: [SyncID]
    }

    private func load() {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            // File missing is the normal first-launch case: start empty, no logging.
            let nsError = error as NSError
            if nsError.domain == NSCocoaErrorDomain, nsError.code == NSFileReadNoSuchFileError {
                return
            }
            logger.error("Failed to read journal at \(self.fileURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return
        }

        do {
            let snapshot = try JSONDecoder().decode(Snapshot.self, from: data)
            pendingSaves = Set(snapshot.saves)
            pendingDeletes = Set(snapshot.deletes)
        } catch {
            logger.error("Failed to decode journal at \(self.fileURL.path, privacy: .public); preserving corrupt file: \(error.localizedDescription, privacy: .public)")
            preserveCorruptFile()
        }
    }

    /// Moves an unreadable/undecodable journal aside so the evidence isn't
    /// destroyed by the next `persist()` overwrite. Replaces any older `.corrupt` file.
    private func preserveCorruptFile() {
        let corruptURL = fileURL.appendingPathExtension("corrupt")
        let fileManager = FileManager.default
        do {
            if fileManager.fileExists(atPath: corruptURL.path) {
                try fileManager.removeItem(at: corruptURL)
            }
            try fileManager.moveItem(at: fileURL, to: corruptURL)
        } catch {
            logger.error("Failed to preserve corrupt journal at \(self.fileURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private func persist() {
        let snapshot = Snapshot(saves: Array(pendingSaves), deletes: Array(pendingDeletes))
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            logger.error("Failed to persist journal at \(self.fileURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}
