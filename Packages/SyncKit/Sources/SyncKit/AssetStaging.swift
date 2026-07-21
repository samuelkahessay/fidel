import Foundation

/// File staging for CKAsset upload/download. SyncKit never dictates app file
/// layout — apps pass explicit source/destination URLs (an old-Sonora lesson).
public enum AssetStaging {
    @discardableResult
    public static func copyAsset(at sourceURL: URL, to destinationURL: URL) throws -> URL {
        let fm = FileManager.default
        // Same file: nothing to do (the old remove-then-copy would destroy it).
        if sourceURL.standardizedFileURL == destinationURL.standardizedFileURL {
            return destinationURL
        }
        try fm.createDirectory(at: destinationURL.deletingLastPathComponent(),
                               withIntermediateDirectories: true)
        // Copy to a sibling temp file, then swap atomically: an interrupt
        // mid-copy leaves the old destination intact, never a missing file.
        let temp = destinationURL.deletingLastPathComponent()
            .appendingPathComponent("synckit-staging-\(UUID().uuidString)")
        try fm.copyItem(at: sourceURL, to: temp)
        do {
            // Same volume, no replacement options: the replaced item lands exactly at destinationURL.
            _ = try fm.replaceItemAt(destinationURL, withItemAt: temp)
        } catch {
            try? fm.removeItem(at: temp)
            throw error
        }
        return destinationURL
    }
}
