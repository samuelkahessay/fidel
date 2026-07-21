import CloudKit
import Foundation
import os

/// Builds upload-ready base records. When `systemFields` (a previously persisted
/// server change tag) exists, the rebuilt record carries it so CloudKit accepts
/// the save as an update instead of flagging a conflict.
public enum CKRecordFactory {
    private static let logger = Logger(subsystem: "dev.skahessay.SyncKit", category: "recordFactory")

    public static func baseRecord(for id: SyncID, systemFields: Data?, zoneID: CKRecordZone.ID) -> CKRecord {
        if let systemFields {
            guard let coder = try? NSKeyedUnarchiver(forReadingFrom: systemFields) else {
                logger.error("Failed to create unarchiver for system fields of \(id.recordType, privacy: .public)/\(id.recordName, privacy: .public); falling back to a fresh record")
                return CKRecord(recordType: id.recordType, recordID: id.recordID(in: zoneID))
            }
            coder.requiresSecureCoding = true
            if let record = CKRecord(coder: coder) {
                coder.finishDecoding()
                return record
            }
            coder.finishDecoding()
            logger.error("Failed to decode CKRecord from system fields of \(id.recordType, privacy: .public)/\(id.recordName, privacy: .public); falling back to a fresh record")
        }
        return CKRecord(recordType: id.recordType, recordID: id.recordID(in: zoneID))
    }

    public static func systemFieldsData(from record: CKRecord) -> Data {
        let coder = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: coder)
        coder.finishEncoding()
        return coder.encodedData
    }
}
