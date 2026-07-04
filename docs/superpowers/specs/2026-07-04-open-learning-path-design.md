# Open learning path — remove hard gating, configurable pace, smart recommendations — design

Date: 2026-07-04
Status: Approved (design)

## Problem

The app's 4-stage **hard gate** discourages new learners and hurts retention. In the user's words: "we can't configure the number of fidel we get to practice and how that gates what we do next — it hurts stickiness; people get discouraged and leave." Two concrete, code-level causes:

1. **Fixed practice size.** `TracingSessionViewModel.standardSessionSize = 8` (`ViewModels/TracingSessionViewModel.swift:64`) is hardcoded. Every "Practice Fidel" session is exactly 8 characters; the learner cannot choose a shorter or longer session.
2. **A 50-character wall in front of all real content.** `LearningStage.fidelRecognitionTarget = 50` (`Models/LearningStage.swift:99`) gates greetings, phrases, lessons, and conversations behind recognizing **50 of 238** characters. Stage 0 exposes *only* Fidel flashcards/quiz/tracing (`LearningStage.swift:65–90`); everything else is locked until 50 recognized. The prior spec measured this at **"~7–10 sessions"** of abstract script before any spoken Amharic (`docs/superpowers/specs/2026-06-27-fidel-learn-recognition-design.md`, "Reachability" note).

This wall sits exactly where motivation is highest and most fragile — the first sessions — which is the worst possible place for friction.

## Relationship to prior work

This **supersedes the *gating* decisions** of `2026-06-27-fidel-learn-recognition-design.md`. That work made the wall *clearer* (a next-action hero, per-activity progress, refresh-on-return) but deliberately **kept** the wall and the `fidel_50` criterion. This redesign removes the wall and **reuses everything that spec built** — `NextActionHero`, `HeroAction`, `HeroStyle`, `ActivityProgress`, and the `.onChange` refresh-on-return handlers become the foundation of the open, recommendation-driven path. The gate is retired; the scaffolding is repurposed. No prior work is wasted.

## User decisions (brainstorming)

1. **Scope:** full path redesign, not a point fix.
2. **Script ↔ content:** **interleave from lesson 1** — characters are taught *inside* the words of each lesson; no "learn the alphabet first" wall (how Duolingo teaches Japanese/Korean/Hindi).
3. **Unlock rule:** **fully open, recommendation-driven** — nothing is ever locked; a strong "recommended next" guides beginners; power users tap anywhere.
4. **Build scope:** **Open Path + Smart Next** — the full coherent redesign built on existing SwiftData models + FSRS. *Deferred to later passes:* onboarding placement test, weekly leagues, Birdbrain-style adaptive difficulty, Practice Hub. *Excluded on principle:* an energy/hearts system.
5. **Tracing:** on a correct trace, **pause a beat, then auto-advance** (respect Reduce Motion / VoiceOver).
6. **Configurable session length** is a given in every version.

## Research basis (see synthesis in conversation)

- **Autonomy is the most defensible retention lever** (Self-Determination Theory). A self-chosen pace is the reference point every other mechanic hangs off.
- **Duolingo *started* fully open (the skill tree) and abandoned it in 2022** because open + no guidance caused decision paralysis. The resolution is not locks — it is a *great recommended-next-step* over open content. This is why `NextStepPlanner` (§4) is the centerpiece.
- **Khan Academy** is the model for mastery done right: content stays browsable; mastery is a *displayed level*, not a gate.
- **Anki** proves the scheduler is the gate: a due-queue plus throttled new-item intake, no content locks.
- **Streaks need built-in slack** (freezes/repair) or the first miss causes quitting.
- **Avoid energy/hearts** — Duolingo's 2025 Energy rollout is a live churn cautionary tale.

## Key existing facts (verified)

- **FSRS scheduler already exists** (`Services/SpacedRepetition.swift`): `FlashcardManager.getDueItems(type:)` (`:197`), `FSRSAlgorithm.getDueCards` (`:135`), `getRetrievability(for:)` (`:149`), `requestRetention = 0.9`. Cards exist for `"vocabulary"` and `"phrase"` item types (`initializeVocabularyCards`, `:220`).
- **Recognition** is written via `UserProgress.recognizeFidelCharacter(_:)` (+2 XP, `Models/Models.swift:183`) and `traceCharacter(_:)` (+5 XP, also recognizes, `:191`).
- **Reusable hero/progress types already exist** in `ViewModels/JourneyViewModel.swift`: `ActivityProgress` (`:16`), `JourneyActivity` (`:27`), `HeroAction` (`:41`), `HeroStyle` (`:50`), `NextActionHero` (`:60`) — currently derived from gating criteria.
- **The gate** lives in `LearningStage.criteria(for:)` (`:103`) + `StageManager.checkAndAdvanceStage()` (`:80`) / `isStageUnlocked(_:)` (`:73`); content is filtered by `StageManager.available{Lessons,Conversations,PracticeModes,Vocabulary,Phrases}()` (`:21–54`).
- **Content** is bundled value types: `Lesson { patterns, vocabulary, phrases, isCompleted, progressPercent }` (`Models/Models.swift:86`) with **no** character map. `FidelCharacter.id = "\(rowIndex)-\(vowelOrder)"`, `.character` is the glyph (`:75`).
- **Lesson completion** hook: `ProgressRepository.completeLesson(_:)` (`:111`) → `UserProgress.completeLesson(_:)`.
- **Ring UI**: `AccessibleProgressRing` (used in `JourneyView.swift:225`, `TracingSessionView.swift:56`, `FlashcardView.swift:283`); also `ProgressRing` (`Theme.swift:579`), `FidelProgressBar` (`Components.swift:123`).
- **Pace config today**: `AppSettingsStore.dailyXPGoal` (clamped 10–500, `AppSettingsStore.swift:88`), `UserProgress.dailyGoal`, tracing `standardSessionSize = 8` / `maxPromotionItems = 3` (`:64–65`, used at `:160/168/175/179`).
- **No first-run onboarding flow** exists — only an `onboardingComplete` flag (`AppSettingsStore.swift:11`) and `SelamWelcomeView` (chat only). A pace picker at first run must be *created* (kept optional here).
- **Gate/pace call sites (blast radius):** `ContentView.swift:465,477`; `JourneyViewModel.swift:80–122,156–171,239,259,337–414`; `JourneyView.swift:26,96–104,193–198,208–276,327–340`; `ProgressRepository.swift:213–222,360,389–391,414`; `ProgressView.swift:62,266–276`; `ProgressExportService.swift:58,63,94,105,184,189,224`.

## Design

### 1. Retire the gate, keep the taxonomy

`LearningStage` currently *groups* content **and** *gates* it. Keep the grouping (the 4 themes become **section headers** in one always-open path — Duolingo's "Sections"), delete the gating.

- **Remove:** `fidelRecognitionTarget`; `StageCriterion` and `LearningStage.criteria(for:)`; `StageManager.checkAndAdvanceStage`, `criteriaForNextStage`, `progressToNextStage`, `isStageUnlocked`; `JourneyViewModel.lockedStages`, `checkAdvancement`, `progressToNextStage`; the `.disabled(...)` gate at `JourneyView.swift:198`.
- **`StageManager` → thin content provider.** Its `available*()` methods return **all** lessons/conversations/practice modes/vocab/phrases (no stage filter). Consider renaming to `CurriculumProvider` in the plan; keep the type to minimize churn if simpler.
- `UserProgress.currentStage` **stays as a field** (still round-tripped by `ProgressExportService`) but is **read-only for display** ("furthest section reached") at `ProgressView.swift:62` and `ContentView.swift:465`. It never gates.

### 2. Interleave: derive the character↔lesson map from words

No hand-authored map. A lesson "owns" the Fidel characters that **appear in its own vocabulary and phrases**.

```swift
// New: CurriculumService (or AmharicData extension)
static func glyphIndex() -> [String: FidelCharacter]   // FidelCharacter.character -> char, built from the chart
static func characters(in lesson: Lesson) -> [FidelCharacter]  // scan amharic strings of vocab+phrases, map each Ethiopic scalar via glyphIndex
```

**Crediting:** on lesson completion (`UserProgress.completeLesson(_:)` / `ProgressRepository.completeLesson`), call `recognizeFidelCharacter(_:)` for each derived character. Result: script recognition grows *through* content, from lesson 1. Dedicated tracing remains available as optional reinforcement — no longer a gate.

*Rationale:* self-maintaining (add a word → its characters are covered automatically; single source of truth), and every character is met inside a real word (contextual encoding).

### 3. Mastery as derived display (rings), never a gate

Lesson mastery is **computed, not stored** (no new gate field). Inputs per lesson: its vocab/phrase FSRS states (`getRetrievability`/stability) + its derived characters' recognized/trace state.

```swift
enum MasteryTier { case new, started, familiar, proficient, mastered }
// Thresholds as named constants (tune in review):
//   started   > 0% items engaged
//   familiar  >= 0.50 of items "learned"
//   proficient>= 0.80
//   mastered  == 1.0 AND mean retrievability >= 0.9
```

An item counts as "learned" if it is in the mastered/recognized set **or** its FSRS stability clears a small threshold. Rendered as an `AccessibleProgressRing` on each lesson card plus a tier label. Display only; competence feedback (SDT-informational), not a control. Doubles as endowed-progress scaffolding (a touched lesson never shows an empty ring).

### 4. `NextStepPlanner` — the "Smart Next" engine (centerpiece)

A new `@MainActor` service composing the recommended session from signals that already exist.

```swift
struct RecommendedSession {
    enum Kind: Equatable { case reviews, resumeLesson(Int), newLesson(Int), mixed, allCaughtUp }
    let kind: Kind
    let reviewCount: Int
    let newCount: Int
    let estimatedMinutes: Int
    let heroAction: HeroAction        // reuse existing enum
    let eyebrow: String; let title: String; let detail: String  // -> NextActionHero
}

@MainActor final class NextStepPlanner {
    func plan(progress: UserProgress,
              tier: DailyGoalTier,
              dueItems: [FlashcardProgress],
              lessons: [Lesson]) -> RecommendedSession
}
```

**Priority order:** (1) **due reviews** first, capped at `tier.reviewCap` (SRS best practice; the cap prevents backlog overwhelm); (2) **resume** an in-progress lesson (`Lesson.progressPercent > 0 && !completed`); (3) **next new** lesson in path order (first id not in `lessonsCompleted`), new-item intake capped at `tier.newCap`. When no reviews are due and every lesson is started → `.allCaughtUp`. Output feeds the existing `NextActionHero`; add `.recommended` and `.allCaughtUp` to `HeroStyle`.

### 5. Configurable pace — goal tiers

Session size becomes a user setting (directly fixes complaint #1).

```swift
enum DailyGoalTier: String, CaseIterable, Codable {
    case casual, regular, serious, intense   // default: .regular (preserves the current 8-char tracing session)
    var newCap: Int            // 3 / 5 / 8 / 12
    var reviewCap: Int         // 10 / 15 / 20 / 30
    var tracingSessionSize: Int// 5 / 8 / 12 / 16   (regular == 8 keeps today's default)
    var estimatedMinutes: Int  // 2 / 5 / 10 / 15
    var suggestedDailyXP: Int  // 10 / 20 / 30 / 50 (Duolingo ladder)
}
```

- Add `AppSettingsStore.dailyGoalTier` (default `.regular`). It is the **single pace control**; it drives the recommendation size (§4) and the tracing session size (§7).
- `dailyXPGoal` **stays** as the daily-XP-ring target (keeps `ContentView.swift:477`, `ProgressView.swift:266–276` working); at onboarding we *suggest* `tier.suggestedDailyXP`, but never overwrite a user's custom value on migration.
- **Settings UI:** a segmented tier picker with per-tier time/size labels (in the You/Progress settings area).
- **Onboarding (optional, low priority):** a one-screen pace sheet gated on `!onboardingComplete`. If deferred, the default `.regular` + Settings control still fully satisfy the requirement.

### 6. Open-path screen (`JourneyView` rework)

New top-to-bottom: **Header** (XP, streak, today's daily-goal ring — keep) → **Recommended hero** (from §4; one CTA) → **Open path** (section headers → lesson cards, each with an `AccessibleProgressRing` mastery ring + tier label, **all tappable**; in-progress lesson highlighted; new lessons show a "Start" affordance).

**Deleted views:** `lockedStagesSection` (`:337`), `LockedStageCard` (`:465`), `LockedStageSheet` (`:505`), the `.disabled` gate (`:198`), the "next-stage criteria" checklist (`:251–276`). Reuses `AccessibleProgressRing`, `FidelProgressBar`, `GlassChip`, Theme card styles — no new design-system work. (~150 lines of lock/criteria UI removed.)

### 7. Auto-advance tracing + configurable size

**File `Views/TracingSessionView.swift:176–181`** — replace the "No auto-advance" block:

```swift
.task(id: celebrationTaskKey) {
    guard viewModel.itemPhase == .celebrating else { return }
    viewModel.prewarmNextCharacter()
    let pause: Duration = reduceMotion ? .seconds(1.6) : .milliseconds(900)
    try? await Task.sleep(for: pause)
    guard !Task.isCancelled, viewModel.itemPhase == .celebrating else { return }
    if UIAccessibility.isVoiceOverRunning { return }   // VoiceOver advances via the button
    viewModel.advanceAfterCelebration()
}
```

The **"Continue"/"Finish"** button stays (now "advance now — skip the beat"); the last item still routes to completion via existing `advanceToNextItem()`. `reduceMotion` is already in scope (used at `:173`).

**Configurable size:** `standardSessionSize` / `maxPromotionItems` (`TracingSessionViewModel.swift:64–65`) stop being hardcoded and derive from `DailyGoalTier.tracingSessionSize` (keep `maxPromotionItems` ~= `size * 0.4`, min 1). Thread the size into `startSession(plan:)` / `composeStandardSession`.

### 8. Streak with slack *(can ship as a fast-follow to keep PR #1 tight)*

Add to `UserProgress`: `streakFreezesAvailable: Int = 0`, `weeklyStreakCount: Int = 0`, `lastFreezeGrantWeek: Int = 0` (+ any anchor date needed). Update `checkStreak()` (`Models/Models.swift:213`) to auto-grant ~1–2 freezes/week and **auto-consume one on a missed day instead of resetting**; maintain a parallel **weekly streak** so one slip never zeroes identity. One-tap repair in the You tab. Never punish beyond the recoverable streak.

### 9. Migration & backward-compat

- New `UserProgress` fields are **additive with defaults** → SwiftData lightweight migration, no mapping code.
- `currentStage` retained and round-tripped; no longer gates. Existing `lessonsCompleted` / `vocabularyMastered` / `fidelCharactersRecognized` map straight into mastery display — **existing users see all content unlocked and their history reflected as mastery**.
- `ProgressExportService` gains `dailyGoalTier` + streak-slack fields in the snapshot and merge (`:58–224`); keep existing fields for round-trip.
- `AppSettingsStore`: add `dailyGoalTier` key + default registration; keep `dailyXPGoal`.

## Files touched

- `Models/LearningStage.swift` — delete criteria/gate; keep enum as section labels; remove `fidelRecognitionTarget`, `StageCriterion`.
- `Models/Models.swift` — `UserProgress`: streak-slack fields; credit derived characters in `completeLesson`; `checkStreak` slack.
- `Services/StageManager.swift` — strip gating; return all content (or rename to `CurriculumProvider`).
- `Services/NextStepPlanner.swift` — **new** recommendation engine.
- `Services/CurriculumService.swift` (or `AmharicData` ext) — **new** glyph index + `characters(in:)`; lesson mastery computation.
- `Services/AppSettingsStore.swift` — `dailyGoalTier`.
- `ViewModels/JourneyViewModel.swift` — replace gating/activity-building with open-path + `NextStepPlanner`; repurpose hero; drop `lockedStages`/`checkAdvancement`.
- `ViewModels/TracingSessionViewModel.swift` — tier-driven session size.
- `Views/JourneyView.swift` — open-path UI; remove locked/criteria views; mastery rings.
- `Views/TracingSessionView.swift` — auto-advance.
- `Views/ProgressView.swift` — tier picker; `currentStage` display only.
- `ContentView.swift` — Today routing/copy; tier-aware; `currentStage` display only.
- `Services/ProgressExportService.swift` — new fields in snapshot/merge.
- `FidelTests/` — new tests (below); update/remove stage-gating tests.

## Testing

XCTest with in-memory `ModelContainer` fixtures (existing convention).

- **`NextStepPlanner`**: fresh user → `newLesson(1)`; items due → `reviews`/`mixed`, reviews first, respect `reviewCap`; mid-lesson → `resumeLesson`; nothing due + all started → `.allCaughtUp`.
- **`DailyGoalTier`**: `newCap`/`reviewCap`/`tracingSessionSize` per tier; default `.regular.tracingSessionSize == 8` (parity).
- **Mastery aggregation**: tier boundaries (new/started/familiar/proficient/mastered) on representative FSRS states.
- **Interleave**: `characters(in:)` maps a known lesson's words to the right `FidelCharacter` ids; `completeLesson` credits them into `fidelCharactersRecognized`.
- **Streak slack**: miss-a-day-with-freeze preserves streak & consumes a freeze; miss-without keeps `weeklyStreakCount`.
- **Tracing VM**: session size follows tier; `advanceAfterCelebration()` advances index and triggers completion on the last item.
- Build + full suite green on iOS Simulator (iPhone 17 Pro) via **XcodeBuildMCP** (per `CLAUDE.md`); manual smoke of the open Journey loop and auto-advance.

## Edge cases / error handling

- Empty due queue + all lessons started → "All caught up" hero (free practice / next new). Brand-new user → recommend Unit 1 · Lesson 1.
- Missing stroke data for a character → skip gracefully (existing behavior).
- Reduce Motion / VoiceOver → gentler/manual tracing advance (§7).
- Huge FSRS backlog → reviews capped by tier so a session never overwhelms.
- Tier changed mid-session → next recommendation recomputes on return (existing `.onChange` refresh handlers).

## Out of scope (this pass)

- Onboarding placement/adaptive test; weekly leagues; Birdbrain-style adaptive difficulty; a dedicated Practice Hub.
- Any energy/hearts/lives system (excluded on principle per research).
- New curriculum content authoring beyond deriving the character map from existing words.
