# Content & Lesson-Type Expansion — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: use superpowers:subagent-driven-development or superpowers:executing-plans to implement task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move Fidel from a solid-A1/low-A2 app toward a sequenced 0→working-proficiency (B1/B2) curriculum by adding high-ROG **lesson types**, **restructuring existing vetted content** into a CEFR-tagged curriculum, and **deepening grammar** — all offline, all respecting the import/licensing gate.

**Design spec:** `docs/superpowers/specs/2026-07-04-content-and-lesson-type-expansion-design.md` (read first — especially "Hard constraints").

**Tech stack:** Swift 5.9+, SwiftUI, SwiftData, XCTest, iOS 17+. Build/test via **XcodeBuildMCP** only. Every task leaves the app compiling and the suite green.

## Global constraints (from the spec)

- Offline-first, no runtime API keys, bundled audio only ("Generated pronunciation" copy). **No unreviewed/derived Amharic content into shipping JSON** — the import gate is hard.
- Build/test only via XcodeBuildMCP (scheme `Fidel`, sim `iPhone 17 Pro`, `useLatestOS`, `suppressWarnings`; `session_show_defaults` before first build). Test import: `@testable import Fidel___Learn_Amharic`.
- New Swift files → `python3 tools/add_swift_file.py <path>`. New bundled resources → `python3 tools/add_resource_file.py <path>`. Never hand-edit `project.pbxproj`.
- Additive SwiftData migrations only. Reuse the Ethiopic Theme + components (`WordTileButton`, `XPBadge`, `AccessibleProgressRing`, `FlowLayout`, `primaryGlassButton`). No new design system. No energy/hearts.
- Conventional Commits, small task-relevant commits, `Co-Authored-By` footer. Branch: `feat/content-lesson-type-expansion`.
- Every new `PracticeMode` case must be added to **all** exhaustive switches: `Models.swift` (icon/description/color), `Views/PracticeView.swift` (`modes` list + `PracticeHubDestination`), `ContentView.swift` (`PracticeModeDestination`), `Views/JourneyView.swift` (navigationDestination). The compiler enforces this.

---

## Status

- [x] **Increment 0 — shipped this session** (branch `feat/content-lesson-type-expansion`):
  - `tools/add_resource_file.py` (Resources-phase pbxproj registration; verified idempotent).
  - **Cloze / "Fill the Blank" lesson type** end-to-end: `ClozeViewModel`, `ClozeView`, `PracticeMode.cloze`, wired into all switches + hub, `ClozeViewModelTests` (6 tests). Reuses `sentence_exercises.json` verbatim — no new content. Verified: build ✓, 97 tests ✓, runtime drive-through ✓.
  - Fixed `social_butterfly` achievement (18→24). Reconciled `CLAUDE.md` + `README.md` counts.
  - **Latent gap found (not fixed):** `progress.achievements` is only set via backup-merge — no gameplay ever *awards* achievements (`allAchievements` is display-only). Achievement-award logic is its own task (Increment 5).

---

## Increment 1 — Grammar explainer cards (P0 lesson type, license-clean authored English)

**Why:** Amharic is highly inflected; learners can't infer rules from substitution alone. Teach-first cards are the missing explicit-grammar surface. Content is *English explanations of already-vetted patterns* → low risk, no new Amharic.

**New files:** `Fidel/Data/grammar_notes.json`, `Fidel/Models/GrammarNote.swift` (or extend `Models.swift`), `Fidel/Views/GrammarNotesView.swift`, `FidelTests/GrammarNotesTests.swift`.
**Modified:** `AmharicDataLoader.swift` (+`grammarNotes` loader), `LessonRepository(Protocol)` (+`getGrammarNotes()` / `forPattern:`), `Models.swift` (`PracticeMode.grammar`), the 4 switch sites, wire a "Learn the rule" entry from `LessonDetailView`/pattern rows.

- [ ] Author `grammar_notes.json`: one note per pattern (`patternId`, `title`, `explanation` (English), `examples: [{amharic, transliteration, english}]` drawn from the existing `patterns.json` examples). ~30 notes. Register via `add_resource_file.py`.
- [ ] `GrammarNote` Codable struct + loader + repo accessor. Decoding test pins count and non-empty explanation/examples.
- [ ] `GrammarNotesView` — card list + detail (reuse Theme). Optional audio on example rows via `WordAudioPlayer`.
- [ ] Wire `PracticeMode.grammar` into all switches; surface a "Grammar" entry in the Practice hub and a "See the rule" link on each pattern in `LessonDetailView`.
- [ ] Build + test green; runtime drive-through.

## Increment 2 — Sentence-level spaced review (P0)

**Why:** In-context sentence SRS is the durable-retention backbone isolated-word flashcards miss; recycles the app's richest content.

**Key fact:** `Services/SpacedRepetition.swift` is already `(itemId, itemType)`-generic (`recordReview(for:type:rating:)`, `getOrCreateProgress(for:type:)`, `getDueItems(type:)`). Add item type `"sentence"`.

- [ ] `FlashcardManager` seeds `"sentence"` items from `sentence_exercises` (+ later conversation lines / pattern examples). Test: due-item scheduling for `"sentence"` mirrors `"vocabulary"`.
- [ ] Sentence-review UI: show English (or Amharic) prompt, reveal the paired sentence + audio, grade Again/Hard/Good/Easy (reuse flashcard grading). Can live inside the existing flashcard/"Recommended review" flow or as `PracticeMode.sentenceReview`.
- [ ] `NextStepPlanner` counts due sentence reviews alongside vocab/phrase reviews. Test the recommendation includes sentence reviews.
- [ ] Build + test green; runtime drive-through.

## Increment 3 — Curriculum restructure: CEFR metadata + surface orphaned content + missing units

**Why:** 26% of vocab and 51% of phrases are in no lesson; Units 2/6/8 have no lesson. This surfaces already-vetted content — zero new Amharic.

**Caution:** touches the freshly-shipped open path. Study `JourneyViewModel`, `Services/CurriculumService.swift`, `Models/LearningStage.swift` (theme sectioning), and `NextStepPlanner` first; lessons are consumed by all of these. **Append** new lessons (ids 9+) rather than renumber (lesson ids are persisted in `UserProgress.lessonsCompleted` and referenced by `cultural_notes` + achievements).

- [ ] Additively enrich `Lesson` (`Models.swift`): `unit: Int`, `cefrLevel: String`, `skillTags: [String]` with defaults; keep existing 8 lessons behaviorally identical. Test: all lessons decode/build; existing lesson content unchanged.
- [ ] Fix Lesson 1 to include the orphaned `Greetings` vocab category. Replace fragile phrase `id`-range slices with explicit id lists (guard: no phrase/vocab orphaned; every lesson non-empty).
- [ ] Add lessons from existing vetted content: **Numbers & Time** (`numbers.json` + `Time`/`Days`), **Colors & Describing** (`Colors`+`Common Adjectives`), **Animals & Nature**, **Around Town** (`Common Nouns`+`Places`), **Daily Routine** (the 16 orphaned `Common Verbs`), **Modern Life** (`Technology`+`Entertainment`+`Countries`). Map each to a `unit`/`cefrLevel`.
- [ ] Verify `JourneyView` sections + `NextStepPlanner` + `CurriculumService` character-crediting handle the new lessons (add/adjust tests). Update `polyglot`/`culture_explorer` achievement text.
- [ ] Add `sentence_exercises` for grammar-units 5–10 **(needs authored + native-reviewed Amharic → route through Increment 6 pipeline)**, and lesson-scope `WordOrderViewModel`/`ClozeViewModel` (optional `unit:` filter).
- [ ] Build + test green; runtime drive-through.

## Increment 4 — Listening comprehension + true "listening" quiz fix (P1)

- [ ] Dialogue-level listening: play a bundled conversation, then authored comprehension MCQs (English questions about who/what/when — no new Amharic). New `listening_questions.json` (register via `add_resource_file.py`), keyed by conversation id.
- [ ] Fix `QuizType.listening`: currently shows Amharic text and asks for typed transliteration (a spelling task). Make it play audio with the text hidden, or relabel honestly. Add a test asserting the audio-first behavior.

## Increment 5 — Achievement awards (fix the latent gap)

- [ ] Add award logic: after XP/lesson/conversation/streak events, evaluate `allAchievements` `requirement` vs. the matching progress counter and append newly-earned ids to `UserProgress.achievements`. Tests per category. (Currently achievements never unlock from gameplay.)

## Increment 6 — Reviewed content-growth pipeline (P1, gated) — the path past A2

**Why:** B1 needs ~2,000 words; working proficiency ~3,000 frequency-ranked families. Growth must go through the import gate, not around it.

- [ ] Build a generation+review harness (multi-agent, cross-verified) that emits **license-clean original** authored content (net-new vocab sequenced by frequency reference; new phrases; conversations for work/health/money/opinions; graded reading passages; verb-conjugation tables) to a **provenance-tagged review dataset** under `Fidel_Resources/` matching `PHRASEBOOK_IMPORT_SCHEMA` (`sourceFile/decision/dedupe/reviewStatus`).
- [ ] Dedupe against shipping JSON (normalized Amharic then English). Native/editorial acceptance required before promotion.
- [ ] Promote accepted content into shipping JSON in a separate task with XcodeBuildMCP validation + decoding-count tests. Generate bundled audio via the existing Azure pipeline (`tools/audio/`), one active clip per (contentType, contentId).

## Increment 7+ — Remaining lesson types (P1/P2)

Dictation + Ge'ez syllable-grid input (from `fidel_chart.json`); conjugation drills (over reviewed verb tables); graded reading/stories (LingQ + Duolingo-Stories hybrid, known/unknown coloring via FSRS `learnedItemIds`); Pimsleur anticipation + shadowing (bundled audio + `AVAudioRecorder` self-eval, no STT); scripted branching roleplay (needs 2nd bundled voice). Grammar depth (verb stems + agreement, object/possessive suffixes, yä- genitive, relative clauses, converb chaining, register) delivered via Increment 6's reviewed pipeline.

---

## Testing strategy

Per `FidelTests` (XCTest, in-memory `ModelContainer`, `Stub*Repository` fixtures): decoding+invariant test per touched/added bank (pin counts — the loader `fatalError`s on bad JSON); ViewModel behavior tests (correct/incorrect scoring, edge cases); lesson-membership tests (no orphaned content; every lesson non-empty; valid ids). Drive each new lesson type in the simulator before claiming done.
