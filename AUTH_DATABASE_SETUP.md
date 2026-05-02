# Fidel Local Data & Backup Guide

Fidel is a local-first learning app. Core lessons, practice, reference content, progress, settings, and backups work without a remote identity provider or hosted database.

---

## Data Strategy

### SwiftData
Use SwiftData for learner progress that benefits from model relationships and local persistence:
- `UserProgress`
- `FlashcardProgress`
- `SelamConversation`
- `SelamMessage`

Progress records use the device-scoped owner ID `local-device`. The field remains in the schema to keep repository queries stable, but there is no multi-user runtime path.

### UserDefaults
Use `AppSettingsStore` for lightweight preferences:
- daily XP goal
- preferred response language
- transliteration visibility
- auto-play pronunciation
- haptics
- selected reference tab
- AI tools visibility
- onboarding complete
- last opened activity

### Application Support / Files
Use JSON files for user-controlled backup and restore. `ProgressExportService` exports a versioned snapshot containing:
- user progress
- flashcard scheduling state
- local settings

Imports merge the backup into the local learner record and keep the strongest progress values.

---

## Build Notes

Use XcodeBuildMCP for all project validation:
- project: `Fidel.xcodeproj`
- scheme: `Fidel`
- simulator: `iPhone 17 Pro`
- `useLatestOS: true`
- `suppressWarnings: true`

Common validation commands:
- `build_sim`
- `test_sim`
- `build_run_sim`

---

## Release Checklist

- [ ] `build_sim` succeeds.
- [ ] `test_sim` succeeds.
- [ ] The app launches directly into learning content.
- [ ] Progress creates under `local-device`.
- [ ] Daily XP goal changes persist across launches.
- [ ] Flashcards load due cards first.
- [ ] Reference exposes lessons, phrases, vocabulary, culture notes, and numeric reference data.
- [ ] Export creates a readable JSON backup.
- [ ] Import restores progress/settings from a valid backup file.
