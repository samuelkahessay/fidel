# Fidel Backlog

Last updated: 2026-05-13
Last audited: 2026-05-13

This is the single parking lot for future Fidel app, landing page, and content-pipeline work. Completed plans and historical audit checklists should link here instead of carrying their own separate future-work lists.

## Active

No active backlog items.

## Ready Next

- 2026-05-13 [content] Review the remaining vocabulary import queue from `../../Fidel_Resources/amharic/VOCAB_DEDUPE_REPORT.md`, starting with unimported clean candidates; fix or exclude rows with missing English, concatenated glosses, broad `Other` category, or embedded media tags.
- 2026-05-13 [content] Build a small phrasebook pilot review sheet from `../../Fidel_Resources/fidel_resources/PHRASEBOOK_IMPORT_SCHEMA.md`; keep phrasebook content reference-only until a reviewed pilot set is accepted.
- 2026-05-13 [feature] Run a post-UI-branch tracing QA pass: tracing, stroke recordings, animation, and unit coverage exist, so focus on remaining UX gaps instead of adding handwriting from scratch.
- 2026-05-13 [feature] Decide whether pronunciation needs scored feedback; the current pronunciation flow plays TTS/ElevenLabs audio and records user playback, but there is no speech-recognition feedback loop.

## Later

- 2026-05-13 [feature] Decide whether licensed native-speaker media should replace or supplement TTS/ElevenLabs pronunciation; if yes, design a rights-reviewed asset pipeline before importing files.
- 2026-05-13 [feature] Design downloadable content packs only after content provenance, media rights, and local-first/offline packaging rules are settled.

## Blocked Or Not Now

- 2026-05-13 [not-now] Configure durable waitlist storage for `FidelWeb`: the subscribe API already supports `WAITLIST_WEBHOOK_URL`; choose the provider, set production env vars, and verify a real signup is stored when launch ops becomes active again.
- 2026-05-13 [blocked] Do not bulk-import vocabulary or phrasebook rows until the review queue, provenance strategy, de-dupe rules, and rights/source review are applied.
- 2026-05-13 [blocked] Keep `.apkg` media archival until source-rights review, audio-quality review, image-rights review, and mapping verification make app usage acceptable.
- 2026-05-13 [blocked] Keep the static speaking-practice PWA archival; do not invest in public companion work unless a separate web product goal reopens that decision.

## Completed

- 2026-05-13 [debt] Finished the active `codex/ui-ux-remediation` work: XcodeBuildMCP `build_sim` succeeded, `test_sim` passed 15/15, simulator launch succeeded after clearing a stale install state, and Journey/Tools/Progress tab smoke checks passed.
