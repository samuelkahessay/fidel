import Foundation

struct AudioAssetRepository {
    static let shared = AudioAssetRepository()

    private let assetsByKey: [AudioContentKey: AudioAsset]
    private let bundle: Bundle
    private let fileExists: (URL) -> Bool

    init(
        assets: [AudioAsset] = AmharicData.audioAssets,
        bundle: Bundle = .main,
        fileExists: @escaping (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }
    ) {
        self.assetsByKey = Dictionary(uniqueKeysWithValues: assets.map { ($0.contentKey, $0) })
        self.bundle = bundle
        self.fileExists = fileExists
    }

    func asset(for contentType: AudioContentType, contentId: String) -> AudioAsset? {
        assetsByKey[AudioContentKey(contentType: contentType, contentId: contentId)]
    }

    func asset(for phrase: Phrase) -> AudioAsset? {
        asset(for: .phrase, contentId: "\(phrase.id)")
    }

    /// Looks up per-word pronunciation audio. Word assets are keyed by the
    /// Amharic text itself under the `.vocabulary` content type (see the
    /// `words` scope in tools/audio/azure_audio_manifest.py).
    func wordAsset(forAmharic amharic: String) -> AudioAsset? {
        asset(for: .vocabulary, contentId: amharic)
    }

    func audioURL(for asset: AudioAsset) -> URL? {
        guard let resourceURL = bundle.resourceURL else { return nil }
        let url = resourceURL.appendingPathComponent(asset.file)
        return fileExists(url) ? url : nil
    }

    var phraseAudioCount: Int {
        assetsByKey.values.filter { $0.contentType == .phrase }.count
    }

    var playablePhraseAudioCount: Int {
        assetsByKey.values.filter { asset in
            asset.contentType == .phrase && audioURL(for: asset) != nil
        }.count
    }

    var hasPronunciationPracticeContent: Bool {
        playablePhraseAudioCount >= 10
    }
}
