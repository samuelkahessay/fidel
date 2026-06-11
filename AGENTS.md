# Fidel - Codex Instructions

## Project Overview

Fidel is a local-first Amharic learning iOS app built with SwiftUI, SwiftData, MVVM, repositories, and local JSON content. The iOS repo is the product source of truth for app code and learner-facing bundled content.

Before starting consolidation, import, release, or large refactor work, read:

- `docs/README.md`
- `docs/backlog.md`
- `docs/status/fidel-group-audit.md`
- `docs/audio-asset-library.md` if the task touches generated pronunciation audio
- `Fidel_local_first_plan.md` if the task touches local-first behavior, auth removal, backup/restore, or release history

## Current Content Scope

- 238 Fidel characters
- 8 structured lessons
- 30 sentence patterns
- 24 conversations
- 174 phrases
- 436 vocabulary entries
- 20 cultural notes
- 4 numeric reference groups
- 238 stroke recordings
- 171 active Azure-generated phrase pronunciation clips in `Fidel/Data/audio_manifest.json`
- 342 generated phrase pronunciation clips in `Fidel/Data/audio_catalog.json` across active and alternate voices

## Product Boundaries

- Keep Fidel local-first. Do not reintroduce sign-in, CloudKit, remote notification, or account-gated launch behavior unless the user explicitly reopens that product decision.
- Azure is a content-production dependency only. The app must not ship Azure keys, call Azure at runtime, or require network access for pronunciation playback.
- The app-facing audio source is `Fidel/Data/audio_manifest.json`. It must contain at most one active row per `contentType` and `contentId`; use `audio_catalog.json` for alternate/generated clips that are not the default learner-facing asset.
- Do not bulk-import resource or phrasebook content directly into app JSON. Use the de-dupe reports, import schema, and rights notes first.
- The static PWA under `../Fidel_Resources/amharic/web_app/` is archival/reference material unless the user starts a separate web companion plan.
- The landing site lives in `../FidelWeb/`; keep marketing counts aligned with the iOS app.

## Architecture Map

```text
Fidel/
├── Fidel.xcodeproj
├── Fidel/
│   ├── ContentView.swift
│   ├── FidelApp.swift
│   ├── Data/              # Bundled learner content JSON
│   ├── Audio/             # Voice-scoped generated pronunciation MP3s
│   ├── Models/            # Domain and SwiftData models
│   ├── Repositories/      # Content/progress repository boundaries
│   ├── Services/          # Bundled audio, progress export, stage, stroke, and spaced repetition services
│   ├── ViewModels/        # Observable feature state
│   └── Views/             # SwiftUI screens and shared components
├── FidelTests/
└── docs/
    └── status/            # Durable group/consolidation status
```

## Navigation

The current bottom tab bar is:

1. Today: daily focus, phrase preview, local progress summary, and quick paths.
2. Learn: stage-gated lesson progression and the core Journey path.
3. Practice: flashcards, quiz, pronunciation, sentence builder, speed drill, and tracing.
4. Selam: tutor chat.
5. You: XP, streaks, achievements, backup/restore, and statistics.

Reference is not a bottom tab. It is opened from `Today > Quick paths > Reference`; it defaults to Quick Phrases and includes speaker buttons for phrases with active bundled audio.

Pronunciation audio is user-facing in:

- `Practice > Pronunciation`
- eligible Learn/Journey activity cards once pronunciation practice is unlocked and enough bundled clips exist
- `Reference > Quick Phrases` rows with a `Generated pronunciation` speaker button

## Learning Stages

| Stage | Name | Notes |
| --- | --- | --- |
| 0 | Script & Sounds (ፊደል) | Starting stage; Fidel chart is available from the beginning. |
| 1 | Survival Phrases (ሰላምታ) | Unlocks after recognizing 50+ Fidel characters. |
| 2 | Building Sentences (ዓረፍተ ነገር) | Unlocks after Lessons 1 and 2 plus 30+ vocabulary words. |
| 3 | Fluency (ብቃት) | Unlocks after core lessons 1-5, 100+ vocabulary words, and 5+ conversations. |

## Working Rules

- Preserve unrelated dirty work. The current repo often has active SwiftUI edits in progress.
- Keep docs/status changes separate from product UI changes when possible.
- Use the app JSON counts as the source of truth before updating marketing or status docs.
- Use `docs/audio-asset-library.md` and `tools/audio/azure_audio_manifest.py` for audio manifest/catalog changes.
- Keep pronunciation UI copy honest: use `Generated pronunciation`, not native-speaker wording, for Azure clips.
- Keep source assets, generated artifacts, local screenshots, and archive files out of app source unless there is a deliberate product reason.
- Prefer small, verifiable commits with only task-relevant files staged.

## Building & Testing

Always prefer XcodeBuildMCP tools for building and testing this project. Do not use raw `xcodebuild` from shell unless the user explicitly asks for a fallback.

Session defaults:

- Project path: `Fidel.xcodeproj`
- Scheme: `Fidel`
- Simulator: `iPhone 17 Pro`
- `useLatestOS`: `true`
- `suppressWarnings`: `true`

Common operations:

- Build: `build_sim`
- Run: `build_run_sim`
- Test: `test_sim`
- Device build: `build_device`

## ASC/Xcode Cloud Release Access

- Fidel's App Store Connect app ID is `6758070348`, bundle ID is `dev.skahessay.learnamharic`, and the Xcode Cloud workflow that runs from `main` is `Default` (`B307BED0-021D-4C68-83D8-8B15B0BD7C7D`).
- In non-interactive Codex shells, prefer the file-backed ASC credential fallback:
  ```bash
  ASC_KEY_ID=$(jq -r '.keychain_metadata[] | select(.name=="Fidel") | .key_id' "$HOME/.asc/config.json")
  ASC_ISSUER_ID=$(jq -r '.keychain_metadata[] | select(.name=="Fidel") | .issuer_id' "$HOME/.asc/config.json")
  ASC_PRIVATE_KEY_PATH="$HOME/.appstoreconnect/AuthKey_${ASC_KEY_ID}.p8"
  ASC_BYPASS_KEYCHAIN=1 \
  ASC_KEY_ID="$ASC_KEY_ID" \
  ASC_ISSUER_ID="$ASC_ISSUER_ID" \
  ASC_PRIVATE_KEY_PATH="$ASC_PRIVATE_KEY_PATH" \
    /opt/homebrew/bin/asc xcode-cloud build-runs \
      --workflow-id B307BED0-021D-4C68-83D8-8B15B0BD7C7D \
      --sort -number --limit 5 --output table
  ```
- Use the same environment prefix for `asc apps`, `asc builds`, and `asc xcode-cloud run/status` commands when driving TestFlight.
- `ci_scripts/ci_post_xcodebuild.sh` is the default Xcode Cloud hook that attaches the just-built TestFlight build to the internal `Internal Testing` group (`4695043c-f536-493b-abd4-c4925bda6154`). It runs on archive actions only, waits for the build to reach `processingState=VALID`, then POSTs it to the group. For Xcode Cloud to run it, the `Default` workflow needs secret environment variables `ASC_KEY_ID`, `ASC_ISSUER_ID`, and either `ASC_PRIVATE_KEY_BASE64`, `ASC_PRIVATE_KEY`, or `ASC_PRIVATE_KEY_PATH`. The hook is intentionally non-fatal: missing secrets or ASC timing lag should not fail an otherwise successful app build.
