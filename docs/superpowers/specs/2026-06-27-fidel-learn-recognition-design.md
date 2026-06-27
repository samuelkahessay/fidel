# Learn-tab clarity + adaptive Fidel recognition — design

Date: 2026-06-27
Status: Approved (design), hardened against adversarial review

## Problem

Two pieces of user feedback on the Fidel iOS app:

1. **Learn tab:** "It's not obvious what you have to do to unlock the next items." The tab shows a stage path, a stage header, and a "Next stage" criteria card, but nothing connects *the activity you tap* to *the requirement that gates the next stage*, and activity cards show no progress (`isCompleted` is hardcoded `false` for the Script & Sounds stage).
2. **Recognizing Fidel:** "Why is it only one at a time — you should be able to do a lot more at once with a dynamic list to practice that changes based on what you've done and haven't." Recognition is currently a *side-effect of tracing one character at a time* (`UserProgress.traceCharacter` also marks it recognized). The only prominent path is the Fidel grid → tap a character → trace it.

## Key existing facts (verified)

- Recognition is written **only** via `UserProgress.traceCharacter(_:)` (`Models/Models.swift:191`), which adds to both `charactersTraced` and `fidelCharactersRecognized`. Tapping a grid cell, the Character Quiz, and the (mislabeled) "Fidel Flashcards" do **not** mark recognition.
- An **adaptive multi-character session already exists**: `TraceSessionPlan.standard` (`ViewModels/TracingSessionViewModel.swift:30`) composes due-for-promotion characters (spaced-repetition) interleaved with new characters in curriculum order, ~8 per session. `TracingSessionView()` defaults to `.standard`. It is already wired to the stage-0 "Character Tracing" activity — just buried as the 4th card.
- Stage gating: `StageManager.criteriaForNextStage()` returns `LearningStage.criteria(for: nextStage)`. Stage 0 (`scriptAndSounds`) has **no** criteria; the `fidel_50` criterion ("Recognize 50+ Fidel characters") belongs to the **next** stage (`survivalPhrases`). `checkAndAdvanceStage()` runs on `JourneyView.onAppear` only.
- `StageCriterion` (`Models/LearningStage.swift:165`) stores `evaluate` and `progressFraction` closures, consumed by `StageManager`, `JourneyView.nextStageCriteria`, and `LockedStageSheet`.

## User decisions (brainstorming)

1. Recognition stays **tied to tracing**; surface the existing adaptive session as the prominent flow (not a new recall-only drill).
2. Surface it as a **one-tap "Practice Fidel" CTA** (adaptivity stays invisible — it just serves the right characters). No visible 238-char coverage map, no batch selection.
3. Learn-tab clarity = **a clear next-action hero + per-activity progress**.
4. Approved folding in the mislabeled-flashcards cleanup and reframing the grid as a secondary "Browse the chart" lookup.

## Design

### Constants

Add a single source of truth for the recognition target so the criterion and the activity card can never drift:

```swift
extension LearningStage {
    static let fidelRecognitionTarget = 50
}
```
Used by both the `fidel_50` criterion `target` and the stage-0 "Practice Fidel" activity progress.

### 1. `StageCriterion` refactor (`Models/LearningStage.swift`)

Replace the stored `progressFraction` closure with explicit `current`/`target` and keep `evaluate` authoritative and independent:

```swift
struct StageCriterion: Identifiable {
    let id: String
    let description: String
    let icon: String
    let evaluate: (UserProgress) -> Bool      // unchanged authority for gating
    let current: (UserProgress) -> Int
    let target: Int

    func progressFraction(_ p: UserProgress) -> Double {
        guard target > 0 else { return evaluate(p) ? 1 : 0 }
        return min(Double(current(p)) / Double(target), 1)
    }
    func remaining(_ p: UserProgress) -> Int { max(target - current(p), 0) }
}
```

- `progressFraction(_:)` becomes a **method** with the same call-site syntax (`criterion.progressFraction(progress)`), so `StageManager`, `nextStageCriteria`, and `LockedStageSheet` compile unchanged.
- Update all six criteria to supply `current` + `target`. Keep `evaluate` explicit (e.g. `all_lessons` keeps the `isSuperset` check; do **not** silently redefine evaluate as `current >= target`).
- `fidel_50.target = LearningStage.fidelRecognitionTarget`.

**Regression guard:** for every criterion across all stages, `evaluate(p) == (current(p) >= target)` on representative progress; `progressToNextStage()` / `checkAndAdvanceStage()` make identical advance decisions as before.

### 2. Adaptive "Practice Fidel" as the stage-0 primary (`ViewModels/JourneyViewModel.swift`)

Reorder/replace the Script & Sounds activities to:

1. **Practice Fidel** — `type: .practiceMode(.tracing)`, subtitle "Trace characters to learn them — adapts to what you know", icon `scribble.variable`, color `practiceColor`. Carries progress `(current: recognized, target: fidelRecognitionTarget, unit: "recognized")`.
2. **Browse the chart** — `type: .fidel`, subtitle "Look up any letter, sound, and vowel form", icon `character.book.closed`, color `infoColor`. (Lookup only; does not mark recognition.)
3. **Character Quiz** — `type: .practiceMode(.quiz)`, subtitle "Test your Fidel knowledge".

Removed: the mislabeled "Fidel Flashcards" (launched *vocabulary* flashcards) and the redundant standalone "Character Tracing" (now the primary). Net: `activities.first` is **Practice Fidel**, so `selectCurrentStagePrimaryActivity()` and a stage-tile tap launch the adaptive tracing session (sets `selectedPracticeMode = .tracing`).

### 3. Per-activity progress

Add to `JourneyActivity`:

```swift
struct ActivityProgress { let current: Int; let target: Int; let unit: String
    var fraction: Double { target > 0 ? min(Double(current)/Double(target), 1) : 0 }
    var isComplete: Bool { current >= target }
}
// JourneyActivity gains: var progress: ActivityProgress? = nil
```

Populated only where measurable (stage-0 Practice Fidel → recognized/50). `ActivityCard` renders, after the subtitle, a `FidelProgressBar(value: progress.fraction, color: activity.color, height: 5)` plus a `caption2` label "`current`/`target` `unit`" — or a "Complete" treatment when `isComplete`. Lessons/conversations keep the existing `isCompleted` checkmark; other practice modes show no bar.

### 4. Next-action hero (`JourneyViewModel` + `JourneyView`)

`JourneyViewModel` exposes a computed `nextActionHero`:

```swift
struct NextActionHero {
    let eyebrow: String          // "Up next" / "Almost there" / "Keep practicing"
    let title: String            // "Recognize 38 more characters"
    let detail: String           // "to unlock Survival Phrases"
    let progress: Double         // 0...1 toward the gating criterion
    let ctaLabel: String         // "Practice Fidel"
    let ctaIcon: String
    let action: HeroAction
    let style: HeroStyle         // .action | .ready | .freePractice
}
enum HeroAction { case practiceTracing, lesson(Int), flashcards, conversation(Int), browseChart }
```

Logic:
- **Fluency / no next stage** (`criteriaForNextStage() == nil`): `.freePractice` hero — "You've unlocked everything", CTA → a real fluency activity (flashcards), **no** fidel target, no force-unwrap.
- **All next-stage criteria met but not yet advanced** (`remaining <= 0` / none unmet): `.ready` hero — "Stage complete!", and the view triggers `checkAdvancement()` (this state is transient given the refresh-on-return fix below). Never render "Recognize 0 more characters".
- **Otherwise:** pick the **first unmet** criterion. Title/CTA derive from the criterion id via **prefix-tolerant** matching with an explicit default:
  - `fidel*` → "Recognize N more character(s)" → `.practiceTracing`, "Practice Fidel", `scribble.variable`
  - `lessons*`/`all_lessons` → "Complete N more lesson(s)" → `.lesson(nextIncompleteId)`, "Continue lesson", `book.fill`
  - `vocab*` → "Master N more word(s)" → `.flashcards`, "Practice words", `rectangle.stack.fill`
  - `conversations*` → "Practice N more conversation(s)" → `.conversation(firstUnpracticedId)`, "Practice a conversation", `bubble.left.and.bubble.right`
  - **default** (unknown id) → criterion `description` + CTA → open current stage's primary activity ("Continue"). No nil/dead button.

`performHeroAction()` maps `HeroAction` to the existing navigation (e.g. `.practiceTracing` → `selectedPracticeMode = .tracing`; `.browseChart` → `showFidelChart = true`).

Placement in `JourneyView.body`: `FidelScreenHeader → hero → stageScroller → stageHeader → nextStageCriteria → activities → lockedStages`. The hero is a `fidelDesignCard` (terracotta-tinted for `.action`) with the CTA as a plain `Button(...).primaryGlassButton(fullWidth: true)` (no nested `LearningCardButton`). **Show `nextStageCriteria` only when the next stage has more than one criterion** (otherwise the hero already conveys the single requirement — removes redundancy).

### 5. Refresh-on-return (correctness-critical) (`JourneyView`)

`refresh()` + `checkAdvancement()` currently run only on root `.onAppear`, which does **not** re-fire when a pushed `navigationDestination` (tracing/lesson/quiz) pops. Add `.onChange` handlers so returning from any activity re-evaluates:

```swift
.onChange(of: viewModel.selectedPracticeMode) { _, v in if v == nil { refreshAfterReturn() } }
.onChange(of: viewModel.selectedLesson)       { _, v in if v == nil { refreshAfterReturn() } }
.onChange(of: viewModel.selectedConversation) { _, v in if v == nil { refreshAfterReturn() } }
.onChange(of: viewModel.showFidelChart)       { _, v in if v == false { refreshAfterReturn() } }
```
where `refreshAfterReturn()` calls `viewModel.refresh()` then `viewModel.checkAdvancement()`. This makes the hero, per-card progress, stage ring, and stage advancement all update the moment the user returns from a session — the core loop this feature targets. (`Lesson`/`Conversation`/`PracticeMode` are `Hashable`, so `.onChange` is valid.)

### 6. Today-tab consistency (`ContentView.swift`)

Stage-0 "Continue" currently routes to `.fidelGrid` (browsing — which cannot mark recognition). Change `TodayView.nextRoute` so stage-0 routes to `.practice(.tracing)` (already maps to `TracingSessionView` via `PracticeModeDestination`), and update `nextActionTitle`/`nextActionSubtitle`/`nextActionIcon` to match ("Practice your Fidel" / "Trace characters to recognize them — this unlocks the next stage" / `scribble.variable`). Rename the "Fidel grid" quick-action subtitle to "Browse letters" for consistency with the demotion.

### 7. Accessibility

- Hero: the descriptive line is a `Text` (wraps via `.fixedSize(horizontal: false, vertical: true)` — the "Recognize N more… to unlock …" line is long); the CTA `Button` is its own element with an `accessibilityHint`. Do not let a parent `.combine` swallow the button.
- Per-activity progress: append "`current` of `target` `unit`" to the `LearningCardButton` `accessibilityLabel` and set `accessibilityValue` so VoiceOver announces "12 of 50 recognized".

## Reachability / UX note

A `.standard` session serves ≤8 characters and only **new** characters (level 0→1 at score ≥70) increment recognition; due-review-heavy sessions may not move the counter. Reaching 50 takes ~7–10 sessions. The refresh-on-return fix plus the hero's "Recognize N more…" copy keep the user oriented; copy must not imply one session == unlock. The tracing completion screen already offers a restart.

## Files touched

- `Models/LearningStage.swift` — `StageCriterion` (`current`/`target`/`remaining`, method `progressFraction`); update 6 criteria; `fidelRecognitionTarget`.
- `ViewModels/JourneyViewModel.swift` — `ActivityProgress`, `JourneyActivity.progress`, `NextActionHero`/`HeroAction`, `nextActionHero` computed property, `performHeroAction()`, stage-0 activity reorder/cleanup with progress.
- `Views/JourneyView.swift` — hero section, per-activity progress in `ActivityCard`, refresh-on-return `.onChange`, conditional `nextStageCriteria`, accessibility.
- `ContentView.swift` — Today stage-0 route + copy; quick-action subtitle.
- `FidelTests/` — new `LearnHeroTests.swift`; update `LocalFirstTests.testCurrentScriptAndSoundsStageSelectsFidelGrid` (primary is now tracing, not the grid).

## Testing

Unit (XCTest, in-memory `ModelContainer` fixture per existing convention):
- `StageCriterion`: `evaluate == (current >= target)`, `remaining`, `progressFraction` for all criteria.
- `nextActionHero`: fresh user (stage 0 → "Recognize 50 more", `.practiceTracing`); partial (30 → remaining 20); all-met-not-advanced → `.ready`; fluency → `.freePractice`, no crash; **every** criterion id across all stages maps to a non-nil action.
- Stage-0 activities: `activities.first` is Practice Fidel; `selectCurrentStagePrimaryActivity()` sets `selectedPracticeMode == .tracing`; Practice Fidel `progress` reflects recognized count and completes at ≥50.
- Update the existing stage test to assert `.tracing` rather than `showFidelChart`.

Build + run on iOS Simulator (iPhone 17 Pro); full test suite green; manual smoke of the Learn tab loop.

## Post-review refinements (adversarial review, 2026-06-27)

A multi-lens adversarial review (correctness / SwiftUI / requirements / accessibility, each finding independently verified) confirmed 9 issues, all addressed:

- **High — vocab CTA dead-end:** the vocab hero CTA routed to Flashcards, which only reschedules FSRS reviews and never increments `vocabularyMastered`. Added a `matchPairs` `HeroAction`; the vocab CTA now routes to Match Pairs (the mode whose `MatchPairsViewModel.masterVocabulary` actually advances the gate).
- **High — tracing completion dead-end:** the adaptive session had no continuation at completion, forcing a back-out/re-enter per 8-char batch. Added "Keep practicing" (restarts the `.standard` batch from live mastery; hidden for `.single`) and "Done" (dismiss) to `TracingSessionView.completionView`.
- **High — hero text contrast:** secondary hero text at 0.85 opacity on terracotta failed WCAG AA. Now full-opacity `onAccentColor`, and the primary hero uses `terracottaDeepColor` (verified legible in dark mode).
- **Medium — activity progress text contrast:** "N/50 recognized" used `activity.color` (3.31:1 in dark). Now `inkSecondaryColor`; the accent stays on the bar.
- **Low — competing progress indicators:** the hero progress bar now renders only when the next stage has a single criterion (`showsProgressBar`); with multiple criteria the stage ring + "Next stage" checklist carry progress.
- **Low — Today/Learn parity:** the Today stage-0 subtitle now includes "N of 50 recognized".
- **Low — a11y hint:** the hero CTA hint is action-oriented ("Starts this activity") instead of restating the title/detail.
- **Low — dead branch clarity:** documented the `.ready` hero's unused `action`.

Three further raised items were verified and refuted as style/parity nits (a11y percent parity on the decorative hidden bar; render-time fetch that pre-existed in `nextStageCriteria`; per-render repository allocation).

## Out of scope

- A recall-only "recognition ≠ writing" drill (recognition stays tied to tracing).
- Visible 238-character coverage map / batch character selection.
- A Practice Fidel card in stages beyond Script & Sounds.
