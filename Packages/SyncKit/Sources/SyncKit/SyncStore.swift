import CloudKit

public enum RemoteApplyResult: Equatable, Sendable {
    /// Remote values were written into the local store.
    case applied
    /// Local copy was newer (LWW); engine should re-queue an upload.
    case localNewer
}

/// App-side persistence bridge. SyncKit stays ignorant of SwiftData;
/// conformances translate between CKRecords and the app's models.
@MainActor
public protocol SyncStore: AnyObject {
    /// Fresh read at send time. Return nil if the record no longer exists locally
    /// (SyncKit drops it from the outgoing batch AND clears its journal entry).
    /// THROW for transient failures (asset file unreadable, store fetch error):
    /// the record is dropped from this batch but its journal entry is retained,
    /// so the next sync retries it.
    func recordToSave(for id: SyncID, in zoneID: CKRecordZone.ID) throws -> CKRecord?

    /// Upsert remote values. Compare `record[SyncKeys.modifiedAt]` against the
    /// local copy (use `ConflictResolution`) and return `.localNewer` to keep
    /// local values; SyncKit then re-queues the record for upload.
    func applyRemoteRecord(_ record: CKRecord) throws -> RemoteApplyResult

    func applyRemoteDeletion(of id: SyncID) throws

    /// Persist `CKRecordFactory.systemFieldsData(from: record)` on the matching
    /// model. MUST NOT modify user-visible fields.
    func didSaveRecord(_ record: CKRecord)

    /// Every synced record currently in the local store.
    func allSyncIDs() throws -> [SyncID]

    /// Account-merge flow: wipe stored system fields so records upload as new.
    func resetAllSystemFields() throws
}
