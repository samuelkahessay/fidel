import Foundation

struct AudioAssetRepository {
    static let shared = AudioAssetRepository()

    private let assetsByKey: [AudioContentKey: AudioAsset]

    init(assets: [AudioAsset] = AmharicData.audioAssets) {
        self.assetsByKey = Dictionary(uniqueKeysWithValues: assets.map { ($0.contentKey, $0) })
    }

    func asset(for contentType: AudioContentType, contentId: String) -> AudioAsset? {
        assetsByKey[AudioContentKey(contentType: contentType, contentId: contentId)]
    }

    func asset(for phrase: Phrase) -> AudioAsset? {
        asset(for: .phrase, contentId: "\(phrase.id)")
    }

    func audioURL(for asset: AudioAsset, bundle: Bundle = .main) -> URL? {
        guard let resourceURL = bundle.resourceURL else { return nil }
        let url = resourceURL.appendingPathComponent(asset.file)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    var phraseAudioCount: Int {
        assetsByKey.values.filter { $0.contentType == .phrase }.count
    }
}
