import CloudKit

/// Stable, cross-device identity of a synced record.
/// `recordName` convention: "<recordType>_<stableID>". Record types must not contain "_".
public struct SyncID: Hashable, Codable, Sendable {
    public let recordType: String
    public let id: String

    public init(recordType: String, id: String) {
        precondition(!recordType.contains("_"), "record types must not contain underscores")
        self.recordType = recordType
        self.id = id
    }

    public init?(recordName: String) {
        guard let underscore = recordName.firstIndex(of: "_") else { return nil }
        let type = String(recordName[..<underscore])
        let id = String(recordName[recordName.index(after: underscore)...])
        guard !type.isEmpty, !id.isEmpty else { return nil }
        self.recordType = type
        self.id = id
    }

    public var recordName: String { "\(recordType)_\(id)" }

    public func recordID(in zoneID: CKRecordZone.ID) -> CKRecord.ID {
        CKRecord.ID(recordName: recordName, zoneID: zoneID)
    }
}
