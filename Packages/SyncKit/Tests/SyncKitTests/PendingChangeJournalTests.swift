import Testing
import Foundation
@testable import SyncKit

@MainActor
struct PendingChangeJournalTests {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("journal-\(UUID().uuidString).json")
    }

    @Test func savesAndDeletesAreMutuallyExclusive() {
        let journal = PendingChangeJournal(fileURL: tempURL())
        let id = SyncID(recordType: "WeightEntry", id: "a")
        journal.recordSave(id)
        #expect(journal.pendingSaves.contains(id))
        journal.recordDelete(id)
        #expect(!journal.pendingSaves.contains(id))
        #expect(journal.pendingDeletes.contains(id))
        journal.recordSave(id)
        #expect(!journal.pendingDeletes.contains(id))
    }

    @Test func persistsAcrossInstances() {
        let url = tempURL()
        let a = SyncID(recordType: "CustomFood", id: "x")
        let b = SyncID(recordType: "FoodUsage", id: "y")
        let first = PendingChangeJournal(fileURL: url)
        first.recordSave(a)
        first.recordDelete(b)
        let second = PendingChangeJournal(fileURL: url)
        #expect(second.pendingSaves == [a])
        #expect(second.pendingDeletes == [b])
    }

    @Test func clearOperationsPersist() {
        let url = tempURL()
        let a = SyncID(recordType: "UserProfile", id: "profile")
        let journal = PendingChangeJournal(fileURL: url)
        journal.recordSave(a)
        journal.clearSave(a)
        #expect(PendingChangeJournal(fileURL: url).pendingSaves.isEmpty)
        journal.recordSave(a)
        journal.clearAll()
        #expect(PendingChangeJournal(fileURL: url).pendingSaves.isEmpty)
    }

    @Test func batchDeletesMoveSavesToDeletesAndPersistOnce() {
        let url = tempURL()
        let a = SyncID(recordType: "WeightEntry", id: "a")
        let b = SyncID(recordType: "FoodLogEntry", id: "b")
        let c = SyncID(recordType: "CustomFood", id: "c")
        let journal = PendingChangeJournal(fileURL: url)
        journal.recordSave(a)

        journal.recordDeletes([a, b, c])

        #expect(journal.pendingSaves.isEmpty)
        #expect(journal.pendingDeletes == [a, b, c])
        // The single batch write must survive relaunch like per-id writes do.
        let reloaded = PendingChangeJournal(fileURL: url)
        #expect(reloaded.pendingSaves.isEmpty)
        #expect(reloaded.pendingDeletes == [a, b, c])
    }

    @Test func emptyOrNoOpBatchDeleteDoesNotPersist() {
        let url = tempURL()
        let a = SyncID(recordType: "WeightEntry", id: "a")
        let journal = PendingChangeJournal(fileURL: url)
        journal.recordDeletes([])
        #expect(!FileManager.default.fileExists(atPath: url.path))
        journal.recordDelete(a)
        let modifiedBefore = try? FileManager.default
            .attributesOfItem(atPath: url.path)[.modificationDate] as? Date
        journal.recordDeletes([a])   // already pending: nothing changed, no write
        let modifiedAfter = try? FileManager.default
            .attributesOfItem(atPath: url.path)[.modificationDate] as? Date
        #expect(modifiedBefore == modifiedAfter)
    }

    @Test func batchSavesMirrorBatchDeletes() {
        let url = tempURL()
        let a = SyncID(recordType: "WeightEntry", id: "a")
        let b = SyncID(recordType: "FoodUsage", id: "b")
        let journal = PendingChangeJournal(fileURL: url)
        journal.recordDeletes([a, b])
        journal.recordSaves([a])
        #expect(journal.pendingSaves == [a])
        #expect(journal.pendingDeletes == [b])
    }

    @Test func corruptJournalStartsEmptyAndPreservesEvidence() throws {
        let url = tempURL()
        let garbage = Data([0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0xFF, 0x42])
        try garbage.write(to: url)

        let journal = PendingChangeJournal(fileURL: url)

        #expect(journal.pendingSaves.isEmpty)
        #expect(journal.pendingDeletes.isEmpty)

        let corruptURL = url.appendingPathExtension("corrupt")
        #expect(FileManager.default.fileExists(atPath: corruptURL.path))
        let preserved = try Data(contentsOf: corruptURL)
        #expect(preserved == garbage)

        // The original path should no longer hold the corrupt bytes (moved aside).
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }
}
