# Fidel - Claude Code Instructions

## Project Overview

Fidel is an **Amharic language learning iOS app** built with **SwiftUI + SwiftData** using **MVVM + Repository pattern**.

### What it teaches
- **Fidel (ፊደል)**: The Ethiopic/Ge'ez script — 34 consonant rows × 7 vowel forms = 238 characters
- **5 structured lessons**: Greetings, Possessives & Family, Questions & Directions, Food & Shopping, Making Plans & Time
- **14 grammar patterns**, **69 vocabulary words**, **50 phrases**, **10 conversation dialogues**

### Architecture
```
Fidel/
├── App/              # FidelApp entry point
├── Models/           # SwiftData models (UserProgress, FlashcardProgress, FidelCharacter, Lesson, etc.)
├── Views/            # SwiftUI views organized by feature
│   ├── Journey/      # Stage-based lesson progression (main learning tab)
│   ├── Tools/        # Selam AI tutor, Reference (Fidel chart, phrases, numbers)
│   ├── Progress/     # Stats dashboard, streaks, achievements
│   └── Components/   # Reusable UI (ProgressRing, GlassChip, etc.)
├── ViewModels/       # JourneyViewModel, ProgressViewModel, SelamViewModel, etc.
├── Repositories/     # LessonRepository, ProgressRepository, SelamRepository
├── Services/         # SpacedRepetition (SM-2), AudioService, SelamAIService, StageManager
├── Data/             # AmharicData.swift (all lesson/character content)
└── Theme/            # Theme.swift (Ethiopian colors, glass morphism, spacing)
```

### Navigation: 3 tabs
1. **Journey** — Stage-gated lesson progression with activity cards
2. **Tools** — Selam AI conversational tutor + reference materials
3. **Progress** — XP, streaks, achievements dashboard

### 4-stage progression system
| Stage | Name | Unlock criteria |
|-------|------|-----------------|
| 0 | Script & Sounds (ፊደል) | Starting stage |
| 1 | Survival Phrases (ሰላมታ) | Recognize 50+ Fidel characters |
| 2 | Building Sentences (ዓረፍተ ነገር) | Complete Lessons 1-2 + 30+ vocab |
| 3 | Fluency (ብቃት) | All 5 lessons + 100+ vocab + 5+ conversations |

### Practice modes
Flashcards (SM-2 spaced repetition), Quiz (5 question types), Pronunciation, Sentence Builder, Speed Drill

### Design system
iOS 26 "Liquid Glass" style. Ethiopian color palette: Green (#00722C), Yellow (#FFD500), Red (#CF1D28). Spring-based animations throughout.

### Key data files
- `AmharicData.swift` — All character, lesson, vocab, phrase, and conversation content
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
