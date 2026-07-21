import Testing
import CloudKit
import Foundation
@testable import SyncKit

@Test func newerLocalWins() {
    let now = Date.now
    #expect(ConflictResolution.winner(localModifiedAt: now,
                                      serverModifiedAt: now.addingTimeInterval(-60)) == .local)
}

@Test func serverWinsTiesAndNewerServer() {
    let now = Date.now
    #expect(ConflictResolution.winner(localModifiedAt: now, serverModifiedAt: now) == .server)
    #expect(ConflictResolution.winner(localModifiedAt: now.addingTimeInterval(-60),
                                      serverModifiedAt: now) == .server)
}

@Test func recordVariantReadsModifiedAtKeyAndDefaultsToServer() {
    let zone = CKRecordZone.ID(zoneName: "ThroughlineData")
    let id = CKRecord.ID(recordName: "WeightEntry_a", zoneID: zone)
    let local = CKRecord(recordType: "WeightEntry", recordID: id)
    let server = CKRecord(recordType: "WeightEntry", recordID: id)
    local[SyncKeys.modifiedAt] = Date.now as CKRecordValue
    server[SyncKeys.modifiedAt] = Date.now.addingTimeInterval(-60) as CKRecordValue
    #expect(ConflictResolution.winner(localRecord: local, serverRecord: server) == .local)

    let bareLocal = CKRecord(recordType: "WeightEntry", recordID: id)
    let bareServer = CKRecord(recordType: "WeightEntry", recordID: id)
    #expect(ConflictResolution.winner(localRecord: bareLocal, serverRecord: bareServer) == .server)
}
