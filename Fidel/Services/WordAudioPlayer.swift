import SwiftUI

/// Plays the pronunciation of a single Amharic word for tappable word tiles.
///
/// Prefers the pre-generated, bundled Azure clip (the production path — release
/// builds ship no client TTS keys); when a word has no bundled clip it falls
/// back to on-device synthesis via `AudioService`. The fallback service is
/// created lazily so the heavier `playAndRecord` audio session is only
/// configured if it is actually needed.
@MainActor
@Observable
final class WordAudioPlayer {
    private let bundled = BundledAudioService()
    private let repository: AudioAssetRepository
    private var fallback: AudioService?
    private var clearTask: Task<Void, Never>?

    /// The Amharic word currently sounding, for a transient tile highlight.
    var speakingWord: String?

    init(repository: AudioAssetRepository = .shared) {
        self.repository = repository
    }

    /// Plays `amharic`, preferring the bundled clip and otherwise synthesizing.
    func play(_ amharic: String) {
        speakingWord = amharic

        if let asset = repository.wordAsset(forAmharic: amharic),
           let url = repository.audioURL(for: asset) {
            bundled.play(asset: asset, url: url)
        } else {
            ensureFallback().speakAmharic(amharic)
        }

        // Clear the highlight shortly after; word clips are brief.
        clearTask?.cancel()
        clearTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            if self?.speakingWord == amharic { self?.speakingWord = nil }
        }
    }

    func isSpeaking(_ amharic: String) -> Bool {
        speakingWord == amharic
    }

    func stop() {
        clearTask?.cancel()
        bundled.stop()
        fallback?.stopPlayback()
        speakingWord = nil
    }

    private func ensureFallback() -> AudioService {
        if let fallback { return fallback }
        let service = AudioService()
        fallback = service
        return service
    }
}
