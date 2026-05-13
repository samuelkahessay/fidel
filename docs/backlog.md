# Fidel Backlog

Last updated: 2026-05-13
Last audited: 2026-05-13

This is the single parking lot for future Fidel app, landing page, and content-pipeline work. Completed plans and historical audit checklists should link here instead of carrying their own separate future-work lists.

## Active

- 2026-05-13 [feature] Finish the Azure-generated pronunciation pilot: app-side manifest loading, bundled playback, phrase-row gating, Journey gating, and generation tooling are implemented; remaining work is to provide Azure Speech credentials, generate 25 MP3s, add them to the Xcode resources, validate playback, and update shipped-scope docs.

## Ready Next

No ready-next backlog items.

## Later

- 2026-05-13 [feature] Design downloadable content packs only after content provenance, media rights, and local-first/offline packaging rules are settled.

## Blocked Or Not Now

- 2026-05-13 [not-now] Configure durable waitlist storage for `FidelWeb`: the subscribe API already supports `WAITLIST_WEBHOOK_URL`; choose the provider, set production env vars, and verify a real signup is stored when launch ops becomes active again.
- 2026-05-13 [not-now] Keep pronunciation scoring out of scope because the product does not currently have shipped pronunciation/audio content; revisit only after reference audio, Amharic recognition quality, privacy/offline policy, and score-copy expectations are proven; see `pronunciation-feedback-decision.md`.
- 2026-05-13 [blocked] Keep the remaining vocabulary import queue blocked on editorial cleanup/native review: after the 16-word conservative import, the remaining likely-new rows are mostly concatenated verb rows, blank-English rows, embedded-media rows, or broad `Other` category rows.
- 2026-05-13 [blocked] Do not bulk-import vocabulary or phrasebook rows until the review queue, provenance strategy, de-dupe rules, and rights/source review are applied.
- 2026-05-13 [blocked] Keep `.apkg` media archival until source-rights review, audio-quality review, image-rights review, and mapping verification make app usage acceptable.
- 2026-05-13 [blocked] Keep the static speaking-practice PWA archival; do not invest in public companion work unless a separate web product goal reopens that decision.

## Completed

- 2026-05-13 [debt] Finished the active `codex/ui-ux-remediation` work: XcodeBuildMCP `build_sim` succeeded, `test_sim` passed 15/15, simulator launch succeeded after clearing a stale install state, and Journey/Tools/Progress tab smoke checks passed.
- 2026-05-13 [content] Built the small phrasebook pilot review sheet at `../../Fidel_Resources/fidel_resources/PHRASEBOOK_PILOT_REVIEW.md` and refreshed stale phrasebook product-decision counts.
- 2026-05-13 [content] Accepted the phrasebook pilot as a review-only direction and generated provenance-preserving review artifacts at `../../Fidel_Resources/fidel_resources/PHRASEBOOK_PILOT_REVIEW.csv` and `../../Fidel_Resources/fidel_resources/PHRASEBOOK_PILOT_REVIEW.json`; no iOS app data was changed.
- 2026-05-13 [feature] Completed the post-UI-branch tracing QA pass: launched Character Tracing in the simulator, verified animated-guide handoff to drawing canvas, confirmed a drawn stroke enables Clear/Check, and confirmed low-coverage feedback returns Try Again/Skip.
- 2026-05-13 [feature] Decided pronunciation scoring is not now and documented reopen criteria in `pronunciation-feedback-decision.md`; the app should not imply a shipped audio/pronunciation product until reference audio/content exists.
