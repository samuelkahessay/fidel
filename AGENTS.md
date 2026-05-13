# Fidel - Codex Instructions

## Project Overview

Fidel is a local-first Amharic learning iOS app built with SwiftUI, SwiftData, MVVM, repositories, and local JSON content. The iOS repo is the product source of truth for app code and learner-facing bundled content.

Before starting consolidation, import, release, or large refactor work, read:

- `docs/README.md`
- `docs/status/fidel-group-audit.md`
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

## Product Boundaries

- Keep Fidel local-first. Do not reintroduce sign-in, CloudKit, remote notification, or account-gated launch behavior unless the user explicitly reopens that product decision.
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
│   ├── Models/            # Domain and SwiftData models
│   ├── Repositories/      # Content/progress repository boundaries
│   ├── Services/          # Audio, progress export, stage, stroke, and spaced repetition services
│   ├── ViewModels/        # Observable feature state
│   └── Views/             # SwiftUI screens and shared components
├── FidelTests/
└── docs/
    └── status/            # Durable group/consolidation status
```

## Navigation

1. Journey: stage-gated lesson progression and core learning path.
2. Tools: Selam, reference material, tracing, and utility practice surfaces.
3. Progress: XP, streaks, achievements, backup/restore, and statistics.

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
