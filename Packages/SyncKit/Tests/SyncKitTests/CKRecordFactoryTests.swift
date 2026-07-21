import Testing
import CloudKit
@testable import SyncKit

@Test func makesFreshRecordWhenNoSystemFields() {
    let zone = CKRecordZone.ID(zoneName: "ThroughlineData")
    let id = SyncID(recordType: "CustomFood", id: "custom-1")
    let record = CKRecordFactory.baseRecord(for: id, systemFields: nil, zoneID: zone)
    #expect(record.recordType == "CustomFood")
    #expect(record.recordID == id.recordID(in: zone))
}

@Test func systemFieldsRoundTripPreservesRecordIdentity() {
    let zone = CKRecordZone.ID(zoneName: "ThroughlineData")
    let id = SyncID(recordType: "WeightEntry", id: "abc")
    let original = CKRecord(recordType: id.recordType, recordID: id.recordID(in: zone))
    original["kg"] = 80.5 as CKRecordValue

    let data = CKRecordFactory.systemFieldsData(from: original)
    let rebuilt = CKRecordFactory.baseRecord(for: id, systemFields: data, zoneID: zone)

    #expect(rebuilt.recordID == original.recordID)
    #expect(rebuilt.recordType == original.recordType)
    // System-fields encoding strips user fields by design.
    #expect(rebuilt["kg"] == nil)
}

@Test func fallsBackToFreshRecordOnCorruptSystemFields() {
    let zone = CKRecordZone.ID(zoneName: "ThroughlineData")
    let id = SyncID(recordType: "FoodUsage", id: "f1")
    let record = CKRecordFactory.baseRecord(for: id, systemFields: Data([0x00, 0x01]), zoneID: zone)
    #expect(record.recordID == id.recordID(in: zone))
}

@Test func fallsBackToFreshRecordWhenArchiveIsNotSystemFields() throws {
    let zone = CKRecordZone.ID(zoneName: "ThroughlineData")
    let id = SyncID(recordType: "FoodUsage", id: "f2")
    let data = try NSKeyedArchiver.archivedData(withRootObject: "not a CKRecord" as NSString, requiringSecureCoding: true)

    let record = CKRecordFactory.baseRecord(for: id, systemFields: data, zoneID: zone)

    #expect(record.recordID == id.recordID(in: zone))
    #expect(record.recordType == id.recordType)
}
