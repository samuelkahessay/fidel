# iOS ↔ web parity evidence

Captured 2026-11-23 on an iPhone 17 Pro simulator (iOS 26.5) and the web production build at 402×874, both holding the same progress: the backup in the round trip below.

| Screen | Side by side |
|---|---|
| Today | [today.png](today.png) |
| Learn | [learn.png](learn.png) |
| Lesson detail | [lesson.png](lesson.png) |
| Practice | [practice.png](practice.png) |
| Flashcards | [flashcards.png](flashcards.png) |
| Word Order | [word-order.png](word-order.png) |
| Character Tracing | [tracing.png](tracing.png) |
| Fidel chart | [chart.png](chart.png) (the iOS capture is from a fresh install) |
| You | [you.png](you.png) |

Raw captures are in `ios/` and `web/`.

## Backup round trip

1. **Web → iOS.** In a fresh browser profile I completed lessons 1 and 2 and conversation 2, then exported: 212 XP, 71 Fidel characters. I copied the file into the simulator's Files storage and imported it in the iOS app via **You → Local Backup → Import**. The app showed "Backup imported on this device" with 212 XP, 2 lessons, 71 Fidel characters and level 3 (`ios/you.png`).
2. **iOS → web.** I exported from the iOS app via **Export → On My iPhone** ("Fidel Progress Backup.json") and imported that file into a fresh browser profile. It showed 0 XP before the import and 212 XP, 2 lessons and 71 characters after it, and the values persisted across a reload.

## Logic parity

`FidelTests/GoldenFixtureTests.swift` writes the fixtures and the web runs them in `web/tests/unit/golden.test.ts`. They cover FSRS scheduling (100 cases), next-step recommendations, lesson composition, lesson-to-letter mapping and mastery (40 cases), streak and daily-XP rules, backup import, and 80 tracing replays. They are checked against both full-precision and shipped 4-dp stroke data: 361 checks pass on the web, and the same fixtures pass in XCTest.

## Known differences

- **Selam:** not on the web; a card points to the iOS app.
- **iCloud sync:** not on the web; backups bridge the two.
- **Level-3 tracing:** on the web it hides the guide and keeps the same tracing engine, instead of iOS's PencilKit shape evaluator.
- **Flashcard deck order (iOS behavior worth fixing):** opening Flashcards on iOS runs `initializeFlashcards`, which creates a card for every word and phrase (1,744), each due immediately. Every never-studied word then counts as a "due review", so Today keeps recommending reviews. The web counts only words actually studied as due, which matches the planner's intent. This should be fixed in the app rather than copied.
