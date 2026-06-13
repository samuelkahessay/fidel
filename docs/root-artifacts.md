# Fidel Root Artifacts

This note records local root-level reference material that should not be
mistaken for app source or active import work.

## Current Local Buckets

- `AppStore/`: local App Store screenshot, metadata, and review-prep material.
  Keep generated images and upload-only assets out of the app target unless a
  release task deliberately promotes them.
- `design-references/`: design inspiration, generated logo explorations, and
  visual reference notes. It can inform future product/design work, but it is
  not bundled learner content.
- `deep_research_amharic_resources`: research note about the wider Amharic
  learning ecosystem. Treat it as product-research input, not importable app
  JSON.
- `fidel drawing artifacts and passes/`: older tracing screenshots and screen
  recordings. This is ignored local history and should remain outside git.

## Handling Rules

- Keep the iOS app source of truth in `Fidel/`, `FidelTests/`, `docs/`, and the
  tracked JSON/audio resources already bundled by the app.
- Keep raw research, source decks, PDFs, and phrasebook extraction work in the
  sibling `Fidel_Resources` workspaces unless a reviewed import task promotes a
  small derived artifact.
- Do not bulk-import resource or phrasebook content into app JSON from these
  local root files.
- If an asset becomes release-critical, move or recreate it in a deliberate
  app-owned home such as `docs/`, `Fidel/Assets.xcassets/`, or a documented
  App Store asset folder, then commit that scoped change separately.
