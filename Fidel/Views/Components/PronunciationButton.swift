import SwiftUI

/// A single speaker button for any learning-content item.
///
/// Resolves a pre-recorded (Azure) clip via `AudioAssetRepository` and plays it through
/// the shared `BundledAudioService`. When no bundled clip exists — vocabulary and
/// conversation lines until their audio is generated, or genuinely dynamic text — it
/// falls back to `AudioService` text-to-speech.
///
/// Services are **injected, never owned**, so a list of buttons shares one player and
/// only one item ever sounds at a time. The owning screen holds the `@State` instances
/// and threads them down; rows must not create their own.
struct PronunciationButton: View {
    /// What this button speaks, and how to find its bundled clip.
    enum Content {
        case phrase(Phrase)
        case vocabulary(VocabularyWord)
        case fidelCharacter(FidelCharacter)
        case conversationLine(conversationId: Int, line: Conversation.DialogueLine)
        /// Text with no stable bundled asset (e.g. a sentence built on the fly). Always TTS.
        case dynamic(amharic: String, transliteration: String?)

        /// The `(type, id)` used to look the bundled clip up. `nil` ⇒ TTS only.
        var lookup: (type: AudioContentType, id: String)? {
            switch self {
            case .phrase(let phrase):
                return (.phrase, "\(phrase.id)")
            case .vocabulary(let word):
                return (.vocabulary, word.id)
            case .fidelCharacter(let character):
                return (.fidelCharacter, character.id)
            case .conversationLine(let conversationId, let line):
                return (.conversationLine, "\(conversationId)-\(line.lineNum)")
            case .dynamic:
                return nil
            }
        }

        var amharic: String {
            switch self {
            case .phrase(let phrase): return phrase.amharic
            case .vocabulary(let word): return word.amharic
            case .fidelCharacter(let character): return character.character
            case .conversationLine(_, let line): return line.amharic
            case .dynamic(let amharic, _): return amharic
            }
        }

        var transliteration: String? {
            switch self {
            case .phrase(let phrase): return phrase.transliteration
            case .vocabulary(let word): return word.transliteration
            case .fidelCharacter(let character): return character.romanization
            case .conversationLine(_, let line): return line.transliteration
            case .dynamic(_, let transliteration): return transliteration
            }
        }
    }

    enum Size {
        case inline  // 44×44, matches the existing phrase/vocab row buttons
        case emphasis  // 88×88 filled circle, for focused single-item screens
    }

    let content: Content
    var size: Size = .inline
    var bundled: BundledAudioService
    var tts: AudioService
    var repository: AudioAssetRepository = .shared

    /// The resolved bundled clip, if one exists and its file is present in the bundle.
    /// `audioURL(for:)` returns nil for a missing file even when a manifest row exists,
    /// so a partial bundle degrades gracefully to TTS instead of a dead button.
    private var resolved: (asset: AudioAsset, url: URL)? {
        guard let lookup = content.lookup,
            let asset = repository.asset(for: lookup.type, contentId: lookup.id),
            let url = repository.audioURL(for: asset)
        else { return nil }
        return (asset, url)
    }

    /// Bundled audio exposes a per-clip `playingAssetId`, so we can light up the exact
    /// button that's sounding. TTS only has a global flag, so TTS buttons stay static.
    private var isPlayingBundled: Bool {
        guard let resolved else { return false }
        return bundled.playingAssetId == resolved.asset.id
    }

    var body: some View {
        Button(action: play) {
            switch size {
            case .inline:
                icon
                    .font(.title3)
                    .foregroundStyle(AppTheme.primaryColor)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            case .emphasis:
                VStack(spacing: AppTheme.Spacing.xxs) {
                    icon
                        .font(.title)
                        .foregroundStyle(AppTheme.onAccentColor)
                    Text(isPlayingBundled ? "Playing" : "Play")
                        .font(.caption)
                        .foregroundStyle(AppTheme.onAccentColor)
                }
                .frame(width: 88, height: 88)
                .background(Circle().fill(AppTheme.primaryColor))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(resolved != nil ? "Play pronunciation" : "Speak \(content.amharic)")
        .accessibilityHint(
            resolved != nil
                ? "Plays the recorded pronunciation"
                : "Speaks \(content.amharic) aloud")
    }

    private var icon: Image {
        Image(systemName: isPlayingBundled ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
    }

    /// Play the bundled clip when one exists, otherwise speak via TTS. Each branch first
    /// stops the *other* service so only one sound is ever audible across both.
    private func play() {
        if let resolved {
            tts.stopPlayback()
            bundled.play(asset: resolved.asset, url: resolved.url)
        } else {
            bundled.stop()
            tts.speakAmharic(content.amharic, transliteration: content.transliteration)
        }
    }
}

#Preview {
    let bundled = BundledAudioService()
    let tts = AudioService()
    return VStack(spacing: 24) {
        PronunciationButton(
            content: .fidelCharacter(
                FidelCharacter(character: "ሀ", consonant: "h", rowIndex: 0, vowelOrder: 1, romanization: "ha", audioHint: "ha")
            ),
            size: .emphasis,
            bundled: bundled,
            tts: tts
        )
        PronunciationButton(
            content: .dynamic(amharic: "ሰላም", transliteration: "selam"),
            bundled: bundled,
            tts: tts
        )
    }
    .padding()
}
