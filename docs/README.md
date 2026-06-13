# Fidel Docs

This folder holds durable planning, status, and decision records for the Fidel iOS product. The app source and bundled learner content remain the source of truth; the sibling repos are supporting surfaces.

## Start Here

- `backlog.md`: future product, content, landing-page, and research work.
- `audio-asset-library.md`: generated pronunciation audio naming, manifest, catalog, and validation rules.
- `root-artifacts.md`: local root-level App Store, design, research, and tracing
  reference buckets that should stay out of accidental app imports.
- `status/fidel-group-audit.md`: group-level consolidation status across iOS, landing page, and resource workspaces.
- `../Fidel_local_first_plan.md`: local-first conversion plan, verification history, and release notes.
- `../README.md`: app overview, build steps, and current content scope.

## Ownership Map

- `../Fidel/`: iOS app source, bundled JSON content, local progress persistence, and learner-facing product behavior.
- `../../FidelWeb/`: Next landing page and waitlist surface.
- `../../Fidel_Resources/amharic/`: tracked research, source CSVs, static PWA reference, and app-import reports.
- `../../Fidel_Resources/fidel_resources/`: non-git phrasebook extraction and editorial workspace.

## Organization Rules

- Keep active product code and docs in this repo.
- Keep raw research, source decks, PDFs, and archive-only material in `Fidel_Resources`.
- Keep large local build output, screenshots, generated caches, and zipped snapshots out of tracked app source.
- When counts change in app JSON, update the landing page and status docs in the same logical workstream.
