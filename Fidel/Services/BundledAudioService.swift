import AVFoundation
import SwiftUI

@MainActor
@Observable
final class BundledAudioService {
    private var player: AVAudioPlayer?

    var playingAssetId: String?
    var lastError: String?

    func play(asset: AudioAsset, url: URL) {
        stop()
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            player?.play()
            playingAssetId = asset.id
            lastError = nil
        } catch {
            playingAssetId = nil
            lastError = error.localizedDescription
        }
    }

    func stop() {
        player?.stop()
        playingAssetId = nil
    }
}
