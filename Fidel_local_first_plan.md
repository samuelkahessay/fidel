# Fidel Local-First Durable Task List

## Purpose
Convert Fidel into a local-first, no-sign-in iOS app while preserving learner progress, bundled offline content, and a clear task-by-task execution trail.

This document is the durable working checklist. Execute one task at a time. For each task: verify the claim, implement only that task, validate with XcodeBuildMCP, commit, then move to the next unchecked task.

## Working Protocol
- [ ] Before starting a task, verify its claim against the current repo with `rg`, `sed`, `plutil`, `jq`, or XcodeBuildMCP as appropriate.
- [ ] Keep each task scoped to the files listed under "Likely files"; only expand scope if verification proves another file participates in that behavior.
- [ ] Do not use raw `xcodebuild`; use XcodeBuildMCP with project `Fidel.xcodeproj`, scheme `Fidel`, simulator `iPhone 17 Pro`, `useLatestOS: true`, and `suppressWarnings: true`.
- [ ] Run the task's validation command before claiming completion.
- [ ] Commit each completed task with the listed commit message or a more specific equivalent.
- [ ] Preserve unrelated user or generated work in the git tree.

## Verified Current State
- [ ] `Fidel/FidelApp.swift` currently gates launch through `AuthGateView`, Sign in with Apple, Keychain storage, and CloudKit-backed SwiftData.
- [ ] `Fidel/Views/ProgressView.swift` currently imports CloudKit, shows Cloud Sync state, and exposes Sign Out.
- [ ] `ProgressRepository` and `FlashcardManager` currently derive active ownership from `AuthManager`.
- [ ] Bundled content currently includes 8 lessons, 30 patterns, 24 conversations, 174 phrases, 420 vocabulary entries, 20 cultural notes, and 238 Fidel characters.
- [ ] `Fidel.xcodeproj` currently has no dedicated test target.
- [ ] Baseline simulator build succeeded with XcodeBuildMCP for scheme `Fidel` on `iPhone 17 Pro`.

---

## Task 1: Make Launch Local-First

**Claim to verify**
- [x] `Fidel/FidelApp.swift` still imports `AuthenticationServices` and `Security`.
- [x] App launch still renders `AuthGateView()` instead of `ContentView()`.
- [x] SwiftData still configures `cloudKitDatabase: .private(...)`.

**Likely files**
- `Fidel/FidelApp.swift`
- `Fidel/Fidel.entitlements`
- `Fidel/Info.plist`

**Implementation checklist**
- [x] Replace the authenticated launch gate with direct `ContentView()` launch.
- [x] Remove `AuthGateView`, `AppleSignInView`, auth diagnostics, `AuthManager`, and Keychain helpers from `FidelApp.swift`.
- [x] Change the SwiftData `ModelConfiguration` to local storage only by removing the CloudKit database argument.
- [x] Remove Sign in with Apple and CloudKit entitlements from `Fidel/Fidel.entitlements`.
- [x] Remove `remote-notification` from `Fidel/Info.plist` unless a real push path is introduced before this task runs.
- [x] Run `rg -n "AuthGateView|AppleSignInView|AuthenticationServices|Keychain|cloudKitDatabase|com.apple.developer.applesignin|com.apple.developer.icloud|remote-notification" Fidel`.

**XcodeBuildMCP validation command**
- [x] `build_sim` with scheme `Fidel` on `iPhone 17 Pro`.

**Commit message**
- `refactor: launch Fidel as a local-first app`

---

## Task 2: Remove Account and Cloud UI

**Claim to verify**
- [x] `Fidel/Views/ProgressView.swift` still imports CloudKit.
- [x] Progress UI still shows Cloud Sync state.
- [x] Progress UI still exposes Sign Out.

**Likely files**
- `Fidel/Views/ProgressView.swift`

**Implementation checklist**
- [x] Remove `import CloudKit`.
- [x] Remove `@Environment(AuthManager.self)`.
- [x] Remove the Cloud Sync status section and iCloud account refresh task.
- [x] Remove the Sign Out toolbar action.
- [x] Add local-first copy near the top of Progress: "Your progress is saved automatically on this device."
- [x] Run `rg -n "CloudKit|Cloud Sync|Sign Out|iCloud|authManager|refreshCloudKitStatus|CloudKitStatus" Fidel/Views/ProgressView.swift`.

**XcodeBuildMCP validation command**
- [x] `build_sim` with scheme `Fidel` on `iPhone 17 Pro`.

**Commit message**
- `refactor: remove account status from progress dashboard`

---

## Task 3: Use One Local Learner ID

**Claim to verify**
- [x] `ProgressRepository` still falls back to `AuthManager.shared.currentUserId`.
- [x] `FlashcardManager` still falls back to `AuthManager.shared.currentUserId`.
- [x] `AuthManager.previewUserId` is still referenced outside previews or removed launch code.

**Likely files**
- `Fidel/Repositories/ProgressRepository.swift`
- `Fidel/Services/SpacedRepetition.swift`

**Implementation checklist**
- [x] Add a single local learner identifier, `local-device`, in one shared place available to progress and flashcards.
- [x] Keep `ownerUserId` fields in the SwiftData models for migration safety.
- [x] Make `ProgressRepository` use the local learner ID by default.
- [x] Make `FlashcardManager` use the same local learner ID by default.
- [x] Preserve explicit `userId` injection for previews or tests when it already exists.
- [x] Run `rg -n "AuthManager|previewUserId|currentUserId" Fidel`.

**XcodeBuildMCP validation command**
- [x] `build_sim` with scheme `Fidel` on `iPhone 17 Pro`.

**Commit message**
- `refactor: use local learner progress ownership`

---

## Task 4: Remove Migration From Scope

**Claim to verify**
- [x] Fidel has never launched publicly, so there is no production user data to migrate.
- [x] The app can safely standardize on new local-only progress records.
- [x] `ownerUserId` fields can remain for schema stability, but no one-time migration service is required.

**Likely files**
- `Fidel/Repositories/ProgressRepository.swift`
- `Fidel/Services/SpacedRepetition.swift`

**Implementation checklist**
- [x] Do not add a dedicated progress migration service.
- [x] Keep local progress creation simple and deterministic.
- [x] Keep duplicate consolidation helpers only if they are still useful for defensive cleanup inside repositories.
- [x] Remove any plan or code language implying a production migration is needed.
- [x] Confirm `find Fidel -name '*Migration*' -print` does not show a progress migration implementation.

**XcodeBuildMCP validation command**
- [x] `build_sim` with scheme `Fidel` on `iPhone 17 Pro`.

**Commit message**
- `docs: remove migration requirement from local-first plan`

---

## Task 5: Add Local Settings and Config Storage

**Claim to verify**
- [x] Daily goal is stored on `UserProgress` but has no dedicated settings experience.
- [x] Selam coaching settings already use `UserDefaults`.
- [x] There is no shared app settings store for local preferences.

**Likely files**
- `Fidel/Services/AppSettingsStore.swift`
- `Fidel/Views/ProgressView.swift`
- `Fidel/Repositories/SelamRepository.swift`

**Implementation checklist**
- [x] Add `SettingsKeys` constants for daily XP goal, preferred response language, transliteration visibility, auto-play pronunciation, haptics, selected reference tab, AI tools visibility, onboarding complete, and last opened activity.
- [x] Add `AppSettingsStore` backed by `UserDefaults`.
- [x] Keep small preferences in `UserDefaults`; reserve Application Support JSON for larger export/import or content-pack data.
- [x] Connect daily XP goal display and editing to the settings store.
- [x] Leave SwiftData progress counters in SwiftData.

**XcodeBuildMCP validation command**
- [x] `build_sim` with scheme `Fidel` on `iPhone 17 Pro`.

**Commit message**
- `feat: add local app settings store`

---

## Task 6: Expose Full Bundled Content

**Claim to verify**
- [x] `Fidel/Data/conversations.json` contains 24 conversations.
- [x] `LearningStage.availableConversationIds` currently exposes only conversations 1 through 18 in Fluency.
- [x] `ReferenceView` groups phrases with hard-coded ID ranges.

**Likely files**
- `Fidel/Models/LearningStage.swift`
- `Fidel/Views/ReferenceView.swift`
- `Fidel/ViewModels/ReferenceViewModel.swift`
- `Fidel/Models/Models.swift`

**Implementation checklist**
- [x] Update Fluency conversation availability to include all 24 bundled conversations.
- [x] Decide whether lessons 6 through 8 remain Fluency electives or become earlier advanced content based on the existing stage descriptions.
- [x] Replace phrase ID-band grouping with data-driven grouping from existing phrase data or a local metadata map.
- [x] Add reference navigation for cultural notes if the data is already loaded by `LessonRepository`.
- [x] Run `jq length Fidel/Data/conversations.json Fidel/Data/phrases.json Fidel/Data/cultural_notes.json`.

**XcodeBuildMCP validation command**
- [x] `build_sim` with scheme `Fidel` on `iPhone 17 Pro`.

**Commit message**
- `feat: expose bundled reference content`

---

## Task 7: Fix Flashcard Due-Card Flow

**Claim to verify**
- [x] `FlashcardViewModel.startSession` currently uses shuffled random vocabulary.
- [x] `ProgressRepository` already exposes `initializeFlashcards` and `getDueFlashcards`.
- [x] Reviews already update FSRS scheduling state.

**Likely files**
- `Fidel/ViewModels/FlashcardViewModel.swift`
- `Fidel/Views/FlashcardView.swift`
- `Fidel/Repositories/ProgressRepository.swift`

**Implementation checklist**
- [x] Initialize vocabulary and phrase flashcard progress before loading a session.
- [x] Load due vocabulary cards first.
- [x] Fill remaining session slots with new or not-due vocabulary cards when due cards are fewer than the requested count.
- [x] Keep filtered vocabulary sessions working for lesson-specific practice.
- [x] Ensure review swipes continue recording FSRS ratings.

**XcodeBuildMCP validation command**
- [x] `build_sim` with scheme `Fidel` on `iPhone 17 Pro`.

**Commit message**
- `feat: prioritize due flashcards`

---

## Task 8: Wire Stage Advancement Into Completion Paths

**Claim to verify**
- [x] `StageManager.checkAndAdvanceStage()` exists.
- [x] `JourneyViewModel.checkAdvancement()` exists.
- [x] Lesson completion, conversation completion, vocabulary mastery, and tracing currently do not reliably trigger advancement checks from their completion paths.

**Likely files**
- `Fidel/Views/JourneyView.swift`
- `Fidel/ViewModels/JourneyViewModel.swift`
- `Fidel/Views/LessonComponents.swift`
- `Fidel/Views/ConversationDetailView.swift`
- `Fidel/ViewModels/TracingViewModel.swift`
- `Fidel/Repositories/ProgressRepository.swift`

**Implementation checklist**
- [x] Trigger stage advancement checks after lesson completion.
- [x] Trigger stage advancement checks after conversation completion.
- [x] Trigger stage advancement checks after Fidel recognition or tracing milestones.
- [x] Trigger stage advancement checks after vocabulary mastery when that path records mastery.
- [x] Refresh Journey after returning from child activities so newly unlocked content appears.
- [x] Preserve the existing stage advancement presentation.

**XcodeBuildMCP validation command**
- [x] `build_sim` with scheme `Fidel` on `iPhone 17 Pro`.

**Commit message**
- `feat: advance stages after learning milestones`

---

## Task 9: Add Optional Export and Import Backup

**Claim to verify**
- [x] Local-first removes account sync and CloudKit backup from the core path.
- [x] There is no existing user-controlled progress export/import service.
- [x] Progress and flashcard records are sufficient for a basic backup snapshot.

**Likely files**
- `Fidel/Services/ProgressExportService.swift`
- `Fidel/Views/ProgressView.swift`
- `Fidel/Models/Models.swift`

**Implementation checklist**
- [x] Define a versioned Codable snapshot for `UserProgress`, `FlashcardProgress`, and relevant local settings.
- [x] Export the snapshot as JSON through a Files share/export flow.
- [x] Import a snapshot through Files, merge it into the local learner record, and preserve the strongest progress values.
- [x] Show clear local backup copy: "Export a backup file you control."
- [x] Keep import failure messages specific and recoverable.

**XcodeBuildMCP validation command**
- [x] `build_sim` with scheme `Fidel` on `iPhone 17 Pro`.

**Commit message**
- `feat: add local progress backup files`

---

## Task 10: Add Test Targets and Critical Coverage

**Claim to verify**
- [x] `Fidel.xcodeproj` currently has only the app target.
- [x] There is no `FidelTests` or `FidelUITests` target.
- [x] Critical local-first behavior has no automated coverage.

**Likely files**
- `Fidel.xcodeproj/project.pbxproj`
- `FidelTests/*`
- `FidelUITests/*`

**Implementation checklist**
- [x] Add a unit test target named `FidelTests`.
- [x] Add tests for local progress creation on first launch.
- [x] Add tests for deterministic local progress creation under `local-device`.
- [x] Add tests for flashcard due-card ordering.
- [x] Add tests for settings persistence.
- [x] Keep UI target creation out of this pass because the new unit target validates the local-first core and XcodeBuildMCP `test_sim` is reliable.
- [x] Defer launch-screen UI coverage to final simulator QA with `build_run_sim`.

**XcodeBuildMCP validation command**
- [x] `test_sim` with scheme `Fidel` on `iPhone 17 Pro`.

**Commit message**
- `test: cover local-first progress behavior`

---

## Task 11: Final Local-First QA and Cleanup

**Claim to verify**
- [ ] No auth/account/cloud runtime references remain unless explicitly kept for optional services outside the core app path.
- [ ] Core lessons, practice, reference, and progress work without sign-in.
- [ ] All local-first tasks above have been checked off and committed.

**Likely files**
- `README.md`
- `AUTH_DATABASE_SETUP.md`
- `Fidel_local_first_plan.md`
- Any source files flagged by final searches

**Implementation checklist**
- [ ] Run `rg -n "AuthManager|AuthGateView|AppleSignInView|AuthenticationServices|Keychain|CloudKit|cloudKitDatabase|Sign Out|Cloud Sync|iCloud|sign in|account" Fidel README.md AUTH_DATABASE_SETUP.md`.
- [ ] Remove or update outdated account/cloud language in user-facing docs.
- [ ] Run `build_sim`.
- [ ] Run `test_sim` after test targets exist.
- [ ] Run the app with `build_run_sim` and manually verify launch goes directly to learning content.
- [ ] Manually verify Progress copy explains local device persistence.
- [ ] Manually verify Reference exposes the full bundled content.
- [ ] Mark this plan's completed task checkboxes only after fresh verification.

**XcodeBuildMCP validation command**
- [ ] `build_sim`, `test_sim`, and `build_run_sim` with scheme `Fidel` on `iPhone 17 Pro`.

**Commit message**
- `chore: finish local-first cleanup`

---

## Completion Criteria
- [ ] App opens directly into learning content.
- [ ] No sign-in or account state appears in the core UX.
- [ ] SwiftData persistence is local-only.
- [ ] Progress persists between launches under the single local learner ID.
- [ ] New progress is created under the local learner record without account setup.
- [ ] Settings persist locally.
- [ ] Core lessons, practice, reference, and progress work offline.
- [ ] Full bundled content is accessible through coherent app surfaces.
- [ ] Flashcards prefer due cards and keep FSRS scheduling state.
- [ ] Stage advancement happens after learning milestones.
- [ ] Tests cover the critical local-first flows.
- [ ] Final XcodeBuildMCP build and test validations pass.
