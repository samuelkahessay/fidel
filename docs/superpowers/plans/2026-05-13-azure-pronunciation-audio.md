# Azure Pronunciation Audio Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

Current status: this historical pilot plan has been completed and superseded by the full phrase audio library. The current manifest ships 171 active `am-ET-AmehaNeural` phrase clips and catalogs 171 `am-ET-MekdesNeural` alternates; see `../../audio-asset-library.md`.

**Goal:** Add a manifest-driven Azure-generated pronunciation audio pilot that plays bundled MP3 files offline for selected phrase content.

**Architecture:** Azure is a local content-production dependency only. The app decodes a bundled `audio_manifest.json`, resolves bundle-relative MP3 paths, and exposes generated-audio playback only for content that has a validated bundled clip.

**Tech Stack:** SwiftUI, Swift, AVFoundation, bundled JSON resources, Python 3 standard library for Azure REST generation/validation, XcodeBuildMCP for build/test/simulator verification.

---

## File Structure

- Create `Fidel/Fidel/Models/AudioAsset.swift`: Decodable manifest model and content lookup key.
- Create `Fidel/Fidel/Repositories/AudioAssetRepository.swift`: Loads manifest data, resolves phrase IDs to audio assets, and validates bundle URLs.
- Create `Fidel/Fidel/Services/BundledAudioService.swift`: Small `AVAudioPlayer` wrapper for bundled MP3 playback.
- Create `Fidel/Fidel/Data/audio_manifest.json`: Starts as an empty manifest until Azure files are generated.
- Create `Fidel/Fidel/Audio/phrases/.gitkeep`: Keeps the bundle audio directory available before generated files exist.
- Modify `Fidel/Fidel/Views/ReferenceView.swift`: Add phrase-row playback buttons only when a phrase has audio.
- Modify `Fidel/Fidel/ViewModels/JourneyViewModel.swift`: Hide pronunciation practice when there are not enough bundled phrase audio assets.
- Modify `Fidel/Fidel/Models/AmharicData.swift` and `Fidel/Fidel/Services/AmharicDataLoader.swift`: Expose `audioAssets`.
- Modify `Fidel/Fidel.xcodeproj/project.pbxproj`: Include new Swift files, `audio_manifest.json`, and the audio folder in the app target.
- Create `Fidel/tools/audio/azure_audio_manifest.py`: Build pilot manifest rows from `phrases.json`, validate files, and generate Azure MP3s when credentials are present.
- Modify `Fidel/FidelTests/LocalFirstTests.swift`: Add manifest/repository tests.
- Modify `Fidel/docs/backlog.md`: Move the Azure-generated audio item into completed/active status after implementation.

## Task 1: Add Audio Manifest Model And Empty Manifest

**Files:**
- Create: `Fidel/Fidel/Models/AudioAsset.swift`
- Create: `Fidel/Fidel/Data/audio_manifest.json`
- Modify: `Fidel/Fidel/Services/AmharicDataLoader.swift`
- Modify: `Fidel/Fidel/Models/AmharicData.swift`
- Test: `Fidel/FidelTests/LocalFirstTests.swift`

- [ ] **Step 1: Write the failing tests**

Add these tests near the other bundled-data tests in `Fidel/FidelTests/LocalFirstTests.swift`:

```swift
func testAudioAssetKeyMatchesPhraseContent() {
    let asset = AudioAsset(
        id: "phrase-12",
        contentType: .phrase,
        contentId: "12",
        language: "am-ET",
        provider: "azure",
        voice: "am-ET-MekdesNeural",
        format: "mp3",
        file: "Audio/phrases/phrase-12.mp3",
        text: "አመሰግናለሁ",
        sourceTextHash: "abc123"
    )

    XCTAssertEqual(asset.contentKey, AudioContentKey(contentType: .phrase, contentId: "12"))
}

func testBundledAudioManifestLoads() {
    XCTAssertTrue(AmharicData.audioAssets.allSatisfy { !$0.id.isEmpty && !$0.file.isEmpty })
}
```

- [ ] **Step 2: Run the focused test to verify it fails**

Run: XcodeBuildMCP `test_sim`.

Expected: compile failure because `AudioAsset`, `AudioContentKey`, and `AmharicData.audioAssets` do not exist.

- [ ] **Step 3: Add the model**

Create `Fidel/Fidel/Models/AudioAsset.swift`:

```swift
import Foundation

enum AudioContentType: String, Codable, Hashable {
    case phrase
    case vocabulary
    case conversationLine
    case fidelCharacter
}

struct AudioContentKey: Hashable {
    let contentType: AudioContentType
    let contentId: String
}

struct AudioAsset: Identifiable, Codable, Hashable {
    let id: String
    let contentType: AudioContentType
    let contentId: String
    let language: String
    let provider: String
    let voice: String
    let format: String
    let file: String
    let text: String
    let sourceTextHash: String

    var contentKey: AudioContentKey {
        AudioContentKey(contentType: contentType, contentId: contentId)
    }
}
```

- [ ] **Step 4: Add the empty manifest**

Create `Fidel/Fidel/Data/audio_manifest.json`:

```json
[]
```

- [ ] **Step 5: Wire the manifest through the data loader**

Add to `Fidel/Fidel/Services/AmharicDataLoader.swift` next to the other static JSON properties:

```swift
static let audioAssets: [AudioAsset] = load("audio_manifest")
```

Add to `Fidel/Fidel/Models/AmharicData.swift` next to the other raw data properties:

```swift
static let audioAssets: [AudioAsset] = AmharicDataLoader.audioAssets
```

- [ ] **Step 6: Add files to the Xcode target**

Add `AudioAsset.swift` to the app target sources and `audio_manifest.json` to the app target resources in `Fidel/Fidel.xcodeproj/project.pbxproj`, following the existing patterns for `Models.swift` and `phrases.json`.

- [ ] **Step 7: Run tests**

Run: XcodeBuildMCP `test_sim`.

Expected: tests compile and pass.

- [ ] **Step 8: Commit**

```bash
git -C Fidel add Fidel/Models/AudioAsset.swift Fidel/Data/audio_manifest.json Fidel/Services/AmharicDataLoader.swift Fidel/Models/AmharicData.swift FidelTests/LocalFirstTests.swift Fidel.xcodeproj/project.pbxproj
git -C Fidel commit -m "feat: add audio asset manifest model"
```

## Task 2: Add Repository And Playback Service

**Files:**
- Create: `Fidel/Fidel/Repositories/AudioAssetRepository.swift`
- Create: `Fidel/Fidel/Services/BundledAudioService.swift`
- Test: `Fidel/FidelTests/LocalFirstTests.swift`

- [ ] **Step 1: Write repository tests**

Add to `Fidel/FidelTests/LocalFirstTests.swift`:

```swift
func testAudioAssetRepositoryFindsPhraseAsset() {
    let asset = AudioAsset(
        id: "phrase-12",
        contentType: .phrase,
        contentId: "12",
        language: "am-ET",
        provider: "azure",
        voice: "am-ET-MekdesNeural",
        format: "mp3",
        file: "Audio/phrases/phrase-12.mp3",
        text: "አመሰግናለሁ",
        sourceTextHash: "abc123"
    )
    let repository = AudioAssetRepository(assets: [asset])

    XCTAssertEqual(repository.asset(for: .phrase, contentId: "12"), asset)
    XCTAssertNil(repository.asset(for: .phrase, contentId: "13"))
}
```

- [ ] **Step 2: Run the focused test to verify it fails**

Run: XcodeBuildMCP `test_sim`.

Expected: compile failure because `AudioAssetRepository` does not exist.

- [ ] **Step 3: Add repository**

Create `Fidel/Fidel/Repositories/AudioAssetRepository.swift`:

```swift
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
```

- [ ] **Step 4: Add playback service**

Create `Fidel/Fidel/Services/BundledAudioService.swift`:

```swift
import AVFoundation
import Foundation

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
```

- [ ] **Step 5: Add files to the Xcode target**

Add `AudioAssetRepository.swift` and `BundledAudioService.swift` to the app target sources in `Fidel/Fidel.xcodeproj/project.pbxproj`.

- [ ] **Step 6: Run tests**

Run: XcodeBuildMCP `test_sim`.

Expected: tests pass.

- [ ] **Step 7: Commit**

```bash
git -C Fidel add Fidel/Repositories/AudioAssetRepository.swift Fidel/Services/BundledAudioService.swift FidelTests/LocalFirstTests.swift Fidel.xcodeproj/project.pbxproj
git -C Fidel commit -m "feat: add bundled audio playback boundary"
```

## Task 3: Add Phrase Playback UI Without Misleading Missing-Audio States

**Files:**
- Modify: `Fidel/Fidel/Views/ReferenceView.swift`
- Modify: `Fidel/Fidel/ViewModels/JourneyViewModel.swift`
- Test: `Fidel/FidelTests/LocalFirstTests.swift`

- [ ] **Step 1: Add a Journey gating test**

Add to `Fidel/FidelTests/LocalFirstTests.swift`:

```swift
func testAudioRepositoryRequiresTenPhraseAssetsForPronunciationPractice() {
    let nineAssets = (1...9).map { id in
        AudioAsset(
            id: "phrase-\(id)",
            contentType: .phrase,
            contentId: "\(id)",
            language: "am-ET",
            provider: "azure",
            voice: "am-ET-MekdesNeural",
            format: "mp3",
            file: "Audio/phrases/phrase-\(id).mp3",
            text: "sample",
            sourceTextHash: "hash-\(id)"
        )
    }
    let tenAssets = (1...10).map { id in
        AudioAsset(
            id: "phrase-\(id)",
            contentType: .phrase,
            contentId: "\(id)",
            language: "am-ET",
            provider: "azure",
            voice: "am-ET-MekdesNeural",
            format: "mp3",
            file: "Audio/phrases/phrase-\(id).mp3",
            text: "sample",
            sourceTextHash: "hash-\(id)"
        )
    }

    XCTAssertFalse(AudioAssetRepository(assets: nineAssets).hasPronunciationPracticeContent)
    XCTAssertTrue(AudioAssetRepository(assets: tenAssets).hasPronunciationPracticeContent)
}
```

- [ ] **Step 2: Implement repository gating**

Add to `AudioAssetRepository`:

```swift
var hasPronunciationPracticeContent: Bool {
    phraseAudioCount >= 10
}
```

- [ ] **Step 3: Update phrase rows**

Modify `PhraseReferenceRow` to accept optional audio:

```swift
struct PhraseReferenceRow: View {
    let phrase: Phrase
    let audioAsset: AudioAsset?
    var audioService: BundledAudioService?
    var audioRepository: AudioAssetRepository = .shared
    @State private var isCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(phrase.amharic)
                    .font(AppTheme.Typography.amharic(size: 20))

                Spacer()

                if let audioAsset,
                   let audioService,
                   let url = audioRepository.audioURL(for: audioAsset) {
                    Button {
                        audioService.play(asset: audioAsset, url: url)
                    } label: {
                        Image(systemName: audioService.playingAssetId == audioAsset.id ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                            .foregroundStyle(AppTheme.primaryColor)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Generated pronunciation")
                    .accessibilityHint("Plays generated pronunciation for \(phrase.amharic)")
                }

                Button(action: copyToClipboard) {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .foregroundStyle(isCopied ? AppTheme.successColor : .secondary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(isCopied ? "Copied phrase" : "Copy Amharic phrase")
                .accessibilityHint("Copies \(phrase.amharic) to the clipboard")
            }
            if audioAsset != nil {
                Text("Generated pronunciation")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Text(phrase.transliteration)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Text(phrase.english)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if !phrase.notes.isEmpty {
                    Text("(\(phrase.notes))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(phrase.amharic), \(phrase.transliteration), \(phrase.english)")
        .accessibilityValue(isCopied ? "Copied" : "")
    }
}
```

- [ ] **Step 4: Pass repository/service from `ReferenceView`**

Add properties:

```swift
@State private var audioService = BundledAudioService()
private let audioRepository = AudioAssetRepository.shared
```

Change phrase row construction:

```swift
PhraseReferenceRow(
    phrase: phrase,
    audioAsset: audioRepository.asset(for: phrase),
    audioService: audioService,
    audioRepository: audioRepository
)
```

- [ ] **Step 5: Hide Journey pronunciation activity until enough clips exist**

Add a dependency to `JourneyViewModel`:

```swift
private let audioAssetRepository: AudioAssetRepository

init(
    lessonRepository: LessonRepositoryProtocol = LessonRepository.shared,
    audioAssetRepository: AudioAssetRepository = .shared
) {
    self.lessonRepository = lessonRepository
    self.audioAssetRepository = audioAssetRepository
}
```

Wrap the survival-phrases pronunciation activity:

```swift
if audioAssetRepository.hasPronunciationPracticeContent {
    result.append(JourneyActivity(
        id: "pronunciation_s1",
        type: .practiceMode(.pronunciation),
        title: "Pronunciation Practice",
        subtitle: "Listen to generated pronunciation",
        icon: "waveform",
        color: AppTheme.primaryColor,
        isCompleted: false
    ))
}
```

- [ ] **Step 6: Run tests**

Run: XcodeBuildMCP `test_sim`.

Expected: tests pass.

- [ ] **Step 7: Commit**

```bash
git -C Fidel add Fidel/Views/ReferenceView.swift Fidel/ViewModels/JourneyViewModel.swift Fidel/Repositories/AudioAssetRepository.swift FidelTests/LocalFirstTests.swift
git -C Fidel commit -m "feat: gate generated pronunciation playback"
```

## Task 4: Add Azure Generation And Manifest Validation Tooling

**Files:**
- Create: `Fidel/tools/audio/azure_audio_manifest.py`
- Create: `Fidel/Fidel/Audio/phrases/.gitkeep`

- [ ] **Step 1: Create the audio folder**

```bash
mkdir -p Fidel/Fidel/Audio/phrases
touch Fidel/Fidel/Audio/phrases/.gitkeep
```

- [ ] **Step 2: Add the tool**

Create `Fidel/tools/audio/azure_audio_manifest.py` with:

```python
#!/usr/bin/env python3
import argparse
import hashlib
import json
import os
from pathlib import Path
from urllib import request

PILOT_IDS = [1, 2, 3, 4, 5, 8, 9, 10, 12, 13, 14, 16, 20, 21, 22, 26, 27, 28, 30, 32, 33, 46, 47, 49, 50]
VOICE = "am-ET-MekdesNeural"
LANGUAGE = "am-ET"
OUTPUT_FORMAT = "audio-24khz-48kbitrate-mono-mp3"

def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]

def load_phrases(root: Path) -> list[dict]:
    return json.loads((root / "Fidel" / "Data" / "phrases.json").read_text(encoding="utf-8"))

def source_hash(text: str, voice: str) -> str:
    return hashlib.sha256(f"{LANGUAGE}|{voice}|{OUTPUT_FORMAT}|{text}".encode("utf-8")).hexdigest()

def manifest_row(phrase: dict, voice: str = VOICE) -> dict:
    phrase_id = str(phrase["id"])
    return {
        "id": f"phrase-{phrase_id}",
        "contentType": "phrase",
        "contentId": phrase_id,
        "language": LANGUAGE,
        "provider": "azure",
        "voice": voice,
        "format": "mp3",
        "file": f"Audio/phrases/phrase-{phrase_id}.mp3",
        "text": phrase["amharic"],
        "sourceTextHash": source_hash(phrase["amharic"], voice),
    }

def write_manifest(root: Path, rows: list[dict]) -> None:
    target = root / "Fidel" / "Data" / "audio_manifest.json"
    target.write_text(json.dumps(rows, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

def validate(root: Path, rows: list[dict]) -> list[str]:
    errors = []
    phrases = {str(item["id"]): item for item in load_phrases(root)}
    for row in rows:
        phrase = phrases.get(row["contentId"])
        if phrase is None:
            errors.append(f"{row['id']}: missing phrase {row['contentId']}")
        elif phrase["amharic"] != row["text"]:
            errors.append(f"{row['id']}: text mismatch")
        file_path = root / "Fidel" / row["file"]
        if not file_path.exists():
            errors.append(f"{row['id']}: missing audio file {file_path}")
    return errors

def synthesize(root: Path, rows: list[dict], force: bool) -> None:
    key = os.environ.get("AZURE_SPEECH_KEY")
    region = os.environ.get("AZURE_SPEECH_REGION")
    if not key or not region:
        raise SystemExit("Set AZURE_SPEECH_KEY and AZURE_SPEECH_REGION before generating audio.")
    endpoint = f"https://{region}.tts.speech.microsoft.com/cognitiveservices/v1"
    for row in rows:
        output = root / "Fidel" / row["file"]
        output.parent.mkdir(parents=True, exist_ok=True)
        if output.exists() and not force:
            continue
        ssml = f"""<speak version='1.0' xml:lang='{LANGUAGE}'><voice xml:lang='{LANGUAGE}' name='{row['voice']}'><prosody rate='-8%'>{row['text']}</prosody></voice></speak>"""
        req = request.Request(endpoint, data=ssml.encode("utf-8"), method="POST")
        req.add_header("Ocp-Apim-Subscription-Key", key)
        req.add_header("Content-Type", "application/ssml+xml")
        req.add_header("X-Microsoft-OutputFormat", OUTPUT_FORMAT)
        req.add_header("User-Agent", "FidelAudioGenerator")
        with request.urlopen(req) as response:
            output.write_bytes(response.read())

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write-manifest", action="store_true")
    parser.add_argument("--generate", action="store_true")
    parser.add_argument("--validate", action="store_true")
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    root = repo_root()
    phrases = {item["id"]: item for item in load_phrases(root)}
    rows = [manifest_row(phrases[phrase_id]) for phrase_id in PILOT_IDS]

    if args.write_manifest:
        write_manifest(root, rows)
    if args.generate:
        synthesize(root, rows, args.force)
    if args.validate:
        errors = validate(root, rows)
        if errors:
            raise SystemExit("\n".join(errors))
        print(f"validated {len(rows)} audio rows")

if __name__ == "__main__":
    main()
```

- [ ] **Step 3: Run manifest writing without credentials**

Run:

```bash
python3 Fidel/tools/audio/azure_audio_manifest.py --write-manifest
```

Expected: `Fidel/Fidel/Data/audio_manifest.json` contains 25 rows and no network call is made.

- [ ] **Step 4: Validate before audio generation**

Run:

```bash
python3 Fidel/tools/audio/azure_audio_manifest.py --validate
```

Expected: fails with 25 `missing audio file` lines. This confirms validation catches missing generated files.

- [ ] **Step 5: Commit tooling and manifest rows**

```bash
git -C Fidel add tools/audio/azure_audio_manifest.py Fidel/Audio/phrases/.gitkeep Fidel/Data/audio_manifest.json
git -C Fidel commit -m "feat: add azure audio generation tooling"
```

## Task 5: Generate Azure MP3 Files

**Files:**
- Generate: `Fidel/Fidel/Audio/phrases/phrase-*.mp3`
- Modify: `Fidel/Fidel.xcodeproj/project.pbxproj`

- [ ] **Step 1: Confirm credentials**

Check locally without printing values:

```bash
test -n "$AZURE_SPEECH_KEY" && test -n "$AZURE_SPEECH_REGION"
```

Expected: exit code `0`. If it fails, ask the user to provide an Azure Speech resource key and region, or set them in the shell as:

```bash
export AZURE_SPEECH_KEY="..."
export AZURE_SPEECH_REGION="canadacentral"
```

- [ ] **Step 2: Generate pilot audio**

Run:

```bash
python3 Fidel/tools/audio/azure_audio_manifest.py --generate
```

Expected: 25 MP3 files under `Fidel/Fidel/Audio/phrases/`.

- [ ] **Step 3: Validate generated audio**

Run:

```bash
python3 Fidel/tools/audio/azure_audio_manifest.py --validate
```

Expected: `validated 25 audio rows`.

- [ ] **Step 4: Add audio files to Xcode resources**

Add all `Fidel/Audio/phrases/*.mp3` files to the app target resources in `Fidel/Fidel.xcodeproj/project.pbxproj`.

- [ ] **Step 5: Commit generated audio**

```bash
git -C Fidel add Fidel/Audio/phrases/*.mp3 Fidel.xcodeproj/project.pbxproj
git -C Fidel commit -m "feat: add generated phrase audio pilot"
```

## Task 6: Verify App Behavior

**Files:**
- No source changes expected. If verification fails, inspect the exact failing command and make the smallest targeted fix before rerunning verification.

- [ ] **Step 1: Run tests**

Run: XcodeBuildMCP `test_sim`.

Expected: all tests pass.

- [ ] **Step 2: Build and run**

Run: XcodeBuildMCP `build_run_sim`.

Expected: app builds, installs, and launches.

- [ ] **Step 3: Simulator smoke check**

Use XcodeBuildMCP UI tools:

1. Open Tools or Reference.
2. Navigate to Quick Phrases.
3. Confirm a generated-audio phrase shows a speaker button.
4. Tap the speaker button.
5. Confirm no missing-file error appears and the UI remains responsive.
6. Search for a phrase outside the pilot set.
7. Confirm no misleading play button appears.

- [ ] **Step 4: Commit any verification fix**

If a fix was required, stage only the files changed by that targeted fix and commit them. For example, if only the phrase-row playback code changed:

```bash
git -C Fidel add Fidel/Views/ReferenceView.swift
git -C Fidel commit -m "fix: stabilize generated audio playback"
```

## Task 7: Update Documentation

**Files:**
- Modify: `Fidel/docs/backlog.md`
- Modify: `Fidel/docs/pronunciation-feedback-decision.md`
- Modify: `Fidel/README.md`

- [ ] **Step 1: Update docs to reflect actual shipped scope**

Document:

- 25 generated phrase clips exist.
- Audio is generated by Azure and bundled offline.
- No scoring exists.
- Native recordings remain a future replacement path.

- [ ] **Step 2: Run docs sanity check**

Run:

```bash
rg -n "native pronunciation|TTS/ElevenLabs|tap-to-hear|scored pronunciation" Fidel/README.md Fidel/docs
```

Expected: no stale claims that the app has native pronunciation, live TTS, or scoring.

- [ ] **Step 3: Commit docs**

```bash
git -C Fidel add README.md docs/backlog.md docs/pronunciation-feedback-decision.md
git -C Fidel commit -m "docs: record generated audio pilot"
```

## Credential Boundary

Tasks 1-4 can be completed without Azure credentials. Task 5 requires an Azure Speech resource with billing enabled or free-tier quota available. Never commit `AZURE_SPEECH_KEY`, `.env`, generated local logs containing credentials, or any Azure portal screenshots.

## Completion Checklist

- [ ] `audio_manifest.json` exists and maps 25 phrase IDs to bundled MP3 files.
- [ ] All manifest rows validate against `phrases.json` and existing MP3 files.
- [ ] The app uses bundled MP3 playback, not live Azure calls.
- [ ] Quick Phrases shows generated-audio playback only for phrases with bundled files.
- [ ] Journey does not advertise pronunciation practice before enough bundled clips exist.
- [ ] Tests pass through XcodeBuildMCP.
- [ ] Simulator smoke check confirms playback UI.
- [ ] Docs accurately describe generated audio and avoid native/scoring claims.
