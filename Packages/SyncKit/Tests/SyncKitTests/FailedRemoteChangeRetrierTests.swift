import CloudKit
import Foundation
import Testing
@testable import SyncKit

@MainActor
private final class RetrierStore: SyncStore {
    enum Failure: Error { case apply }

    var shouldFailUpsert = false
    var shouldFailDeletion = false
    var result: RemoteApplyResult = .applied
    var appliedRecords: [CKRecord] = []
    var deletedIDs: [SyncID] = []

    func recordToSave(for id: SyncID, in zoneID: CKRecordZone.ID) throws -> CKRecord? { nil }

    func applyRemoteRecord(_ record: CKRecord) throws -> RemoteApplyResult {
        if shouldFailUpsert { throw Failure.apply }
        appliedRecords.append(record)
        return result
    }

    func applyRemoteDeletion(of id: SyncID) throws {
        if shouldFailDeletion { throw Failure.apply }
        deletedIDs.append(id)
    }

    func didSaveRecord(_ record: CKRecord) {}
    func allSyncIDs() -> [SyncID] { [] }
    func resetAllSystemFields() {}
}

@MainActor
private final class RetrierFetcher: RemoteRecordFetching {
    var records: [CKRecord.ID: CKRecord] = [:]
    var requestedIDs: [CKRecord.ID] = []

    func record(for recordID: CKRecord.ID) async throws -> CKRecord {
        requestedIDs.append(recordID)
        guard let record = records[recordID] else {
            throw NSError(domain: CKErrorDomain, code: CKError.Code.unknownItem.rawValue)
        }
        return record
    }
}

@MainActor
struct FailedRemoteChangeRetrierTests {
    private func journal() -> FailedRemoteChangeJournal {
        FailedRemoteChangeJournal(
            fileURL: FileManager.default.temporaryDirectory
                .appending(path: "retrier-\(UUID().uuidString).json")
        )
    }

    @Test func failedUpsertSurvivesThenRefetchesFreshRecord() async {
        let zone = CKRecordZone.ID(zoneName: "SonoraData")
        let id = SyncID(recordType: "Memo", id: "asset")
        let remoteJournal = journal()
        remoteJournal.recordUpsert(id)
        let store = RetrierStore()
        store.shouldFailUpsert = true
        let fetcher = RetrierFetcher()
        let firstRecord = CKRecord(recordType: id.recordType, recordID: id.recordID(in: zone))
        firstRecord["generation"] = 1 as CKRecordValue
        fetcher.records[firstRecord.recordID] = firstRecord
        let retrier = FailedRemoteChangeRetrier(journal: remoteJournal, store: store, zoneID: zone)

        let failed = await retrier.retry(using: fetcher)
        #expect(failed.errors.count == 1)
        #expect(remoteJournal.pendingUpserts == [id])

        store.shouldFailUpsert = false
        let freshRecord = CKRecord(recordType: id.recordType, recordID: id.recordID(in: zone))
        freshRecord["generation"] = 2 as CKRecordValue
        fetcher.records[freshRecord.recordID] = freshRecord
        let succeeded = await retrier.retry(using: fetcher)

        #expect(succeeded.appliedUpserts == [id])
        #expect(remoteJournal.pendingUpserts.isEmpty)
        #expect(store.appliedRecords.last?["generation"] as? Int64 == 2)
        #expect(fetcher.requestedIDs.count == 2)
    }

    @Test func failedDeletionSurvivesRestartAndReplaysLocally() async {
        let zone = CKRecordZone.ID(zoneName: "FidelData")
        let id = SyncID(recordType: "UserProgress", id: "local")
        let url = FileManager.default.temporaryDirectory
            .appending(path: "retrier-delete-\(UUID().uuidString).json")
        let firstJournal = FailedRemoteChangeJournal(fileURL: url)
        firstJournal.recordDeletion(id)
        let store = RetrierStore()
        store.shouldFailDeletion = true
        let firstRetrier = FailedRemoteChangeRetrier(journal: firstJournal, store: store, zoneID: zone)

        let failed = await firstRetrier.retry(using: RetrierFetcher())
        #expect(failed.errors.count == 1)
        #expect(firstJournal.pendingDeletions == [id])

        store.shouldFailDeletion = false
        let restartedJournal = FailedRemoteChangeJournal(fileURL: url)
        let restartedRetrier = FailedRemoteChangeRetrier(journal: restartedJournal, store: store, zoneID: zone)
        let succeeded = await restartedRetrier.retry(using: RetrierFetcher())

        #expect(succeeded.appliedDeletions == [id])
        #expect(restartedJournal.pendingDeletions.isEmpty)
        #expect(store.deletedIDs == [id])
    }

    @Test func unknownRemoteItemConvergesThroughDeletionReplay() async {
        let zone = CKRecordZone.ID(zoneName: "RallyIQData")
        let id = SyncID(recordType: "RacquetBuild", id: "gone")
        let remoteJournal = journal()
        remoteJournal.recordUpsert(id)
        let store = RetrierStore()
        let retrier = FailedRemoteChangeRetrier(journal: remoteJournal, store: store, zoneID: zone)

        let outcome = await retrier.retry(using: RetrierFetcher())

        #expect(outcome.errors.isEmpty)
        #expect(remoteJournal.pendingUpserts.isEmpty)
        #expect(remoteJournal.pendingDeletions.isEmpty)
        #expect(store.deletedIDs == [id])
    }
}
