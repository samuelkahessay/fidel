# Content & lesson-type expansion — 0 → working proficiency — design

Date: 2026-07-04
Status: Draft (design)

## Problem

The app feels "light on resources / lesson types / overall content for someone going from 0 to full working proficiency." A five-agent audit (content inventory, docs/decisions, resource lanes, Amharic curriculum research, competitor lesson-type research) confirms the *feeling* but sharpens the *diagnosis*: the bottleneck is **structure, grammar depth, and missing lesson types** far more than raw word count, and the obvious "add more content" lever is **blocked by licensing and an established import gate**.

### What's actually there (ground truth, not the stale docs)

Authoritative counts from `Fidel/Data/*.json` (the README is right; `CLAUDE.md`/`CURRICULUM.md`/`LEVEL_SYSTEM.md` cite obsolete 5-lesson/69-word figures):

| Bank | Count | Notes |
|---|---|---|
| `vocabulary.json` | **436** across 23 categories | Exceeds the A1 target (~500 lexical units), touches A2 |
| `phrases.json` | **174** | |
| `patterns.json` | **30** grammar patterns | units 1–10; counts 7/2/1/1/3/3/3/2/3/5 |
| `conversations.json` | **24** | difficulty 1:3, 2:18, 3:3 — almost no easy on-ramp / little advanced |
| `sentence_exercises.json` | **24** | word-order items; only grammar-units 1–4 have data |
| `cultural_notes.json` | **20** | |
| `fidel_chart.json` | **238** | full abugida; `fidel_stroke_data.json` ships stroke data |
| `numbers.json` | 31 numbers / 13 months / 10 ordinals / 4 fractions | |

Lessons are **not data** — they are 8 hardcoded `Lesson(...)` literals in `Models/AmharicData.swift:33-98` that *derive* content by filtering the flat banks (vocab by `category`, phrases by `id`-range, patterns by `unit`).

### The real gaps

1. **Orphaned content — the app already owns content it never teaches.**
   - **112 / 436 vocab (26%)** appear in **no** lesson: whole categories `Common Nouns`(56), `Common Verbs`(16), `Colors`(10), `Technology`(9), `Countries`(6), `Entertainment`(6), `Numbers`(5), `Greetings`(4). Reachable only via the global flashcard/quiz/match banks.
   - **89 / 174 phrases (51%)** appear in no lesson (ids 66–70, 91–174).
   - `sentence_exercises` cover only grammar-units 1–4; units 5–10 have **zero** word-order items, and `WordOrderViewModel` ignores `unit` and shuffles the global pool.
   - Fix: this content is *already vetted* — re-slicing it into lessons is pure, zero-risk value.

2. **Missing topic lessons.** No lesson teaches+practices **Numbers/Time** (Unit 2), **Shopping/Money** (Unit 6 — no currency/bargaining vocab at all), or **Daily Routine** (Unit 8 — the 16 `Common Verbs` are never surfaced), though `LEVEL_SYSTEM.md` specifies them.

3. **Shallow grammar — the true 0→proficiency blocker.** Amharic is a Category-IV (FSI ~1,100h) root-and-pattern Semitic language. Working proficiency requires the **verb system** (perfect / imperfect / jussive-imperative / gerundive stems with full subject agreement), **object & possessive suffixes**, the **yä- genitive**, **yä-/yämmi- relative clauses**, **converb chaining** and **compound tenses**, plus the obligatory **T-V formality register**. The current 30 patterns are mostly copula-based present tense + limited past/future/negation — they cap the learner at short declaratives (≈ high-A1/low-A2).

4. **Missing lesson types (the clearest read of "light on lesson types").** Present: flashcards, MCQ/typed-translation/"listening" quiz, sentence-builder (self-marked), word-order, match-pairs, speed-drill, pronunciation playback, character tracing, conversation reading/role-step, Selam chat. **Absent** (all confirmed high-ROI by competitor + SLA research): contextual **cloze**, **sentence-level SRS**, **grammar explainer cards**, **dictation / Ge'ez typing**, **graded reading passages/stories**, **dialogue-level listening comprehension**, **conjugation drills**, **Pimsleur-style anticipation + shadowing**. Also: the current `QuizType.listening` shows the Amharic *text* (audio suppressed) and asks for a typed transliteration — a spelling task mislabeled "Listening."

5. **No CEFR / level / skill metadata.** `Lesson` (`Models/Models.swift:86-93`) is `{id, title, description, patterns, vocabulary, phrases}` — no `unit`, `cefrLevel`, `lessonType`, or ordering. Progression is neither sequenced, measurable, nor displayable against A1→B2. Practice modes all pull *global* banks, so drills can never be scoped to the current lesson or a target skill.

6. **Stale/buggy metadata.** `allAchievements` `social_butterfly` (`Models.swift:416`) says "Practice all 18 conversations" but 24 exist (unlocks early, wrong copy). `CLAUDE.md`/`CURRICULUM.md`/`LEVEL_SYSTEM.md` cite obsolete counts.

### Estimated ceiling today

**Solid A1 reaching into low-A2.** The 436-word bank is fine for A1; shallow grammar, short scripted dialogues, orphaned content, and no graded production cap realistic proficiency well below the B1/B2 the roadmap aspires to.

## Hard constraints (non-negotiable — these shape everything below)

From `AGENTS.md`, `Fidel_local_first_plan.md`, the decision docs, and MEMORY:

- **Offline-first, no runtime API keys.** No cloud, no account, no network dependency for any learner-facing feature. Azure is a *content-production* dependency only; all learner audio is bundled MP3s labeled "Generated pronunciation" (never "native speaker," no scoring implied).
- **Import gate (decisive).** Resource-lane content (the phrasebook PDF, the Abugida Anki deck, Colloquial-Amharic-derived CSVs, the children's-book vocab) is **copyrighted with unresolved redistribution rights** and was already ruled **reference-only / archival**. No such content enters app JSON without provenance tagging, dedupe against existing JSON, source-rights review, and a reviewed pilot. Prior decisions: phrasebook = reference-only (Option 2); Anki media = archival; PWA = archival; only 16 conservative vocab rows imported so far (→436).
- **Editorial quality bar.** Amharic content must be native-reviewable. Do **not** dump unreviewed/generated Amharic into shipping JSON.
- **Build/test only via XcodeBuildMCP** (scheme `Fidel`, `iPhone 17 Pro`, `useLatestOS`, `suppressWarnings`; `session_show_defaults` before first build). Test target imports **`@testable import Fidel___Learn_Amharic`**. Register every new Swift file via `python3 tools/add_swift_file.py`; new bundled resources via `python3 tools/add_resource_file.py` (added this pass). Never hand-edit `project.pbxproj`.
- **Additive SwiftData migrations** (defaults only; no mapping code — app has never shipped publicly). **No energy/hearts/lives.** Open path, no content gate; interleaved Fidel; recommendation-driven (`NextStepPlanner`). Reuse the Ethiopic Theme + existing components; no new design system.
- **Source-of-truth rule.** `Fidel/` app JSON is authoritative; when counts change, update `README`, `CLAUDE.md`, `CURRICULUM.md`, `LEVEL_SYSTEM.md`, status docs, and FidelWeb marketing counts in the same workstream.

### Consequence for "gather more resources"

The path to proficiency is **not** bulk-importing the copyrighted lanes. It is: (a) **new lesson types** built in app code over existing content + bundled audio; (b) **restructuring** already-vetted content into a sequenced, CEFR-tagged curriculum that surfaces the 26%/51% orphaned material and fills Units 2/6/8; (c) **license-clean authored material** (English grammar explanations of existing patterns; deterministic verb-conjugation tables) added under the editorial bar; and (d) a **provenance-tagged review pipeline** for any net-new Amharic, so genuine content growth proceeds through the gate rather than around it.

## Design

### A. Curriculum framework (schema + restructure) — uses only existing vetted content

1. **Enrich `Lesson`** additively: `unit: Int`, `cefrLevel: String` (`"A1"`…`"B2"`), `skillTags: [String]`, keep it a value type. Keep the 8 existing lessons' behavior; add metadata. (Lessons stay Swift literals for now — data-driving them is a later task.)
2. **Explicit lesson membership.** Replace fragile phrase `id`-range slicing with explicit id lists (or a `lessonId` tag on content) so reordering can't silently change a lesson, and so orphaned phrases can be placed deliberately.
3. **Surface orphaned content + fill missing units.** Add lessons (from existing vocab/phrases): **Numbers & Time** (Unit 2, using `numbers.json` + `Time`/`Days`), **Colors & Describing Things** (`Colors`+`Common Adjectives`), **Animals & Nature**, **Around Town / Common Nouns** (`Common Nouns`+`Places`), **Daily Routine** (Unit 8, the 16 `Common Verbs`), **Modern Life** (`Technology`+`Entertainment`+`Countries`), and a real **Greetings** lesson wiring the 4-word `Greetings` category into Lesson 1. Net effect: 8 → ~15 lessons, ~0 orphaned content, no new Amharic authored.
4. **Lesson-scoped practice.** Add repository accessors so cloze/word-order/flashcards can be scoped to a lesson or skill, not only the global bank.

### B. New lesson types — priority order (from research; each maps to the existing repo→VM→View→XCTest spine)

**P0 (this program's first increment — zero new Amharic, fully offline):**
- **Contextual Cloze / fill-in-the-blank.** Blank one token in an Amharic sentence; pick from distractors (or type), with English + partial sentence for context. Reuses `sentence_exercises.json` (`amharicTokens` + `amharicDistractors`) *verbatim* — no new content. Optional bundled full-sentence audio on completion.
- **Sentence-level SRS.** Extend FSRS (`SpacedRepetition.swift` is already `(itemId, itemType)`-generic via `recordReview(for:type:rating:)`) with an item type `"sentence"` fed by `sentence_exercises` / conversation lines / pattern examples. Isolated-word review → durable in-context review.
- **Grammar explainer cards.** Teach-first cards: English explanation + worked Amharic examples for each pattern. Content is *English prose about already-vetted Amharic patterns* → low risk, no new Amharic. Data authored into `grammar_notes.json`.

**P1 (next increments):**
- **Dialogue-level listening comprehension** (reuse conversation line audio + authored comprehension MCQs).
- **Dictation / "type what you hear"** + a Ge'ez input method (syllable grid derived from `fidel_chart.json`).
- **Conjugation drills** over authored, native-reviewed verb-morphology tables (deterministic → generatable + verifiable).
- **Graded reading passages / stories** (LingQ + Duolingo-Stories hybrid; tap-to-reveal gloss, inline audio, comprehension MCQs, known/unknown coloring via existing FSRS `learnedItemIds`). Needs authored+reviewed passages.
- **Pimsleur anticipation + shadowing** (bundled audio + `AVAudioRecorder` self-eval; on-device acoustic self-rating consistent with the existing `DrawingEvaluator` pattern — no STT).

**P2 / gated:** scripted branching roleplay (needs a 2nd bundled voice); Drops-style image association (needs an illustration pipeline); automated pronunciation scoring / free-form AI roleplay (fundamentally need STT/LLM — offer only as an explicitly-connected Selam bonus, never core).

### C. Grammar depth toward B1/B2 — authored + native-reviewed, sequenced by need

Add pattern coverage for: full root-and-pattern verb conjugation (4 stems + agreement), copula/existential/"have"/negation as first-class, object & possessive suffixes, definite-object `-n`, yä- genitive, yä-/yämmi- relative clauses, converb chaining + compound tenses, causative/passive, comparatives, and the T-V register as metadata on person-addressing items. Delivered as new `patterns.json` entries + conjugation tables + grammar cards. **All new Amharic here goes through the review pipeline (D).**

### D. Content growth pipeline (respects the import gate)

Net-new Amharic (vocabulary toward the ~2,000 B1 / ~3,000 working-proficiency frequency core; new phrases; conversations; reading passages) is produced as **license-clean original authored content** (not copied from the copyrighted lanes), emitted to a **provenance-tagged review dataset** (`Fidel_Resources/` review sheets, matching `PHRASEBOOK_IMPORT_SCHEMA`), cross-verified by multiple agents, and only promoted to shipping JSON after native/editorial acceptance. Frequency sequencing follows Aberra's *Frequency Dictionary of Amharic* as a *reference for ordering* (not a source to copy).

## Scope of the first increment (this session)

Safe, high-value, fully verifiable, constraint-respecting — **no unreviewed new Amharic**:

1. `tools/add_resource_file.py` — Resources-phase pbxproj registration for new bundled JSON. **(done)**
2. **Curriculum metadata + restructure (A1–A3):** additive `Lesson` metadata; wire orphaned vocab/phrases; add missing-unit lessons from existing vetted content; keep the app green.
3. **New lesson type — Contextual Cloze (B/P0):** end-to-end (repo accessor → `ClozeViewModel` → `ClozeView` → `PracticeMode.cloze` → XCTest with stub repo + decoding/invariant test), reusing `sentence_exercises` verbatim.
4. **Bug/staleness fixes (part of #6 gap):** `social_butterfly` 18→24; reconcile stale doc counts; correct/relabel the "Listening" quiz behavior or its label.
5. **Verification:** `test_sim` green + `build_sim` clean via XcodeBuildMCP; update README/CLAUDE/CURRICULUM counts.

Deferred to subsequent increments (documented here, not built this session): grammar explainer cards, sentence-SRS, listening comprehension, dictation + Ge'ez input, conjugation drills, graded reading, shadowing, and the reviewed content-growth pipeline (C, D and the rest of B).

## Testing strategy

Per `FidelTests` convention (XCTest, in-memory `ModelContainer`, `StubLessonRepository` fixtures, `@testable import Fidel___Learn_Amharic`): a decoding+invariant test per touched/added bank (assert counts, no empty tokens, distractors distinct), a `ClozeViewModel` behavior test (correct/incorrect scoring, blank selection), and lesson-membership tests (no orphaned vocab/phrases; every lesson non-empty; ids valid). Content-decoding tests pin exact counts so the `fatalError`-on-bad-JSON load path stays guarded.

## Risks

- **Correctness of any new Amharic** → mitigated by building the first increment with *no* new Amharic (reuse + restructure + English grammar prose only) and routing genuine growth through the review pipeline.
- **pbxproj / shared-file churn** → sequential Swift edits with a green build after each; parallelism reserved for independent content authoring and read-only work, never concurrent edits to `Models.swift` / `AmharicData.swift` / `project.pbxproj`.
- **Scope** → the goal (0→B2) is a multi-increment arc; this spec defines the whole path and ships a coherent, verified down payment.
