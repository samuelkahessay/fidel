import CloudKit
import Foundation

public enum SyncAssetError: Error, Equatable {
    /// The local file backing an asset is missing — treat as transient
    /// (throw from recordToSave so the journal retries) unless the app
    /// knows the file is permanently gone.
    case missingFile(URL)
}

public extension CKRecord {
    /// Attach a file as a CKAsset. Throws if the file does not exist so
    /// callers can decide between retry (transient) and send-without-asset.
    func attachAsset(at url: URL, forKey key: String) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw SyncAssetError.missingFile(url)
        }
        self[key] = CKAsset(fileURL: url)
    }

    /// The downloaded/staged file URL of an asset field, if present.
    func stagedAssetURL(forKey key: String) -> URL? {
        (self[key] as? CKAsset)?.fileURL
    }
}
