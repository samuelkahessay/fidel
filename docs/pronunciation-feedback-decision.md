# Pronunciation Feedback Decision

Date: 2026-05-13

## Decision

Do not build scored pronunciation feedback yet. The product now has a generated offline pronunciation-audio pilot, but scoring should stay out of scope until Amharic recognition quality, reference quality, and privacy/offline constraints are proven.

Update: pronunciation content started with the Azure-generated offline audio pilot, not scoring. The app bundles 25 generated phrase clips and labels them as generated pronunciation.

## Current App State

- The app has a shipped generated pronunciation pilot for 25 phrase clips.
- There is no reviewed native-speaker audio corpus. The accepted first pronunciation pipeline is an Azure-generated, clearly labeled, offline-bundled pilot.
- The app does not use speech recognition, phoneme scoring, server-side audio upload, or a native-speaker scoring model.

## Why Not Now

- Scoring needs a trustworthy Amharic reference target. The current generated clips are useful for practice but are not native-speaker proof.
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

Pronunciation content is now available through the Azure-generated offline pilot. A self-rating step such as `Again`, `Close`, or `Good` can come later if it stays clearly separate from automated scoring.
