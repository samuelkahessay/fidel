import CloudKit
import Foundation

/// Field keys every synced record must carry (set by the app's encode step).
public enum SyncKeys {
    public static let modifiedAt = "modifiedAt"
    public static let schemaVersion = "schemaVersion"
}

public enum ConflictWinner: Equatable, Sendable {
    case local
    case server
}

/// Default portfolio policy: last-write-wins on `modifiedAt`, server wins ties
/// (and wins when timestamps are missing — the conservative choice).
public enum ConflictResolution {
    public static func winner(localModifiedAt: Date, serverModifiedAt: Date) -> ConflictWinner {
        localModifiedAt > serverModifiedAt ? .local : .server
    }

    public static func winner(localRecord: CKRecord, serverRecord: CKRecord) -> ConflictWinner {
        let local = localRecord[SyncKeys.modifiedAt] as? Date ?? .distantPast
        let server = serverRecord[SyncKeys.modifiedAt] as? Date ?? .distantFuture
        return winner(localModifiedAt: local, serverModifiedAt: server)
    }
}
