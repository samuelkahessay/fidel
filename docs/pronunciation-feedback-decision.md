# Pronunciation Feedback Decision

Date: 2026-05-13

## Decision

Do not build scored pronunciation feedback yet. Keep the current listen, record, playback, and self-compare loop as the supported pronunciation experience until reference audio, recognition quality, and privacy/offline constraints are decided.

## Current App State

- `PronunciationPracticeView` supports phrase, vocabulary, and Fidel practice modes.
- `AudioService` plays generated Amharic speech and records local `.m4a` learner audio for playback.
- The app does not use speech recognition, phoneme scoring, server-side audio upload, or a native-speaker scoring model.

## Why Not Now

- Scoring needs a trustworthy Amharic reference target. The current audio path is generated speech, not a rights-reviewed native-speaker corpus.
- Speech-recognition quality for Amharic should be proven before it becomes learner-facing feedback.
- Audio scoring has privacy and offline-product implications that do not match the current local-first app shape without an explicit design.
- A weak score would be worse than no score because it would teach false confidence or false corrections.

## Reopen Criteria

Reconsider scored feedback when all of these are true:

- Native-speaker or otherwise validated reference audio is available for a reviewed lesson slice.
- The scoring engine can be evaluated against Amharic examples with known expected outcomes.
- The product decision is made for local-only, on-device recognition, or explicit opt-in server processing.
- The UI can explain scores as practice guidance, not as authoritative fluency judgment.

## Near-Term Alternative

If pronunciation needs more structure before scoring is ready, add a lightweight self-rating step after playback: `Again`, `Close`, or `Good`, stored locally like other practice progress.
