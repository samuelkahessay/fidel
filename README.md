# Fidel — Learn Amharic

Fidel is an iOS app for English speakers learning Amharic, the working language of Ethiopia. It teaches the Ge'ez script (ፊደል, *fidel*) alongside practical vocabulary, phrases, grammar and conversations. Everything runs on the device: no account, no server, no API keys.

Built with SwiftUI and SwiftData for iOS 26.

## What's inside

**Learning path.** Eight lessons (greetings, family, directions, food, time, health, travel, culture) on an open path. Nothing is locked. A recommended next step picks due reviews, then lessons in progress, then new lessons, sized to a daily goal. Fidel characters are taught inside the lessons that use them, and each lesson shows a mastery ring.

**Practice.** Flashcards with FSRS spaced repetition, quizzes (multiple choice and typed), sentence builder, word order, fill the blank, grammar reference, graded reading passages, match pairs, speed drill, pronunciation, and character tracing with stroke-by-stroke feedback.

**Reference.** The full Fidel chart, a phrasebook, vocabulary by category, Ethiopian numbers, months, ordinals and fractions, and cultural notes.

**Selam.** A conversational tutor that runs on Apple's on-device model (Foundation Models). It explains in English and quotes Amharic only from Fidel's own curriculum, through tool calls into the bundled data. It appears only on devices with Apple Intelligence turned on.

**Progress.** XP, streaks with weekly freezes, achievements, optional iCloud sync, and JSON backup and restore.

## Content

All learner-facing content is plain JSON in [`Fidel/Data`](Fidel/Data):

| Content | Count |
|---|---|
| Fidel characters (34 consonants × 7 vowel forms) | 238 |
| Lessons | 8 |
| Grammar patterns (including 12 verb-conjugation tables) | 94 |
| Vocabulary words | 1,038 |
| Phrases | 706 |
| Conversations | 30 |
| Cultural notes | 90 |
| Sentence exercises | 24 |
| Reading passages | 5 |
| Bundled pronunciation clips | 3,320 |

Pronunciation audio was generated with Azure neural voices and is bundled as MP3s in `Fidel/Audio`, indexed by `Fidel/Data/audio_manifest.json`. See [`docs/audio-asset-library.md`](docs/audio-asset-library.md) before changing audio.

## Building

Requirements: Xcode 26 or later and an iOS 26 simulator or device.

1. Clone the repo and open `Fidel.xcodeproj`.
2. Pick an iOS 26 simulator and press Run. No signing team is needed for the simulator.
3. To run on a device, select the **Fidel** target → **Signing & Capabilities**, choose your team, and change the bundle identifier (for example `com.yourname.fidel`).

Run the tests with **Product → Test**, or from the command line:

```bash
xcodebuild test -project Fidel.xcodeproj -scheme Fidel -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO
```

Optional pieces:

- **iCloud sync** uses the CloudKit container `iCloud.dev.skahessay.learnamharic`. For sync in your own build, create a container under your team and update `Fidel/Fidel.entitlements` and `Fidel/FidelRelease.entitlements`. Without it the app runs on local storage.
- **Selam** needs no key. It appears only where Apple Intelligence is available: an Apple Intelligence–capable device, or the simulator on a Mac with Apple Intelligence enabled.

## Project layout

```
Fidel/
├── FidelApp.swift, ContentView.swift   App entry and tab shell
├── Data/          Bundled content (JSON) and audio manifests
├── Audio/         Generated pronunciation MP3s
├── Models/        SwiftData models and content types
├── Repositories/  Content, progress and audio access
├── Services/      Spaced repetition, planning, tracing, audio, Selam
├── Sync/          CloudKit sync store and record mapping
├── ViewModels/    Observable feature state
└── Views/         SwiftUI screens and components
FidelTests/        Unit tests
Packages/SyncKit/  Vendored CloudKit sync engine
```

## Design

Fidel uses a calm, warm palette: terracotta `#B55130`, eucalyptus `#4B7A64` and gold `#CF9A2E` on a paper background (`#F6F0E4`) with dark ink (`#221C16`). Each color has a dark-mode variant in [`Theme.swift`](Fidel/Views/Theme.swift).

## Contributing

Contributions are welcome, especially corrections to Amharic content from native and heritage speakers. See [CONTRIBUTING.md](CONTRIBUTING.md). Planned work is tracked in [`docs/backlog.md`](docs/backlog.md).

## License

Fidel is released under the [MIT License](LICENSE).
