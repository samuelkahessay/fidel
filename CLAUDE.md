# Fidel - Claude Code Instructions

## Project Overview

Fidel is an **Amharic language learning iOS app** built with **SwiftUI + SwiftData** using **MVVM + Repository pattern**.

### What it teaches
- **Fidel (ፊደል)**: The Ethiopic/Ge'ez script — 34 consonant rows × 7 vowel forms = 238 characters
- **8 structured lessons**: Greetings & Introductions, Possessives & Family, Questions & Directions, Food & Shopping, Making Plans & Time, Health & Body, Travel & Transportation, Ethiopian Culture & Celebrations
- **94 grammar patterns** (incl. 12 verb-conjugation tables), **1038 vocabulary words**, **706 phrases**, **30 conversation dialogues**, **90 cultural notes**, **24 word-bank sentence exercises**, **5 reading passages** — all banks grew via a POC promotion of the generated + extracted candidate corpus (`Fidel_Resources/amharic/{generated,extracted}_review/`)

> Counts above are ground truth from `Fidel/Data/*.json`; keep the table in `README.md` in sync when they change.

### Architecture
```
Fidel/
├── App/              # FidelApp entry point
├── Models/           # SwiftData models (UserProgress, FlashcardProgress, FidelCharacter, Lesson, etc.)
├── Views/            # SwiftUI views organized by feature
│   ├── Journey/      # Open learning path — recommendation-driven, no gate (main learning tab)
│   ├── Tools/        # Selam AI tutor, Reference (Fidel chart, phrases, numbers)
│   ├── Progress/     # Stats dashboard, streaks, achievements
│   └── Components/   # Reusable UI (ProgressRing, GlassChip, etc.)
├── ViewModels/       # JourneyViewModel, ProgressViewModel, SelamViewModel, etc.
├── Repositories/     # LessonRepository, ProgressRepository, SelamRepository
├── Services/         # SpacedRepetition (SM-2), AudioService, SelamAIService, StageManager
├── Data/             # Bundled content JSON and audio manifests
└── Theme/            # Theme.swift (Ethiopian colors, glass morphism, spacing)
```

### Navigation: 5 tabs
1. **Today** — Daily focus + quick paths
2. **Learn** — Open learning path (`JourneyView`): a recommended-next hero + fully-tappable lessons with mastery rings
3. **Practice** — Practice hub (flashcards, quiz, tracing, etc.)
4. **Selam** — Selam AI conversational tutor
5. **You** — XP, streaks, achievements, backup/restore

### Progression: open path (no hard gate)
There is **no stage gate**. All lessons and conversations are always available; the four themes (Script & Sounds, Survival Phrases, Building Sentences, Fluency) are just **section headers**. The Fidel script is **interleaved** into lessons — completing a lesson credits the Fidel characters that appear in its words (`CurriculumService`) — and progress shows as per-lesson **mastery rings** (New→Started→Familiar→Proficient→Mastered), display-only, never a lock.

- **`NextStepPlanner`** picks the recommended next session (due reviews → resume in-progress → next new lesson), sized by the user's **`DailyGoalTier`** (Casual/Regular/Serious/Intense, chosen in the You tab).
- Spaced repetition via **FSRS** (`Services/SpacedRepetition.swift`). Tracing sessions **auto-advance** on a correct trace and size to the tier.
- Streaks have **slack**: auto-granted weekly freezes absorb a single missed day (`UserProgress.checkStreak`).

### Practice modes
Flashcards (FSRS/SM-2 spaced repetition), Quiz (multiple choice / typed translation / typed pronunciation), Sentence Builder, Word Order, **Fill the Blank (cloze)**, **Grammar** (teach-first reference over patterns), **Reading** (graded passages + comprehension), Match Pairs, Speed Drill, Pronunciation, Character Tracing

### Design system
iOS 26 "Liquid Glass" style. Warm palette defined in `Theme.swift`: terracotta (#B55130), eucalyptus (#4B7A64), gold (#CF9A2E) on paper (#F6F0E4) with ink (#221C16), each with a dark-mode variant. Spring-based animations throughout.

### Key data files
- `Fidel/Data/*.json` — All character, lesson content, vocab, phrase, and conversation data (lessons are assembled in `Models/AmharicData.swift`)
- `Theme.swift` — Colors, spacing, typography, button/card styles

---

## Building & Testing

Always use **XcodeBuildMCP** tools for building and testing this project. Do not use raw `xcodebuild` commands via Bash.

### Session Defaults

Set these defaults at the start of each session:

- **Project path:** `Fidel.xcodeproj`
- **Scheme:** `Fidel`
- **Simulator:** `iPhone 17 Pro` (no iPhone 16 simulator available)
- **useLatestOS:** `true`
- **suppressWarnings:** `true`

### Common Operations

- **Build:** `build_sim` for simulator builds
- **Run:** `build_run_sim` to build and launch on simulator
- **Test:** `test_sim` for running tests on simulator
- **Device build:** `build_device` for physical device builds
