# Fidel Backlog

Last updated: 2026-07-04
Last audited: 2026-05-13

This is the single parking lot for future Fidel app, landing page, and content-pipeline work. Completed plans and historical audit checklists should link here instead of carrying their own separate future-work lists.

## Active

No active backlog items.

## Ready Next

- 2026-07-04 [program] Content & lesson-type expansion toward 0→working proficiency. Increment 0 shipped (see Completed). Next increments: grammar cards→sentence-SRS→curriculum restructure (CEFR metadata + surface the 26% orphaned vocab / 51% orphaned phrases + add Units 2/6/8)→listening comprehension→achievement-award logic→reviewed content-growth pipeline (all net-new Amharic through the import gate).
- 2026-07-04 [debt] Add achievement-award logic: `progress.achievements` is only set via backup-merge, so no gameplay ever unlocks the 13 defined achievements (`allAchievements` is display-only). Evaluate `requirement` vs. progress counters on XP/lesson/conversation/streak events.

## Later

- 2026-05-13 [feature] Design downloadable content packs only after content provenance, media rights, and local-first/offline packaging rules are settled.

## Blocked Or Not Now

- 2026-05-13 [not-now] Configure durable waitlist storage for `FidelWeb`: the subscribe API already supports `WAITLIST_WEBHOOK_URL`; choose the provider, set production env vars, and verify a real signup is stored when launch ops becomes active again.
- 2026-05-13 [not-now] Keep pronunciation scoring out of scope even with the generated-audio pilot; revisit only after Amharic recognition quality, privacy/offline policy, native-speaker reference quality, and score-copy expectations are proven; see `pronunciation-feedback-decision.md`.
- 2026-05-13 [blocked] Keep the remaining vocabulary import queue blocked on editorial cleanup/native review: after the 16-word conservative import, the remaining likely-new rows are mostly concatenated verb rows, blank-English rows, embedded-media rows, or broad `Other` category rows.
- 2026-05-13 [blocked] Do not bulk-import vocabulary or phrasebook rows until the review queue, provenance strategy, de-dupe rules, and rights/source review are applied.
- 2026-05-13 [blocked] Keep `.apkg` media archival until source-rights review, audio-quality review, image-rights review, and mapping verification make app usage acceptable.
- 2026-05-13 [blocked] Keep the static speaking-practice PWA archival; do not invest in public companion work unless a separate web product goal reopens that decision.

## Completed

- 2026-07-05 [feature+content] **Promoted the remaining candidate corpus + shipped the Reading lesson type.** patterns.json 30→**94** (+52 grammar patterns +12 verb-conjugation tables, all unit=11 so they surface in Grammar/Sentence-Builder without altering the 8 lessons), conversations.json 24→**30** (+6 functional B1 dialogues), cultural_notes.json 20→**90** (+70), and a new **reading_passages.json** (5 graded passages) behind a new **Reading** `PracticeMode` (ReadingViewModel/ReadingView + repo accessor + decoding test). Also fixed `add_resource_file.py` (Resources-phase marker used `rfind`) — validated end-to-end registering the new bundled JSON. `social_butterfly` 24→30. Verified: `test_sim` 105/105, app launches, Reading list + passage + comprehension render on real data. Copyright waived by owner for internal POC.
- 2026-07-05 [content] **POC promotion**: imported the full consolidated candidate corpus (1,134 unique vocab+phrases from the generated + extracted review packs, deduped vs app + each other) into shipping JSON — `vocabulary.json` 436→**1038**, `phrases.json` 174→**706**. Copyright waived by owner for internal POC; provenance kept in the review packs. 18 items were verifier-flagged low-confidence (still promoted per request). New categories (Work/Health/Money/Opinions/Education/etc.) flow into global flashcards/quiz/cloze/match/speed-drill; wiring them into lessons is the pending curriculum-restructure increment. Verified: JSON decodes on-device, no dup ids/pairs, `test_sim` 103/103, app launches and surfaces promoted content (Phrase of the Day rendered a promoted health phrase). Grammar patterns (52), conjugations (12), conversations (6), reading passages (5), and cultural notes (70) remain in the review packs, not yet promoted.
- 2026-07-05 [content] Generated a provenance-tagged **review corpus** toward 0→proficiency by fanning out 58 subagents (parallel generate → adversarial verify → dedupe against app JSON): 208 candidate vocab (194 keep, 8 functional domains), 74 phrases, 12 grammar patterns (suffixes/genitive/relative/negation/compound tenses), 12 verb-conjugation tables (156 forms), 6 B1 conversations, 5 graded reading passages. Written to `../../Fidel_Resources/amharic/generated_review/` (CSV/JSON + manifest + raw). AI-verified only — **NOT native-reviewed, NOT imported**; sits behind the import gate as reviewer input (Increment 6 first pass). No `Fidel/Data/*.json` changed.
- 2026-07-04 [feature] Shipped Increment 0 of the content/lesson-type expansion (branch `feat/content-lesson-type-expansion`): two new offline lesson types built entirely on existing vetted content — **Fill the Blank (cloze)** over `sentence_exercises.json` and a **Grammar** teach-first reference over `patterns.json` (English-only blurbs, no new Amharic). Added `tools/add_resource_file.py` (Resources-phase pbxproj registration). Fixed the `social_butterfly` achievement (18→24) and reconciled stale `CLAUDE.md`/`README.md` counts. Verified: `build_sim` clean, `test_sim` 103/103 (was 91; +12), and simulator drive-through of both new modes. No content entered through the import gate.
- 2026-05-13 [debt] Finished the active `codex/ui-ux-remediation` work: XcodeBuildMCP `build_sim` succeeded, `test_sim` passed 15/15, simulator launch succeeded after clearing a stale install state, and Journey/Tools/Progress tab smoke checks passed.
- 2026-05-13 [content] Built the small phrasebook pilot review sheet at `../../Fidel_Resources/fidel_resources/PHRASEBOOK_PILOT_REVIEW.md` and refreshed stale phrasebook product-decision counts.
- 2026-05-13 [content] Accepted the phrasebook pilot as a review-only direction and generated provenance-preserving review artifacts at `../../Fidel_Resources/fidel_resources/PHRASEBOOK_PILOT_REVIEW.csv` and `../../Fidel_Resources/fidel_resources/PHRASEBOOK_PILOT_REVIEW.json`; no iOS app data was changed.
- 2026-05-13 [feature] Completed the post-UI-branch tracing QA pass: launched Character Tracing in the simulator, verified animated-guide handoff to drawing canvas, confirmed a drawn stroke enables Clear/Check, and confirmed low-coverage feedback returns Try Again/Skip.
- 2026-05-13 [feature] Shipped the Azure-generated offline pronunciation library: created the free Azure Speech resource, generated 171 active male phrase MP3s plus 171 female alternate catalog MP3s, added bundle resource packaging, validated the manifest/files, replaced stale live/native pronunciation UI, and kept scoring out of scope.
- 2026-05-13 [feature] Decided pronunciation scoring is not now and documented reopen criteria in `pronunciation-feedback-decision.md`; generated pronunciation should stay clearly labeled and should not imply native-speaker scoring or authoritative fluency judgment.
