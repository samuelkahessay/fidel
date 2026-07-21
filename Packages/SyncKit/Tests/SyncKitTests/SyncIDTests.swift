import Testing
import CloudKit
@testable import SyncKit

@Test func recordNameJoinsTypeAndID() {
    let id = SyncID(recordType: "WeightEntry", id: "abc-123")
    #expect(id.recordName == "WeightEntry_abc-123")
}

@Test func parsesRecordNameSplittingOnFirstUnderscore() {
    let id = SyncID(recordName: "FoodUsage_custom_underscore-id")
    #expect(id?.recordType == "FoodUsage")
    #expect(id?.id == "custom_underscore-id")
}

@Test func rejectsMalformedRecordNames() {
    #expect(SyncID(recordName: "NoUnderscore") == nil)
    #expect(SyncID(recordName: "_missingType") == nil)
    #expect(SyncID(recordName: "MissingID_") == nil)
}

@Test func roundTripsThroughCKRecordID() {
    let zone = CKRecordZone.ID(zoneName: "ThroughlineData")
    let id = SyncID(recordType: "CustomFood", id: "custom-1")
    let recordID = id.recordID(in: zone)
    #expect(recordID.zoneID == zone)
    #expect(SyncID(recordName: recordID.recordName) == id)
}
