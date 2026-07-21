import CloudKit

@MainActor
protocol RemoteRecordFetching: AnyObject {
    func record(for recordID: CKRecord.ID) async throws -> CKRecord
}

extension CKDatabase: RemoteRecordFetching {}

struct FailedRemoteRetryOutcome {
    var appliedUpserts: [SyncID] = []
    var appliedDeletions: [SyncID] = []
    var localNewer: [SyncID] = []
    var errors: [String] = []
}

/// Replays server changes whose first local apply failed. Upserts are fetched
/// by ID so CloudKit supplies new CKAsset staging URLs on every retry.
@MainActor
final class FailedRemoteChangeRetrier {
    private let journal: FailedRemoteChangeJournal
    private let store: any SyncStore
    private let zoneID: CKRecordZone.ID

    init(journal: FailedRemoteChangeJournal, store: any SyncStore, zoneID: CKRecordZone.ID) {
        self.journal = journal
        self.store = store
        self.zoneID = zoneID
    }

    func retry(using fetcher: any RemoteRecordFetching) async -> FailedRemoteRetryOutcome {
        var outcome = FailedRemoteRetryOutcome()

        for id in journal.pendingUpserts.sorted(by: { $0.recordName < $1.recordName }) {
            do {
                let record = try await fetcher.record(for: id.recordID(in: zoneID))
                switch try store.applyRemoteRecord(record) {
                case .applied:
                    journal.clearUpsert(id)
                    outcome.appliedUpserts.append(id)
                case .localNewer:
                    store.didSaveRecord(record)
                    journal.clearUpsert(id)
                    outcome.localNewer.append(id)
                }
            } catch let error as CKError where error.code == .unknownItem {
                // The record disappeared after the original change event. A
                // deletion replay is the only state that can now converge.
                journal.recordDeletion(id)
            } catch {
                outcome.errors.append("remote upsert \(id.recordName): \(error.localizedDescription)")
            }
        }

        for id in journal.pendingDeletions.sorted(by: { $0.recordName < $1.recordName }) {
            do {
                try store.applyRemoteDeletion(of: id)
                journal.clearDeletion(id)
                outcome.appliedDeletions.append(id)
            } catch {
                outcome.errors.append("remote deletion \(id.recordName): \(error.localizedDescription)")
            }
        }

        return outcome
    }
}
