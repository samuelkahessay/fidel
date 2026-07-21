import Foundation
import Testing
@testable import SyncKit

@MainActor
struct FailedRemoteChangeJournalTests {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "remote-journal-\(UUID().uuidString).json")
    }

    @Test func upsertsAndDeletionsPersistAcrossRestart() {
        let url = tempURL()
        let upsert = SyncID(recordType: "Memo", id: "a")
        let deletion = SyncID(recordType: "Memo", id: "b")

        let first = FailedRemoteChangeJournal(fileURL: url)
        first.recordUpsert(upsert)
        first.recordDeletion(deletion)

        let restarted = FailedRemoteChangeJournal(fileURL: url)
        #expect(restarted.pendingUpserts == [upsert])
        #expect(restarted.pendingDeletions == [deletion])
    }

    @Test func newestRemoteOperationWinsForOneID() {
        let journal = FailedRemoteChangeJournal(fileURL: tempURL())
        let id = SyncID(recordType: "Memo", id: "same")

        journal.recordUpsert(id)
        journal.recordDeletion(id)
        #expect(journal.pendingUpserts.isEmpty)
        #expect(journal.pendingDeletions == [id])

        journal.recordUpsert(id)
        #expect(journal.pendingUpserts == [id])
        #expect(journal.pendingDeletions.isEmpty)
    }

    @Test func failedEntriesClearOnlyAfterExplicitSuccess() {
        let url = tempURL()
        let id = SyncID(recordType: "Memo", id: "retry")
        let journal = FailedRemoteChangeJournal(fileURL: url)
        journal.recordUpsert(id)

        #expect(FailedRemoteChangeJournal(fileURL: url).pendingUpserts == [id])
        journal.clearUpsert(id)
        #expect(FailedRemoteChangeJournal(fileURL: url).pendingUpserts.isEmpty)
    }
}
