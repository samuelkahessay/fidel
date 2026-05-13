# Fidel Group Durable Task List

Date created: 2026-05-02
Last updated: 2026-05-13

Purpose: track consolidation work across the Fidel sibling repos and resource folders. Work one task at a time. For each task, verify the claim, make the smallest scoped change, run the listed validation, commit if a tracked repo changed, then mark the task complete here.

Location note: this file now lives inside the iOS product repo at `docs/status/fidel-group-audit.md` so future Codex sessions can find the group-level consolidation history from the app source of truth.

## Working Protocol

- [x] Before starting a task, verify its claim against the current repo/folder with `rg`, `sed`, `jq`, `python3`, `node`, git status, or XcodeBuildMCP as appropriate.
- [x] Preserve unrelated dirty or untracked files in all child repos.
- [x] Do not move or import content unless the task explicitly calls for it.
- [x] For iOS validation, use XcodeBuildMCP only: project `Fidel.xcodeproj`, scheme `Fidel`, simulator `iPhone 17 Pro`, `useLatestOS: true`, `suppressWarnings: true`.
- [x] If a task changes a git repo, commit inside that repo with the task's commit message or a more specific equivalent.
- [x] After completing a task, update this document's checkbox and refresh any changed counts or status notes.

## Verified Baseline

- [x] `Fidel/` is the iOS product source of truth; `main` now includes the conservative vocabulary import and TestFlight build 12 merge, while active UI work is on `codex/ui-ux-remediation`.
- [x] XcodeBuildMCP `test_sim` for `Fidel` passed 12/12 on `iPhone 17 Pro` after the conservative vocabulary import. This has not been re-run after the active `codex/ui-ux-remediation` edits.
- [x] `FidelWeb/` is a Next landing page repo with consolidation commits on branch `codex/fidelweb-consolidation`; `main` is at `origin/main`.
- [x] `Fidel_Resources/amharic/` is a resource git repo on branch `codex/resource-consolidation` with local untracked `.DS_Store`, `.apkg`, and `LearnAmharic/`.
- [x] `Fidel_Resources/fidel_resources/` is a non-git phrasebook extraction/editing workspace.
- [x] iOS bundled content counts: 8 lessons, 30 patterns, 24 conversations, 174 phrases, 436 vocabulary entries, 20 cultural notes, 238 Fidel characters, 238 stroke recordings, and 4 numeric reference groups.
- [x] `FidelWeb/src/lib/constants.ts` initially advertised older content counts: 5 lessons, 69 vocabulary words, 50 phrases, and 10 conversations. This is corrected on branch `codex/fidelweb-consolidation`.
- [x] `Fidel_Resources/amharic/web_app/js/data.js` contains 27 patterns, 10 conversations, and 62 phrases.
- [x] `Fidel_Resources/amharic/anki_vocabulary.csv` and `anki_vocabulary_categorized.csv` each have 546 rows including headers.
- [x] `Fidel_Resources/fidel_resources/output/qa_report_final.json` now reports 9,914 lines, 18 H2 sections, 221 H3 sections, 4,584 table rows, and 0 QA failures.
- [x] Phrasebook editorial handoff now lists 24 completed chapter files and 0 remaining chapter files.

## Task 1: Refresh Baseline Inventory

**Claim to verify**
- [x] Counts and repo statuses in this document still match the sibling repos.

**Likely files**
- `docs/status/fidel-group-audit.md`

**Implementation checklist**
- [x] Run git status in `Fidel/`, `FidelWeb/`, and `Fidel_Resources/amharic/`.
- [x] Recount iOS JSON files with `jq`.
- [x] Recount resource PWA data with Node.
- [x] Re-read phrasebook final QA metrics.
- [x] Update "Verified Baseline" if anything changed.

**Validation**
- [x] `rg -n "[T]BD|[F]IXME" docs/status/fidel-group-audit.md` returns no matches.

**Commit message**
- No commit required if only this parent non-git document changes.

## Task 2: Reconcile FidelWeb Marketing Counts

**Claim to verify**
- [x] `FidelWeb/src/lib/constants.ts` still advertises stale app scope relative to iOS.
- [x] Any visible landing-page copy generated from these constants still reflects old counts.

**Likely files**
- `FidelWeb/src/lib/constants.ts`
- `FidelWeb/README.md`

**Implementation checklist**
- [x] Update marketing stats to match the iOS app: 238 characters, 8 lessons, 436 vocabulary entries, 174 phrases, 24 conversations, and 20 cultural notes where those claims are visible.
- [x] Update feature and stage descriptions so they do not mention old counts or the old 5-lesson curriculum.
- [x] Keep waitlist/product positioning intact unless a verified line directly conflicts with current iOS scope.
- [x] Run `rg -n "5 lessons|69 vocabulary|50 phrases|10 conversations|14 grammar|11 achievements" FidelWeb/src FidelWeb/README.md`.

**Validation**
- [x] In `FidelWeb/`, install dependencies if needed with `npm install`.
- [x] Run `npm run build`.

**Commit message**
- `docs: align landing page content counts`

## Task 3: Verify FidelWeb Waitlist Durability

**Claim to verify**
- [x] `FidelWeb/src/app/api/subscribe/route.ts` validates email but only logs signups to the server console.

**Likely files**
- `FidelWeb/src/app/api/subscribe/route.ts`
- `FidelWeb/README.md`
- `FidelWeb/DEPLOYMENT.md`

**Implementation checklist**
- [x] Decide the minimal durable waitlist path for the current project: static disabled form, file-backed development stub, or configured provider integration.
- [x] Document the selected path clearly in `README.md` or `DEPLOYMENT.md`.
- [x] If provider integration is chosen, require env vars and fail gracefully when missing.
- [x] Do not silently claim signups are stored if they are not.

**Validation**
- [x] Run `npm run build` in `FidelWeb/`.
- [x] Run or manually verify the subscribe endpoint behavior in development if dependencies are installed.

**Commit message**
- `fix: clarify waitlist signup handling`

## Task 4: Create Vocabulary De-Dupe Report

**Claim to verify**
- [x] iOS had 420 bundled vocabulary entries at the de-dupe report baseline; the conservative import raised this to 436.
- [x] Resource CSV has 545 vocabulary entries excluding the header.
- [x] No vocabulary import should happen before duplicate and delta analysis.

**Likely files**
- `Fidel_Resources/amharic/anki_vocabulary_categorized.csv`
- `Fidel/Fidel/Data/vocabulary.json`
- `Fidel_Resources/amharic/VOCAB_DEDUPE_REPORT.md`

**Implementation checklist**
- [x] Normalize iOS and CSV entries by Amharic, transliteration, and English.
- [x] Count exact matches, Amharic-only matches, English-only matches, and likely new entries.
- [x] Group likely new entries by CSV category.
- [x] Flag conflicting translations or transliterations for manual review.
- [x] Do not edit `Fidel/Fidel/Data/vocabulary.json` in this task.

**Validation**
- [x] Report includes total iOS entries, total CSV entries excluding header, match counts, conflict counts, and recommended import candidates.
- [x] Run a small parser sanity check over the CSV and JSON.

**Commit message**
- `docs: add vocabulary de-dupe report`

## Task 5: Decide Phrasebook Product Path

**Claim to verify**
- [x] Phrasebook resources are large enough to support multiple possible product directions.
- [x] Productization should not continue without choosing the target shape.

**Likely files**
- `Fidel_Resources/fidel_resources/EDITORIAL_HANDOFF.md`
- `Fidel_Resources/fidel_resources/output/qa_report_final.json`
- `Fidel_Resources/fidel_resources/PHRASEBOOK_PRODUCT_DECISION.md`

**Implementation checklist**
- [x] Summarize three options: in-app content pack, reference-only dataset, archival research.
- [x] Recommend one default path for this project.
- [x] List what the recommended path requires before any app import.
- [x] List what work should stop if the phrasebook remains archival.
- [x] Keep the decision document separate from edited chapter content.

**Validation**
- [x] Decision document names one recommended path and explicitly rejects or defers the other two.

**Commit message**
- No commit required if only the non-git `fidel_resources` folder changes.

## Task 6: Finish Remaining Phrasebook Editorial Pass

**Claim to verify**
- [x] Editorial handoff still lists these remaining files: `04e-countryside.md`, `04g-time-numbers.md`, `06a-meeting-people.md`, `06d-interests.md`, `06e-activities.md`, `06g-religion-holidays.md`, `09-english-to-ethiopian-amharic-dictionary.md`, `00-front-matter.md`, and `10-index.md`.

**Likely files**
- `Fidel_Resources/fidel_resources/output/chapters/04e-countryside.md`
- `Fidel_Resources/fidel_resources/output/chapters/04g-time-numbers.md`
- `Fidel_Resources/fidel_resources/output/chapters/06a-meeting-people.md`
- `Fidel_Resources/fidel_resources/output/chapters/06d-interests.md`
- `Fidel_Resources/fidel_resources/output/chapters/06e-activities.md`
- `Fidel_Resources/fidel_resources/output/chapters/06g-religion-holidays.md`
- `Fidel_Resources/fidel_resources/output/chapters/09-english-to-ethiopian-amharic-dictionary.md`
- `Fidel_Resources/fidel_resources/output/chapters/00-front-matter.md`
- `Fidel_Resources/fidel_resources/output/chapters/10-index.md`
- `Fidel_Resources/fidel_resources/EDITORIAL_HANDOFF.md`

**Implementation checklist**
- [x] Fix the recurring artifacts documented in the handoff: double-spaced prose, prose mixed into table rows, split m/f variants, split multi-word entries, sidebar labels leaking into tables, garbled Amharic, trailing slash/parenthesis issues, and hyphenation artifacts.
- [x] Work one chapter file at a time and update its status when complete.
- [x] Do not add new content that is not present in the extracted phrasebook.
- [x] Preserve the existing table format unless the handoff instructs a special format.

**Validation**
- [x] Run `python3 qa_phrasebook.py` from `Fidel_Resources/fidel_resources/` if the script supports the edited output.
- [x] Confirm the handoff no longer lists unfinished files.

**Commit message**
- No commit required if only the non-git `fidel_resources` folder changes.

## Task 7: Design Phrasebook Import Schema

**Claim to verify**
- [x] Phrasebook content cannot be safely imported into iOS until a schema maps chapter rows to app concepts.

**Likely files**
- `Fidel_Resources/fidel_resources/PHRASEBOOK_IMPORT_SCHEMA.md`
- `Fidel/Fidel/Models/Models.swift`
- `Fidel/Fidel/Data/phrases.json`
- `Fidel/Fidel/Data/cultural_notes.json`

**Implementation checklist**
- [x] Define target entities for phrasebook rows: phrase, vocabulary entry, cultural note, dictionary entry, or excluded archival row.
- [x] Define required fields for each target entity and how source chapter/section provenance is preserved.
- [x] Define rejection rules for incomplete rows, dictionary-scale rows, and duplicate app content.
- [x] Include a small worked example from one practical/social chapter.
- [x] Do not edit iOS app JSON in this task.

**Validation**
- [x] Schema document includes at least one example for phrase, vocabulary, cultural note, and rejected row.

**Commit message**
- No commit required if only the non-git `fidel_resources` folder changes.

## Task 8: Evaluate Anki Media For Native Audio/Image Use

**Claim to verify**
- [x] `Fidel_Resources/amharic/Amharic_Most_common_words_Abugida_Language_School.apkg` exists locally but is untracked.
- [x] The iOS app currently uses TTS/cache/recording flows, not bundled native media for each vocabulary item.

**Likely files**
- `Fidel_Resources/amharic/anki_deck_analysis.md`
- `Fidel_Resources/amharic/ANKI_MEDIA_EVALUATION.md`

**Implementation checklist**
- [x] Verify whether the `.apkg` can be inspected locally without destructive extraction.
- [x] Document media counts, sample filenames, and mapping feasibility.
- [x] Identify rights/source constraints before recommending app use.
- [x] Recommend one of: do not use, use for research only, or extract into a reviewed asset pipeline.
- [x] Do not add media to the iOS app in this task.

**Validation**
- [x] Evaluation document includes technical feasibility and rights caveat sections.

**Commit message**
- `docs: evaluate anki media source`

## Task 9: Verify FidelWeb Build

**Claim to verify**
- [x] `FidelWeb/node_modules` is absent or stale before dependency installation.
- [x] Landing page should have a reproducible build check before further web work.

**Likely files**
- `FidelWeb/package-lock.json`
- `FidelWeb/package.json`
- `FidelWeb/README.md`

**Implementation checklist**
- [x] Run `npm install` in `FidelWeb/` if dependencies are absent.
- [x] Run `npm run build`.
- [x] If build fails, record the exact failure and fix only build blockers.
- [x] If build passes, document the verified Node/npm path if useful.

**Validation**
- [x] `npm run build` exits 0.

**Commit message**
- `chore: verify landing page build`

## Task 10: Decide Fate Of Static Speaking-Practice PWA

**Claim to verify**
- [x] `Fidel_Resources/amharic/web_app/` is a complete static PWA but overlaps with iOS features.

**Likely files**
- `Fidel_Resources/amharic/web_app/README.md`
- `Fidel_Resources/amharic/PWA_ARCHIVE_DECISION.md`

**Implementation checklist**
- [x] Compare PWA UX/features to iOS implementations for pattern browser, sentence builder, conversation simulator, speed drills, and progress.
- [x] Recommend whether the PWA remains archival, becomes a public companion, or serves only as UX reference.
- [x] If archival, document that iOS remains product source of truth.
- [x] If companion, list the minimum work required to sync content counts and branding.

**Validation**
- [x] Decision document names one recommended status and the next action.

**Commit message**
- `docs: decide static pwa role`

## Task 11: Update Final Consolidation Status

**Claim to verify**
- [x] Tasks 1 through 10 are either complete or explicitly deferred with a reason.

**Likely files**
- `docs/status/fidel-group-audit.md`
- Any task-specific reports produced above.

**Implementation checklist**
- [x] Mark completed tasks in this checklist.
- [x] Add a short "Current Source Of Truth" note.
- [x] Add a short "Deferred Work" note for anything intentionally postponed.
- [x] Run status checks for all child repos and record where changes live.

**Validation**
- [x] No unchecked task lacks a reason if consolidation is being paused.
- [x] All changed git repos have either commits or an explicit uncommitted-work note.

**Commit message**
- Use the relevant repo-specific commit messages from completed tasks.

## Current Source Of Truth

- `Fidel/` remains the iOS product source of truth for app code and learner-facing content.
- `Fidel/` branch `main` now contains the conservative vocabulary import and TestFlight build 12 merge:
  - `e10f4bd data: import reviewed vocabulary candidates`
  - `2fc28c9 Merge pull request #4 from samuelkahessay/codex/testflight-build-12`
- `Fidel/` branch `codex/ui-ux-remediation` currently contains uncommitted UI/UX remediation work. Keep organization commits scoped so they do not stage or overwrite those SwiftUI edits.
- `FidelWeb/` branch `codex/fidelweb-consolidation` contains committed landing-page count, waitlist, dependency, and build-verification updates:
  - `7a7cb10 docs: align landing page content counts`
  - `7e008c5 fix: clarify waitlist signup handling`
  - `ed4f168 chore: verify landing page build`
  - `164bc5c docs: update vocabulary count after import`
- `Fidel_Resources/amharic/` branch `codex/resource-consolidation` contains committed audit reports and decisions:
  - `b0fe10b docs: add vocabulary de-dupe report`
  - `928c408 docs: evaluate anki media source`
  - `cc84a70 docs: decide static pwa role`
  - `b4631bf docs: record conservative vocabulary import`
- `Fidel_Resources/fidel_resources/` is a non-git workspace with updated local phrasebook decision, schema, editorial handoff, chapter cleanup, and refreshed final QA report.

## Deferred Work

- Do not bulk-import additional vocabulary or phrasebook rows yet; use the de-dupe report and import schema first.
- Keep the `.apkg` untracked and archival until native audio/image assets become an explicit product goal with source-rights review.
- Keep `web_app/` archival as a UX/content reference unless a separate web companion plan is created.
- Deploying or wiring a real waitlist provider for `FidelWeb` is still a product/ops task: production now requires `WAITLIST_WEBHOOK_URL`.

## Repo Status Sweep

- `Fidel/`: active branch `codex/ui-ux-remediation`; many tracked SwiftUI files are modified, and local untracked agent/design/artifact files remain. This document move and instruction refresh should be handled separately from the UI work.
- `FidelWeb/`: clean on `codex/fidelweb-consolidation`.
- `Fidel_Resources/amharic/`: clean tracked state on `codex/resource-consolidation`; pre-existing untracked `.DS_Store`, `.apkg`, and `LearnAmharic/` remain.
- `Fidel_Resources/fidel_resources/`: non-git workspace; local document/chapter/report updates are intentionally uncommitted because this folder has no repository.
