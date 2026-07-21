import Testing
import CloudKit
import Foundation
@testable import SyncKit

@Test func attachAssetThrowsWhenFileMissing() throws {
    let record = CKRecord(recordType: "Memo",
                          recordID: .init(recordName: "Memo_a",
                                          zoneID: .init(zoneName: "SonoraData")))
    let missing = FileManager.default.temporaryDirectory
        .appendingPathComponent("nope-\(UUID().uuidString).m4a")
    #expect(throws: SyncAssetError.self) {
        try record.attachAsset(at: missing, forKey: "audio")
    }
}

@Test func attachAndReadBackAssetURL() throws {
    let file = FileManager.default.temporaryDirectory
        .appendingPathComponent("clip-\(UUID().uuidString).m4a")
    try Data([0x01, 0x02]).write(to: file)
    let record = CKRecord(recordType: "Memo",
                          recordID: .init(recordName: "Memo_b",
                                          zoneID: .init(zoneName: "SonoraData")))
    try record.attachAsset(at: file, forKey: "audio")
    #expect(record.stagedAssetURL(forKey: "audio") == file)
    #expect(record.stagedAssetURL(forKey: "missing") == nil)
}
