# Azure Pronunciation Audio Design

Date: 2026-05-13

## Decision

Add pronunciation/audio through an Azure-generated offline asset pipeline. Azure is used only during content production to synthesize MP3 files from the app's existing Amharic text. The iOS app bundles and plays those files locally; it does not ship an Azure key, call Azure at runtime, or require network access for audio playback.

The first shipped scope is a 25-phrase pilot from `Fidel/Data/phrases.json`. Do not generate all vocabulary, all conversations, or all Fidel characters until the pilot proves quality, bundle size, UX, and review workflow.

## Why Azure

Azure is the strongest synthetic option found for Amharic because it explicitly lists Amharic text-to-speech voices:

- `am-ET-MekdesNeural` (female)
- `am-ET-AmehaNeural` (male)

Other checked options were weaker for this goal:

- Apple system speech is not a dependable Amharic source; Apple VoiceOver supported-language documentation does not list Amharic.
- Google Cloud Text-to-Speech and Amazon Polly do not list Amharic in their supported voice/language tables.
- ElevenLabs' documented multilingual TTS language lists do not include Amharic.
- OpenAI TTS language support does not list Amharic, even though it can generate audio for many languages.
- Common Voice and WAXAL are useful research datasets, but they are not a direct app-ready source of phrase pronunciation audio.

## Product Principles

- Use the Amharic script as the synthesis input, not transliteration.
- Treat generated speech as a pronunciation aid, not as native-speaker proof.
- Disclose synthetic audio subtly in the app, for example `Generated pronunciation`.
- Keep the app local-first: audio is bundled and playable offline.
- Keep a manifest-driven architecture so native-speaker recordings can replace generated clips later without changing UI code.
- Do not add pronunciation scoring in this work. Azure pronunciation assessment does not list Amharic.

## Pilot Content

Use the first pilot for high-value survival phrases already in `phrases.json`. Prefer complete phrases that do not contain placeholders.

Initial candidate set:

| ID | English | Amharic |
| ---: | --- | --- |
| 1 | Hello | ጤና ይስጥልኝ |
| 2 | How are you? | እንደምን ነህ? |
| 3 | How are you? | እንደምን ነሽ? |
| 4 | How are you? | እንደምን ነዎት? |
| 5 | I'm fine | ደህና ነኝ |
| 8 | Goodbye | ደህና ሁን |
| 9 | Goodbye | ደህና ሁኝ |
| 10 | Goodbye | ደህና ይዋሉ |
| 12 | Thank you | አመሰግናለሁ |
| 13 | You're welcome | ምንም አይደለም |
| 14 | Excuse me / Sorry | ይቅርታ |
| 16 | What's your name? | ስምህ ማነው? |
| 20 | Where is it? | የት ነው? |
| 21 | What is this? | ይህ ምን ነው? |
| 22 | How much is it? | ምን ያህል ነው? |
| 26 | Yes | አዎ |
| 27 | No | አይ |
| 28 | OK / Alright | እሺ |
| 30 | I don't understand | አልገባኝም |
| 32 | I want coffee | ቡና እፈልጋለሁ |
| 33 | I want water | ውሃ እፈልጋለሁ |
| 46 | Help! | እርዳታ! |
| 47 | I need a doctor | ዶክተር ፈልጋለሁ |
| 49 | Where is the hospital? | ሆስፒታል የት ነው? |
| 50 | I don't speak Amharic | አማርኛ አልችልም |

Skip placeholder phrases such as `[name]`, `[country]`, and `[place]` in the first pass unless they are replaced with concrete example phrases.

## Audio Manifest

Add a bundled manifest at `Fidel/Data/audio_manifest.json`.

Suggested row shape:

```json
{
  "id": "phrase-1",
  "contentType": "phrase",
  "contentId": "1",
  "language": "am-ET",
  "provider": "azure",
  "voice": "am-ET-MekdesNeural",
  "format": "mp3",
  "file": "Audio/phrases/phrase-1.mp3",
  "text": "ጤና ይስጥልኝ",
  "sourceTextHash": "sha256-of-text-and-voice"
}
```

Rules:

- `contentType` starts with `phrase`; later values can include `vocabulary`, `conversationLine`, and `fidelCharacter`.
- `contentId` maps to the existing JSON item ID.
- `file` is a bundle-relative path.
- `sourceTextHash` changes when the input text, voice, or generation settings change, so stale files can be detected.
- The manifest is the only app-facing map from content to audio files.

## Generation Workflow

Add a local script, for example `tools/audio/generate_azure_audio.py`, that:

1. Reads a review manifest or a selected list of phrase IDs.
2. Pulls Amharic text from `Fidel/Data/phrases.json`.
3. Calls Azure Speech Text-to-Speech using `AZURE_SPEECH_KEY` and `AZURE_SPEECH_REGION` from the local environment.
4. Generates both `am-ET-MekdesNeural` and `am-ET-AmehaNeural` for a small audition batch.
5. Saves reviewed pilot files as MP3 under `Fidel/Audio/phrases/`.
6. Writes `Fidel/Data/audio_manifest.json`.
7. Refuses to overwrite existing reviewed files unless `--force` is passed.

Use MP3 output for the pilot. Azure's REST API supports MP3 output formats such as `audio-24khz-48kbitrate-mono-mp3`; this is a good bundle-size/quality starting point.

## iOS App Changes

Add these app boundaries:

- `AudioAsset` model: decodes one manifest row.
- `AudioAssetRepository`: loads `audio_manifest.json`, resolves bundle URLs, and answers whether a given phrase has audio.
- `AudioPlaybackService`: plays bundled audio via `AVAudioPlayer`.

Refactor existing audio behavior:

- Remove live ElevenLabs/Azure runtime assumptions from learner-facing playback.
- Prefer bundled audio when present.
- If audio is missing, hide the play button or show a disabled state that does not imply audio exists.
- Split local learner recording out of the first audio pilot. If it returns later, add `NSMicrophoneUsageDescription` to `Info.plist` before exposing recording controls.

Update UI copy:

- Use `Generated pronunciation` as the learner-facing label.
- Avoid `native pronunciation` for Azure-generated clips.
- Keep pronunciation practice out of early stages unless enough clips exist for that mode.

## Validation

Before shipping the pilot:

- Run a manifest validator that checks every manifest row has a matching app content item and bundle file.
- Verify all referenced MP3 files are included in the Xcode resources build phase.
- Build with XcodeBuildMCP.
- Run the existing test suite with XcodeBuildMCP.
- Simulator smoke test:
  - A phrase with audio shows a play control.
  - Tapping play produces playback without network access.
  - A phrase without audio does not present misleading audio UI.
  - Pronunciation UI uses generated-audio copy, not native-audio copy.

## Future Upgrade Path

Native-speaker recordings can replace Azure-generated MP3s by keeping the same manifest IDs and changing:

- `provider`
- `voice`
- `file`
- `sourceTextHash`

The app should not care whether the audio came from Azure or a native recording, as long as the manifest row and bundled file are valid.

## Sources Checked

- Azure language support: Amharic TTS voices and STT support are listed for `am-ET`; Amharic is not listed in pronunciation assessment.
- Azure Text-to-Speech REST API: supports MP3 output formats through `X-Microsoft-OutputFormat`.
- Azure Text-to-Speech transparency note: calls out disclosure, editorial control, and possible pronunciation/intonation errors.
- Apple VoiceOver supported languages: Amharic is not listed.
- Google Cloud Text-to-Speech supported voices: no `am-ET` entry found.
- Amazon Polly supported languages: no Amharic entry found.
- ElevenLabs documented TTS language lists: Amharic is not listed.
- OpenAI TTS supported languages: Amharic is not listed.

## Voice Audition Before Full Generation

Choose the default Azure voice after auditioning `Mekdes` and `Ameha` on 5-10 sample phrases. If there is no clear winner, use `am-ET-MekdesNeural` for the first 25-phrase pilot because it is the female Amharic voice and the existing app content does not currently model speaker gender.
