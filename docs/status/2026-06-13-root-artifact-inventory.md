# Root Artifact Inventory

Date: 2026-06-13

This note records local, untracked root material observed during the Friday
admin maintenance sweep. It is an inventory, not an approval to import or ship
the assets.

## Observed Local Material

- `AppStore/Screenshots/iphone-pro-max/` contains five local App Store
  screenshot PNGs for Today, Learn, Practice, Selam, and Progress.
- `design-references/` contains a short README, Amine Store analysis notes, a
  homepage reference PNG, and generated Fidel logo candidates.
- `deep_research_amharic_resources` exists as a loose local root item and needs
  a source/rights review before becoming app content or tracked research.

## Handling Rules

- Keep these files untracked until a specific release, design, or content task
  decides ownership.
- Do not add the screenshot/logo PNGs to app source by default. If they become
  release evidence, prefer `docs/app_store/` notes plus ignored image storage;
  if they become design source, move them under a deliberate `design/` tree.
- Treat `deep_research_amharic_resources` as research/reference only until the
  content provenance and rights path is explicit.
- Bundled learner content still comes from `Fidel/Data/*.json`,
  `Fidel/Data/audio_manifest.json`, and `Fidel/Audio/`.

## Suggested Next Home

- App Store release docs: `docs/app_store/`
- Product/design references: `design/` or `docs/research/`
- Raw/imported content research: sibling resource workspaces described in
  `docs/README.md`
