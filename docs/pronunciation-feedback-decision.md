# Pronunciation Feedback Decision

Date: 2026-05-13

## Decision

Do not build scored pronunciation feedback yet. The product does not currently have a shipped pronunciation/audio content layer, so scoring should stay out of scope until audio content, recognition quality, and privacy/offline constraints are decided.

## Current App State

- The app has implementation hooks for pronunciation practice and local recording, but these are not a finished shipped pronunciation/audio product.
- There is no reviewed native-speaker audio corpus or accepted pronunciation content pipeline.
- The app does not use speech recognition, phoneme scoring, server-side audio upload, or a native-speaker scoring model.

## Why Not Now

- Scoring needs a trustworthy Amharic reference target. That reference content does not exist in the product yet.
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

If pronunciation becomes a near-term goal, start by adding a small rights-reviewed audio/content pilot. A self-rating step such as `Again`, `Close`, or `Good` can come after there is real content to practice against.
