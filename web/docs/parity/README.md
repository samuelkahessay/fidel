# iOS ↔ web parity evidence

Captured 2026-11-23 on an iPhone 17 Pro simulator (iOS 26.5) and the web production build at 402×874. Both hold the same progress: the backup from the round trip below. Each image shows the iOS app on the left and the web on the right.

| Area | Screen | Side by side |
|---|---|---|
| Today | Today | [today.jpg](today.jpg) |
| Learn | Learn path | [learn.jpg](learn.jpg) |
| | Lesson detail | [lesson.jpg](lesson.jpg) |
| | Conversation | [conversation.jpg](conversation.jpg) |
| Practice | Practice hub | [practice.jpg](practice.jpg) |
| | Flashcards | [flashcards.jpg](flashcards.jpg) |
| | Quiz | [quiz.jpg](quiz.jpg) |
| | Fill the Blank | [cloze.jpg](cloze.jpg) |
| | Match Pairs | [match.jpg](match.jpg) |
| | Word Order | [word-order.jpg](word-order.jpg) |
| | Sentence Builder | [sentence-builder.jpg](sentence-builder.jpg) |
| | Grammar | [grammar.jpg](grammar.jpg) |
| | Reading | [reading.jpg](reading.jpg) |
| | Speed Drill | [speed-drill.jpg](speed-drill.jpg) |
| | Pronunciation | [pronunciation.jpg](pronunciation.jpg) |
| | Character Tracing | [tracing.jpg](tracing.jpg) |
| Reference | Fidel chart | [chart.jpg](chart.jpg) (the iOS capture is from a fresh install) |
| | Phrasebook | [reference.jpg](reference.jpg) |
| You | Progress, pace, backup | [you.jpg](you.jpg) |

Selam is excluded on the web (see [PARITY.md](../../PARITY.md)).

The comparisons drove these web changes:
- **Learn:** the dark recommended card and title-case sections.
- **Practice:** the "Recommended review" card and mode icons.
- **Flashcards:** the transliteration shown up front, with Show Answer, Still learning and Got it!.
- **Quiz:** the type chooser.
- **Match Pairs:** the round and matched counters, plus transliteration on the tiles.
- **Word Order:** transliteration on the tiles.
- **Sentence Builder:** option counts.
- **Conversation:** the full dialogue with a difficulty header and cultural context.
- **Reference:** the iOS labels.
- **Tracing:** the slate canvas.

## Backup round trip

1. **Web → iOS.** In a fresh browser profile I completed lessons 1 and 2 and conversation 2, then exported: 212 XP, 71 Fidel characters. I copied the file into the simulator's Files storage and imported it in the iOS app via **You → Local Backup → Import**. The app showed "Backup imported on this device" with 212 XP, 2 lessons, 71 Fidel characters and level 3 ([you.jpg](you.jpg), left).
2. **iOS → web.** I exported from the iOS app via **Export → On My iPhone** ("Fidel Progress Backup.json") and imported that file into a fresh browser profile. It showed 0 XP before the import and 212 XP, 2 lessons and 71 characters after it, and the values persisted across a reload.

## Logic parity

`FidelTests/GoldenFixtureTests.swift` writes the fixtures and the web runs them in `web/tests/unit/golden.test.ts`. They cover FSRS scheduling (100 cases), next-step recommendations, lesson composition, lesson-to-letter mapping and mastery (40 cases), streak and daily-XP rules, backup import, and 80 tracing replays. They are checked against both full-precision and shipped 4-dp stroke data: 361 checks pass on the web, and the same fixtures pass in XCTest.

## Known differences

- **Selam:** not on the web; a card points to the iOS app.
- **iCloud sync:** not on the web; backups bridge the two.
- **Level-3 tracing:** on the web it hides the guide and keeps the same tracing engine, instead of iOS's PencilKit shape evaluator.
- **Pronunciation:** iOS plays the generated clip for each of the 703 phrases in order. The web plays the same clips for 10 random phrases per session and adds an optional record-and-compare step (local only, never uploaded).
- **Conversation audio:** iOS has a play-through transport bar. The web has a play button per line.
- **Flashcard due count (iOS behavior worth fixing):** opening Flashcards on iOS runs `initializeFlashcards`, which creates a card for every word and phrase (1,744), each due immediately. After a single visit, Today reads "Review 15 words" even for a learner who has never studied any ([ios-today-after-flashcards-visit.jpg](ios-today-after-flashcards-visit.jpg)). The web counts only words actually studied as due, which matches the planner's intent. This should be fixed in the app rather than copied.
