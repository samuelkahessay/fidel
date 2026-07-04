# Open Learning Path Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Fidel's 4-stage hard gate (50-character wall + fixed 8-char sessions) with an always-open, recommendation-driven learning path that has configurable pace, interleaved script, mastery-as-display, and auto-advancing tracing.

**Architecture:** Build additive service layers first (`DailyGoalTier`, `CurriculumService`, `NextStepPlanner`) that the existing FSRS scheduler and SwiftData models feed. Then rewire `JourneyViewModel`/`JourneyView` from stage-gating to the open path, then delete the now-dead gate. Tracing, settings, streak-slack, and backup round-trip follow. Every task leaves the app compiling and the test suite green.

**Tech Stack:** Swift 5.9+, SwiftUI, SwiftData, XCTest, iOS 17+. Existing FSRS scheduler (`Services/SpacedRepetition.swift`). Build/test via **XcodeBuildMCP** only.

## Global Constraints

- Build & test **only** via XcodeBuildMCP (never raw `xcodebuild`). Scheme `Fidel`, project `Fidel.xcodeproj`, simulator **iPhone 17 Pro**, `useLatestOS: true`, `suppressWarnings: true`. Call `session_show_defaults` before the first build/test.
- Design spec: `docs/superpowers/specs/2026-07-04-open-learning-path-design.md` (read before starting).
- Tests use in-memory `ModelContainer` fixtures (existing `FidelTests` convention).
- **Test target import:** every test file imports the app module as `@testable import Fidel___Learn_Amharic` (the product name "Fidel - Learn Amharic" sanitizes to this — it is NOT `Fidel`). The `@testable import Fidel` shown in task test snippets below is shorthand; use `Fidel___Learn_Amharic`.
- New Swift files must be registered in the Xcode project (objectVersion 56, manual refs) via `python3 tools/add_swift_file.py <repo-relative-path>` — never hand-edit `project.pbxproj`.
- **No energy/hearts/lives** mechanic. Gating removal must never re-introduce a content wall.
- Default pace tier is `.regular`, and `.regular.tracingSessionSize == 8` and its promotion count `== 3` — this preserves today's exact tracing behavior for existing users.
- Ethiopic color palette + Theme components only; reuse `AccessibleProgressRing`, `FidelProgressBar`, `GlassChip`. No new design system.
- Conventional Commits; end every commit body with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`. Work on branch `feat/open-learning-path`.
- Respect Reduce Motion and VoiceOver for any auto-advancing UI.

---

## File Structure

**New files**
- `Fidel/Models/DailyGoalTier.swift` — pace tiers (session sizes, caps, labels).
- `Fidel/Services/CurriculumService.swift` — glyph→character index, character-in-lesson derivation, lesson mastery computation, open-path sectioning.
- `Fidel/Services/NextStepPlanner.swift` — the "recommended next" engine.
- `FidelTests/DailyGoalTierTests.swift`, `CurriculumServiceTests.swift`, `NextStepPlannerTests.swift`, `LessonCreditTests.swift`, `StreakSlackTests.swift`, `TracingSessionSizeTests.swift`.

**Modified files**
- `Fidel/Services/AppSettingsStore.swift` — `dailyGoalTier`.
- `Fidel/Repositories/ProgressRepository.swift` — credit characters on `completeLesson`.
- `Fidel/ViewModels/JourneyViewModel.swift` — open path + recommendation; drop gating props.
- `Fidel/Views/JourneyView.swift` — open-path UI; remove locked/criteria views.
- `Fidel/Models/LearningStage.swift` — delete gate; keep enum as section labels.
- `Fidel/Services/StageManager.swift` — return all content; drop gating methods.
- `Fidel/ViewModels/TracingSessionViewModel.swift` — tier-driven size.
- `Fidel/Views/TracingSessionView.swift` — auto-advance.
- `Fidel/Views/ProgressView.swift` — tier picker; `currentStage` display-only.
- `Fidel/ContentView.swift` — Today routing/copy; `currentStage` display-only.
- `Fidel/Models/Models.swift` — streak-slack fields + `checkStreak` slack.
- `Fidel/Services/ProgressExportService.swift` — round-trip tier + streak fields.

---

## Task 1: `DailyGoalTier` pace tiers + settings

**Files:**
- Create: `Fidel/Models/DailyGoalTier.swift`
- Modify: `Fidel/Services/AppSettingsStore.swift` (add key + property + default registration)
- Test: `FidelTests/DailyGoalTierTests.swift`

**Interfaces:**
- Produces: `enum DailyGoalTier: String, CaseIterable, Codable, Identifiable` with `newCap: Int`, `reviewCap: Int`, `tracingSessionSize: Int`, `estimatedMinutes: Int`, `suggestedDailyXP: Int`, `displayName: String`, `subtitle: String`, `static let `default`: DailyGoalTier = .regular`; `AppSettingsStore.dailyGoalTier: DailyGoalTier { get set }`.

- [ ] **Step 1: Write the failing test**

```swift
// FidelTests/DailyGoalTierTests.swift
import XCTest
@testable import Fidel

final class DailyGoalTierTests: XCTestCase {
    func testRegularPreservesLegacyTracingDefault() {
        // The redesign must not change existing users' tracing session size.
        XCTAssertEqual(DailyGoalTier.default, .regular)
        XCTAssertEqual(DailyGoalTier.regular.tracingSessionSize, 8)
    }

    func testCapsIncreaseMonotonicallyWithTier() {
        let order: [DailyGoalTier] = [.casual, .regular, .serious, .intense]
        XCTAssertEqual(order.map(\.newCap), [3, 5, 8, 12])
        XCTAssertEqual(order.map(\.reviewCap), [10, 15, 20, 30])
        XCTAssertEqual(order.map(\.tracingSessionSize), [5, 8, 12, 16])
        XCTAssertEqual(order.map(\.suggestedDailyXP), [10, 20, 30, 50])
    }

    func testAllCasesHaveNonEmptyLabels() {
        for tier in DailyGoalTier.allCases {
            XCTAssertFalse(tier.displayName.isEmpty)
            XCTAssertFalse(tier.subtitle.isEmpty)
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Use XcodeBuildMCP `test_sim` (scheme `Fidel`, iPhone 17 Pro). Expected: FAIL — `DailyGoalTier` undefined.

- [ ] **Step 3: Write the implementation**

```swift
// Fidel/Models/DailyGoalTier.swift
import Foundation

/// The learner-chosen pace. Single control that sizes both the daily
/// recommendation (NextStepPlanner) and the tracing session. Replaces the
/// hardcoded 8-char session; `.regular` preserves the legacy default exactly.
enum DailyGoalTier: String, CaseIterable, Codable, Identifiable {
    case casual, regular, serious, intense

    var id: String { rawValue }

    static let `default`: DailyGoalTier = .regular

    /// Max new items introduced in one recommended session.
    var newCap: Int {
        switch self { case .casual: 3; case .regular: 5; case .serious: 8; case .intense: 12 }
    }
    /// Max spaced-repetition reviews surfaced in one session (prevents backlog overwhelm).
    var reviewCap: Int {
        switch self { case .casual: 10; case .regular: 15; case .serious: 20; case .intense: 30 }
    }
    /// Number of characters in a "Practice Fidel" tracing session.
    var tracingSessionSize: Int {
        switch self { case .casual: 5; case .regular: 8; case .serious: 12; case .intense: 16 }
    }
    var estimatedMinutes: Int {
        switch self { case .casual: 2; case .regular: 5; case .serious: 10; case .intense: 15 }
    }
    /// Suggested daily-XP-ring target when the learner first picks this tier.
    var suggestedDailyXP: Int {
        switch self { case .casual: 10; case .regular: 20; case .serious: 30; case .intense: 50 }
    }
    var displayName: String {
        switch self { case .casual: "Casual"; case .regular: "Regular"; case .serious: "Serious"; case .intense: "Intense" }
    }
    var subtitle: String { "~\(estimatedMinutes) min · \(newCap) new" }
}
```

Then in `Fidel/Services/AppSettingsStore.swift`: add `static let dailyGoalTier = "fidel.settings.dailyGoalTier"` to `SettingsKeys`; add the property; register the default.

```swift
// Add inside AppSettingsStore
var dailyGoalTier: DailyGoalTier {
    get {
        guard let raw = defaults.string(forKey: SettingsKeys.dailyGoalTier),
              let tier = DailyGoalTier(rawValue: raw) else { return .default }
        return tier
    }
    nonmutating set { defaults.set(newValue.rawValue, forKey: SettingsKeys.dailyGoalTier) }
}
// In registerDefaults(): SettingsKeys.dailyGoalTier: DailyGoalTier.default.rawValue
```

- [ ] **Step 4: Run tests to verify they pass** (`test_sim`). Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Fidel/Models/DailyGoalTier.swift Fidel/Services/AppSettingsStore.swift FidelTests/DailyGoalTierTests.swift
git commit -m "feat(pace): add DailyGoalTier and settings store

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: `CurriculumService` — interleave map (characters in a lesson)

**Files:**
- Create: `Fidel/Services/CurriculumService.swift`
- Test: `FidelTests/CurriculumServiceTests.swift`

**Interfaces:**
- Consumes: `LessonRepository.shared.getFidelChart()`, `Lesson`, `FidelCharacter` (`FidelCharacter.character` is the glyph, `.id` is `"row-vowel"`).
- Produces: `struct CurriculumService { static let shared: CurriculumService; func characterIds(in lesson: Lesson) -> [String]; func characters(in lesson: Lesson) -> [FidelCharacter] }`.

- [ ] **Step 1: Write the failing test**

```swift
// FidelTests/CurriculumServiceTests.swift
import XCTest
@testable import Fidel

final class CurriculumServiceTests: XCTestCase {
    func testCharactersDerivedFromLessonWordsExistInChart() {
        let lessons = LessonRepository.shared.getLessons()
        let lesson = try! XCTUnwrap(lessons.first { $0.id == 1 })
        let ids = CurriculumService.shared.characterIds(in: lesson)
        XCTAssertFalse(ids.isEmpty, "Lesson 1 words should contain Fidel characters")
        // Every derived id must be a real chart character id ("row-vowel").
        let chartIds = Set(LessonRepository.shared.getFidelChart().flatMap { $0 }.map(\.id))
        for id in ids { XCTAssertTrue(chartIds.contains(id), "\(id) not in chart") }
    }

    func testDerivationIsDeduplicatedAndStable() {
        let lesson = try! XCTUnwrap(LessonRepository.shared.getLessons().first { $0.id == 1 })
        let ids = CurriculumService.shared.characterIds(in: lesson)
        XCTAssertEqual(ids.count, Set(ids).count, "ids should be unique")
    }
}
```

- [ ] **Step 2: Run test to verify it fails** (`test_sim`). Expected: FAIL — `CurriculumService` undefined.

- [ ] **Step 3: Write the implementation**

```swift
// Fidel/Services/CurriculumService.swift
import Foundation

/// Derives which Fidel characters a lesson "owns" from the characters that
/// actually appear in its vocabulary and phrases — the interleave map is
/// self-maintaining (add a word, its characters are covered automatically).
struct CurriculumService {
    static let shared = CurriculumService()
    private let lessonRepository: LessonRepositoryProtocol
    init(lessonRepository: LessonRepositoryProtocol = LessonRepository.shared) {
        self.lessonRepository = lessonRepository
    }

    /// Glyph string -> FidelCharacter, built once from the chart.
    private func glyphIndex() -> [String: FidelCharacter] {
        var index: [String: FidelCharacter] = [:]
        for row in lessonRepository.getFidelChart() {
            for char in row { index[char.character] = char }
        }
        return index
    }

    func characters(in lesson: Lesson) -> [FidelCharacter] {
        let index = glyphIndex()
        var seen = Set<String>()
        var result: [FidelCharacter] = []
        let strings = lesson.vocabulary.map(\.amharic) + lesson.phrases.map(\.amharic)
        for string in strings {
            for scalarChar in string.map(String.init) {
                if let fidel = index[scalarChar], seen.insert(fidel.id).inserted {
                    result.append(fidel)
                }
            }
        }
        return result
    }

    func characterIds(in lesson: Lesson) -> [String] { characters(in: lesson).map(\.id) }
}
```

Note for implementer: Amharic combining/punctuation glyphs may not be in the chart — the `index[...]` lookup silently skips non-chart scalars, which is intended. Iterate by Swift `Character` (grapheme) via `string.map(String.init)`.

- [ ] **Step 4: Run tests to verify they pass** (`test_sim`). Expected: PASS. If Lesson 1's words produce zero chart hits, inspect `getFidelChart()` glyph forms vs. word glyphs and adjust the lookup granularity (grapheme vs. unicodeScalar) — do not weaken the assertions.

- [ ] **Step 5: Commit**

```bash
git add Fidel/Services/CurriculumService.swift FidelTests/CurriculumServiceTests.swift
git commit -m "feat(curriculum): derive lesson->Fidel character map from lesson words

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: Credit interleaved characters on lesson completion

**Files:**
- Modify: `Fidel/Repositories/ProgressRepository.swift:111` (`completeLesson(_:)`)
- Test: `FidelTests/LessonCreditTests.swift`

**Interfaces:**
- Consumes: `CurriculumService.shared.characterIds(in:)`, `UserProgress.recognizeFidelCharacter(_:)`, `LessonRepository.shared`.
- Produces: after `completeLesson(id)`, `UserProgress.fidelCharactersRecognized` is a superset of that lesson's derived character ids.

- [ ] **Step 1: Write the failing test**

```swift
// FidelTests/LessonCreditTests.swift
import XCTest
import SwiftData
@testable import Fidel

@MainActor
final class LessonCreditTests: XCTestCase {
    private func makeRepo() throws -> ProgressRepository {
        let container = try ModelContainer(
            for: UserProgress.self, FlashcardProgress.self, CharacterTraceMastery.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ProgressRepository(modelContext: container.mainContext)
    }

    func testCompletingLessonCreditsItsCharacters() throws {
        let repo = try makeRepo()
        let lesson = try XCTUnwrap(LessonRepository.shared.getLessons().first { $0.id == 1 })
        let expected = Set(CurriculumService.shared.characterIds(in: lesson))
        XCTAssertFalse(expected.isEmpty)

        repo.completeLesson(1)

        let recognized = Set(repo.getUserProgress()?.fidelCharactersRecognized ?? [])
        XCTAssertTrue(recognized.isSuperset(of: expected))
    }
}
```

(Match the exact `ModelContainer` model list to the existing `FidelTests` fixture convention; adjust the model list if the suite has a shared helper.)

- [ ] **Step 2: Run test to verify it fails** (`test_sim`). Expected: FAIL — characters not credited.

- [ ] **Step 3: Write the implementation**

In `ProgressRepository.completeLesson(_:)`, after the existing `progress.completeLesson(lessonId)` and before/at the save, add crediting:

```swift
func completeLesson(_ lessonId: Int) {
    let progress = ensureUserProgress()
    progress.completeLesson(lessonId)
    if let lesson = LessonRepository.shared.getLessons().first(where: { $0.id == lessonId }) {
        for charId in CurriculumService.shared.characterIds(in: lesson) {
            progress.recognizeFidelCharacter(charId)   // no-op if already recognized
        }
    }
    save()   // use whatever persistence call the existing method uses
}
```

Preserve the method's existing structure (XP, save mechanism); only add the crediting loop.

- [ ] **Step 4: Run tests to verify they pass** (`test_sim`). Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Fidel/Repositories/ProgressRepository.swift FidelTests/LessonCreditTests.swift
git commit -m "feat(curriculum): credit a lesson's Fidel characters on completion

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: Lesson mastery computation (display tiers)

**Files:**
- Modify: `Fidel/Services/CurriculumService.swift` (add mastery API)
- Test: `FidelTests/CurriculumServiceTests.swift` (extend)

**Interfaces:**
- Produces: `enum MasteryTier: Int, Comparable, CaseIterable { case new, started, familiar, proficient, mastered }`; `func mastery(for lesson: Lesson, learnedItemIds: Set<String>, recognizedCharIds: Set<String>) -> (tier: MasteryTier, fraction: Double)`.
- Item id conventions: vocabulary `word.id` (`"category-amharic"`), phrase `String(phrase.id)`, character `char.id`.

- [ ] **Step 1: Write the failing test**

```swift
// append to CurriculumServiceTests.swift
func testMasteryTierBoundaries() {
    let lesson = try! XCTUnwrap(LessonRepository.shared.getLessons().first { $0.id == 1 })
    let vocabIds = lesson.vocabulary.map(\.id)
    let phraseIds = lesson.phrases.map { String($0.id) }
    let charIds = CurriculumService.shared.characterIds(in: lesson)
    let allItemIds = vocabIds + phraseIds
    let allCharIds = charIds

    // Nothing learned -> .new, fraction 0
    let none = CurriculumService.shared.mastery(for: lesson, learnedItemIds: [], recognizedCharIds: [])
    XCTAssertEqual(none.tier, .new)
    XCTAssertEqual(none.fraction, 0, accuracy: 0.001)

    // Everything learned -> .mastered, fraction 1
    let all = CurriculumService.shared.mastery(
        for: lesson, learnedItemIds: Set(allItemIds), recognizedCharIds: Set(allCharIds))
    XCTAssertEqual(all.tier, .mastered)
    XCTAssertEqual(all.fraction, 1, accuracy: 0.001)

    // A single learned item -> .started (any progress, below familiar)
    if let first = allItemIds.first {
        let started = CurriculumService.shared.mastery(
            for: lesson, learnedItemIds: [first], recognizedCharIds: [])
        XCTAssertEqual(started.tier, .started)
    }
}
```

- [ ] **Step 2: Run test to verify it fails** (`test_sim`). Expected: FAIL — `mastery(for:...)` undefined.

- [ ] **Step 3: Write the implementation** (append to `CurriculumService`)

```swift
enum MasteryTier: Int, Comparable, CaseIterable {
    case new, started, familiar, proficient, mastered
    static func < (l: MasteryTier, r: MasteryTier) -> Bool { l.rawValue < r.rawValue }
    var label: String {
        switch self { case .new: "New"; case .started: "Started"; case .familiar: "Familiar"
        case .proficient: "Proficient"; case .mastered: "Mastered" }
    }
}

extension CurriculumService {
    /// Fraction of a lesson's items (vocab + phrases + its characters) that are
    /// "learned". Display only — never a gate.
    func mastery(for lesson: Lesson,
                 learnedItemIds: Set<String>,
                 recognizedCharIds: Set<String>) -> (tier: MasteryTier, fraction: Double) {
        let vocabIds = lesson.vocabulary.map(\.id)
        let phraseIds = lesson.phrases.map { String($0.id) }
        let charIds = characterIds(in: lesson)
        let total = vocabIds.count + phraseIds.count + charIds.count
        guard total > 0 else { return (.new, 0) }

        let learnedVocabPhrase = (vocabIds + phraseIds).filter { learnedItemIds.contains($0) }.count
        let learnedChars = charIds.filter { recognizedCharIds.contains($0) }.count
        let fraction = Double(learnedVocabPhrase + learnedChars) / Double(total)

        let tier: MasteryTier
        switch fraction {
        case 1: tier = .mastered
        case 0.8..<1: tier = .proficient
        case 0.5..<0.8: tier = .familiar
        case let f where f > 0: tier = .started
        default: tier = .new
        }
        return (tier, fraction)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass** (`test_sim`). Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Fidel/Services/CurriculumService.swift FidelTests/CurriculumServiceTests.swift
git commit -m "feat(curriculum): compute lesson mastery tiers for display

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 5: `NextStepPlanner` — the recommendation engine

**Files:**
- Create: `Fidel/Services/NextStepPlanner.swift`
- Test: `FidelTests/NextStepPlannerTests.swift`

**Interfaces:**
- Consumes: `DailyGoalTier`, `HeroAction` (existing, `ViewModels/JourneyViewModel.swift:41`), `UserProgress`, `Lesson`.
- Produces: `struct RecommendedSession: Equatable { enum Kind ...; let kind; reviewCount; newCount; estimatedMinutes; heroAction; eyebrow; title; detail }` and `struct NextStepPlanner { func plan(completedLessonIds: Set<Int>, inProgressLessonId: Int?, tier: DailyGoalTier, dueReviewCount: Int, orderedLessonIds: [Int]) -> RecommendedSession }`.

Design note: `plan` takes primitives (not the whole VM state) so it is pure and trivially testable. The ViewModel computes `dueReviewCount`, `completedLessonIds`, `inProgressLessonId`, and `orderedLessonIds` from its repositories and passes them in.

- [ ] **Step 1: Write the failing test**

```swift
// FidelTests/NextStepPlannerTests.swift
import XCTest
@testable import Fidel

final class NextStepPlannerTests: XCTestCase {
    let planner = NextStepPlanner()
    let order = [1, 2, 3, 4, 5]

    func testFreshUserGetsFirstNewLesson() {
        let s = planner.plan(completedLessonIds: [], inProgressLessonId: nil,
                             tier: .regular, dueReviewCount: 0, orderedLessonIds: order)
        XCTAssertEqual(s.kind, .newLesson(1))
        XCTAssertEqual(s.heroAction, .lesson(1))
    }

    func testDueReviewsTakePriorityAndAreCapped() {
        let s = planner.plan(completedLessonIds: [1], inProgressLessonId: nil,
                             tier: .regular, dueReviewCount: 100, orderedLessonIds: order)
        XCTAssertEqual(s.kind, .reviews)
        XCTAssertEqual(s.reviewCount, DailyGoalTier.regular.reviewCap) // 15
        XCTAssertEqual(s.heroAction, .flashcards)
    }

    func testResumeInProgressLessonWhenNoReviews() {
        let s = planner.plan(completedLessonIds: [1], inProgressLessonId: 2,
                             tier: .regular, dueReviewCount: 0, orderedLessonIds: order)
        XCTAssertEqual(s.kind, .resumeLesson(2))
        XCTAssertEqual(s.heroAction, .lesson(2))
    }

    func testAllCaughtUpWhenEverythingDoneAndNothingDue() {
        let s = planner.plan(completedLessonIds: Set(order), inProgressLessonId: nil,
                             tier: .regular, dueReviewCount: 0, orderedLessonIds: order)
        XCTAssertEqual(s.kind, .allCaughtUp)
    }
}
```

- [ ] **Step 2: Run test to verify it fails** (`test_sim`). Expected: FAIL — types undefined.

- [ ] **Step 3: Write the implementation**

```swift
// Fidel/Services/NextStepPlanner.swift
import Foundation

struct RecommendedSession: Equatable {
    enum Kind: Equatable { case newLesson(Int), resumeLesson(Int), reviews, allCaughtUp }
    let kind: Kind
    let reviewCount: Int
    let newCount: Int
    let estimatedMinutes: Int
    let heroAction: HeroAction
    let eyebrow: String
    let title: String
    let detail: String
}

/// Chooses the single best "do this now" session over the OPEN path.
/// Priority: due reviews (capped) -> resume in-progress lesson -> next new
/// lesson -> all caught up. This recommender is what makes a fully-open path
/// usable for beginners without re-introducing locks.
struct NextStepPlanner {
    func plan(completedLessonIds: Set<Int>,
              inProgressLessonId: Int?,
              tier: DailyGoalTier,
              dueReviewCount: Int,
              orderedLessonIds: [Int]) -> RecommendedSession {
        let reviews = min(dueReviewCount, tier.reviewCap)
        let nextNewId = orderedLessonIds.first { !completedLessonIds.contains($0) }

        if reviews > 0 {
            let hasNew = nextNewId != nil
            return RecommendedSession(
                kind: .reviews, reviewCount: reviews,
                newCount: hasNew ? tier.newCap : 0,
                estimatedMinutes: tier.estimatedMinutes,
                heroAction: .flashcards,
                eyebrow: "Recommended today",
                title: "Review \(reviews) word\(reviews == 1 ? "" : "s")",
                detail: hasNew ? "then start something new" : "keep your memory fresh")
        }
        if let resumeId = inProgressLessonId, !completedLessonIds.contains(resumeId) {
            return RecommendedSession(
                kind: .resumeLesson(resumeId), reviewCount: 0, newCount: tier.newCap,
                estimatedMinutes: tier.estimatedMinutes, heroAction: .lesson(resumeId),
                eyebrow: "Pick up where you left off", title: "Continue your lesson",
                detail: "~\(tier.estimatedMinutes) min")
        }
        if let newId = nextNewId {
            return RecommendedSession(
                kind: .newLesson(newId), reviewCount: 0, newCount: tier.newCap,
                estimatedMinutes: tier.estimatedMinutes, heroAction: .lesson(newId),
                eyebrow: "Recommended today", title: "Start a new lesson",
                detail: "~\(tier.estimatedMinutes) min · \(tier.newCap) new")
        }
        return RecommendedSession(
            kind: .allCaughtUp, reviewCount: 0, newCount: 0,
            estimatedMinutes: tier.estimatedMinutes, heroAction: .flashcards,
            eyebrow: "You're all caught up", title: "Free practice",
            detail: "Review anything you like")
    }
}
```

- [ ] **Step 4: Run tests to verify they pass** (`test_sim`). Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Fidel/Services/NextStepPlanner.swift FidelTests/NextStepPlannerTests.swift
git commit -m "feat(path): add NextStepPlanner recommendation engine

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 6: Rewire `JourneyViewModel` to the open path

**Files:**
- Modify: `Fidel/ViewModels/JourneyViewModel.swift`
- Test: `FidelTests/` (add `JourneyViewModelOpenPathTests.swift`; update existing Journey tests to remove gating expectations)

**Interfaces:**
- Consumes: `NextStepPlanner`, `CurriculumService`, `DailyGoalTier` (via `AppSettingsStore`), `FlashcardManager.getDueItems()`, existing `HeroAction`/`NextActionHero`/`JourneyActivity`.
- Produces: `var recommendedSession: RecommendedSession?`; `var pathSections: [JourneyPathSection]` where `struct JourneyPathSection: Identifiable { let id; let title: String; let amharicTitle: String; let items: [JourneyLessonItem] }` and `struct JourneyLessonItem: Identifiable { let id; let lesson: Lesson; let masteryTier: MasteryTier; let masteryFraction: Double; let isCompleted: Bool }`. Everything is always selectable.

**Bridge for compile-safety:** keep the properties `lockedStages`, `progressToNextStage`, `checkAdvancement()` present but neutral (`lockedStages = []`, `progressToNextStage = 0`, `checkAdvancement()` is a no-op) so `JourneyView` still compiles until Task 7. They are deleted in Task 8.

- [ ] **Step 1: Write the failing test**

```swift
// FidelTests/JourneyViewModelOpenPathTests.swift — key behaviors
// (Use the existing FidelTests ModelContainer helper + configure(...) convention.)
@MainActor func testNothingIsLocked() throws {
    let vm = try makeConfiguredJourneyViewModel(progress: freshProgress())
    XCTAssertTrue(vm.lockedStages.isEmpty)
    XCTAssertFalse(vm.pathSections.isEmpty)
    XCTAssertTrue(vm.pathSections.allSatisfy { !$0.items.isEmpty || $0.title == "Script & Sounds" })
}

@MainActor func testFreshUserRecommendationIsFirstLesson() throws {
    let vm = try makeConfiguredJourneyViewModel(progress: freshProgress())
    XCTAssertEqual(vm.recommendedSession?.heroAction, .lesson(1))
}

@MainActor func testCompletedLessonShowsMastery() throws {
    let progress = freshProgress(); // complete lesson 1 via repo used in fixture
    let vm = try makeConfiguredJourneyViewModel(progress: progress, completedLessons: [1])
    let item = vm.pathSections.flatMap(\.items).first { $0.lesson.id == 1 }
    XCTAssertNotNil(item)
    XCTAssertGreaterThan(item!.masteryTier, .new)
}
```

Implementer: write `makeConfiguredJourneyViewModel` / `freshProgress` helpers mirroring the existing Journey test setup (in-memory container + `StageManager` + `ProgressRepository`).

- [ ] **Step 2: Run test to verify it fails** (`test_sim`). Expected: FAIL — `pathSections`/`recommendedSession` undefined.

- [ ] **Step 3: Write the implementation**

Rework `refresh()` and the activity/hero building:
1. Read `tier = AppSettingsStore().dailyGoalTier`.
2. Compute `dueReviewCount = flashcardManager.getDueItems().count` (add a `FlashcardManager` — construct from the same `modelContext` passed to `configure`; extend `configure(stageManager:progressRepository:)` to also accept `modelContext` or a `FlashcardManager`).
3. Build `orderedLessonIds` from all lessons (no stage filter): `lessonRepository.getLessons().map(\.id).sorted()`.
4. `completedLessonIds = Set(progress.lessonsCompleted)`; `inProgressLessonId = lessons.first { $0.progressPercent > 0 && !completed }?.id`.
5. `recommendedSession = NextStepPlanner().plan(...)`. Map it into the existing `NextActionHero` (reuse `.action` style for actionable kinds, `.freePractice` for `.allCaughtUp`).
6. Build `pathSections`: partition all lessons into the four theme sections (define the partition explicitly — e.g. Script & Sounds: a synthetic "Practice Fidel" entry; Survival: lessons [1,2]; Building: [3,4,5]; Fluency: [6,7,8] — confirm against `LessonRepository.getLessons()` ids). For each lesson compute mastery via `CurriculumService.shared.mastery(for:learnedItemIds:recognizedCharIds:)` where `learnedItemIds` = ids of the user's mastered vocab/phrases (from `progress.vocabularyMastered` plus FSRS items with stability over threshold) and `recognizedCharIds = Set(progress.fidelCharactersRecognized)`.
7. Set the compile bridge: `lockedStages = []`, `progressToNextStage = 0`, and make `checkAdvancement()` a no-op body.
8. Remove reads of `stageManager.criteriaForNextStage()` / `isStageUnlocked` / `checkAndAdvanceStage`; `availableLessons()`/`availableConversations()` now return all (Task 8 makes StageManager return all — until then call `lessonRepository.getLessons()` directly here).

Keep this task focused on the ViewModel; the view is Task 7. Iterate against `test_sim` until the new tests pass and the project still builds (`build_sim`).

- [ ] **Step 4: Run tests + build** (`test_sim`, then `build_sim`). Expected: new tests PASS; project builds (JourneyView still uses bridged props).

- [ ] **Step 5: Commit**

```bash
git add Fidel/ViewModels/JourneyViewModel.swift FidelTests/JourneyViewModelOpenPathTests.swift
git commit -m "feat(path): drive JourneyViewModel from open path + NextStepPlanner

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 7: Open-path UI (`JourneyView`)

**Files:**
- Modify: `Fidel/Views/JourneyView.swift`

**Interfaces:**
- Consumes: `JourneyViewModel.recommendedSession`, `pathSections`, `JourneyLessonItem`, existing `performHeroAction()`/selection bindings, `AccessibleProgressRing`, `FidelProgressBar`.

- [ ] **Step 1: Restructure the body**

Replace the current `body` composition (`FidelScreenHeader → hero → stageScroller → stageHeader → nextStageCriteria → activities → lockedStages`) with: `FidelScreenHeader → recommendedHero → openPath`. Delete `lockedStagesSection` (`:337`), `LockedStageCard` (`:465`), `LockedStageSheet` (`:505`), the `.disabled(...)` gate (`:198`), the `nextStageCriteria` block (`:251–276`), and the `.sheet(item: $viewModel.tappedLockedStage)` (`:63`).

- [ ] **Step 2: Recommended hero**

Bind the hero card to `viewModel.recommendedSession` (fallback to `nextActionHero` if nil). CTA button (`.primaryGlassButton(fullWidth: true)`) calls the existing hero-action path for `recommendedSession.heroAction`. Show `eyebrow` / `title` / `detail`; use full-opacity `onAccentColor` text (WCAG AA — matches the 2026-06-27 review fix).

- [ ] **Step 3: Open path list**

For each `pathSections` element: a section header (`title` + `amharicTitle`), then each `JourneyLessonItem` as a tappable card showing an `AccessibleProgressRing(progress: item.masteryFraction, ...)` and `item.masteryTier.label`. Tapping selects the lesson (`viewModel.selectedLesson = item.lesson` or the existing selection API). No card is ever disabled. In-progress item (fraction > 0 && < 1) gets a subtle accent border; `.new` shows a "Start" affordance.

- [ ] **Step 4: Build & smoke**

`build_run_sim` (iPhone 17 Pro). Verify: Journey shows one recommended CTA + a fully-tappable path; no locks; tapping any lesson opens it; returning updates rings (existing `.onChange` refresh handlers still fire). Take a `screenshot` for the review.

- [ ] **Step 5: Commit**

```bash
git add Fidel/Views/JourneyView.swift
git commit -m "feat(path): open-path Journey UI with mastery rings, no locks

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 8: Delete the dead gate

**Files:**
- Modify: `Fidel/Models/LearningStage.swift`, `Fidel/Services/StageManager.swift`, `Fidel/ViewModels/JourneyViewModel.swift` (remove bridge props), `Fidel/Views/ProgressView.swift:62`, `Fidel/ContentView.swift:465`
- Test: remove/replace gating tests (e.g. any `StageCriterion`/`checkAndAdvanceStage` tests)

- [ ] **Step 1: Strip `LearningStage`**

Delete `fidelRecognitionTarget`, `StageCriterion`, `criteria(for:)`. Keep the enum + `displayName`/`amharicTitle`/`icon`/`color`/`stageDescription` (used as section labels + `currentStage` display). Keep `availableLessonIds`/`availableConversationIds` only if `pathSections` partitioning reuses them; otherwise delete.

- [ ] **Step 2: Simplify `StageManager`**

Remove `checkAndAdvanceStage`, `criteriaForNextStage`, `progressToNextStage`, `isStageUnlocked`, `nextStage`. `available*()` return all content unconditionally (or delete `StageManager` and have the VM use `lessonRepository` directly — pick the smaller diff).

- [ ] **Step 3: Remove ViewModel bridge props**

Delete `lockedStages`, `progressToNextStage`, `checkAdvancement`, `tappedLockedStage`, `showStageAdvancement`, `advancedToStage` and any now-unused `stageManager` plumbing. Fix `ProgressView.swift:62` and `ContentView.swift:465` to read `progress.currentStage` for **display only** (furthest section reached) — no gating semantics.

- [ ] **Step 4: Build + full test suite**

`build_sim` then `test_sim`. Expected: compiles with no references to deleted symbols; suite green. Remove any test asserting old gating (e.g. `testCurrentScriptAndSoundsStageSelectsFidelGrid`, `StageCriterion` tests) — replace intent with the Task 6/7 open-path tests.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor(path): remove 4-stage hard gate now that path is open

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 9: Auto-advance tracing + tier-driven session size

**Files:**
- Modify: `Fidel/Views/TracingSessionView.swift:176-181`, `Fidel/ViewModels/TracingSessionViewModel.swift:64-65,131-149,154-190`
- Test: `FidelTests/TracingSessionSizeTests.swift`

**Interfaces:**
- Consumes: `DailyGoalTier.tracingSessionSize`, `AppSettingsStore`.
- Produces: `TracingSessionViewModel.startSession(plan:)` composes `tier.tracingSessionSize` items; `advanceAfterCelebration()` unchanged (already advances index).

- [ ] **Step 1: Write the failing test**

```swift
// FidelTests/TracingSessionSizeTests.swift
import XCTest
import SwiftData
@testable import Fidel

@MainActor
final class TracingSessionSizeTests: XCTestCase {
    override func tearDown() { AppSettingsStore().dailyGoalTier = .regular; super.tearDown() }

    private func freshRepo() throws -> ProgressRepository {
        let container = try ModelContainer(
            for: UserProgress.self, FlashcardProgress.self, CharacterTraceMastery.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ProgressRepository(modelContext: container.mainContext)
    }

    // A fresh learner has empty trace mastery, so the session fills to the tier
    // size from the 238 new characters — proving the size both scales and is exact.
    func testStandardSessionSizeFollowsTier() throws {
        let store = AppSettingsStore()

        store.dailyGoalTier = .casual
        let casual = TracingSessionViewModel(); casual.configure(progressRepository: try freshRepo())
        casual.startSession(plan: .standard)
        XCTAssertEqual(casual.items.count, DailyGoalTier.casual.tracingSessionSize) // 5

        store.dailyGoalTier = .intense
        let intense = TracingSessionViewModel(); intense.configure(progressRepository: try freshRepo())
        intense.startSession(plan: .standard)
        XCTAssertEqual(intense.items.count, DailyGoalTier.intense.tracingSessionSize) // 16
    }
}
```

(Reset the tier in `tearDown` to `.regular` to avoid cross-test leakage.)

- [ ] **Step 2: Run test to verify it fails** (`test_sim`). Expected: FAIL — session still fixed at 8.

- [ ] **Step 3: Implement tier-driven size**

Replace the `static let standardSessionSize = 8` / `maxPromotionItems = 3` usage with an instance size read at session start:

```swift
// in startSession(plan:) for .standard:
let size = AppSettingsStore().dailyGoalTier.tracingSessionSize
let promotions = max(1, Int(Double(size) * 0.4))
items = Self.composeStandardSession(
    mastery: progressRepository?.allTraceMastery() ?? [],
    sessionSize: size, maxPromotionItems: promotions)
```

Change `composeStandardSession` signature to accept `sessionSize:` and `maxPromotionItems:` and use them at the current `:160/168/175/179` sites. Keep the composition logic identical otherwise.

- [ ] **Step 4: Implement auto-advance** in `TracingSessionView.swift:176-181`

```swift
.task(id: celebrationTaskKey) {
    guard viewModel.itemPhase == .celebrating else { return }
    viewModel.prewarmNextCharacter()
    let pause: Duration = reduceMotion ? .seconds(1.6) : .milliseconds(900)
    try? await Task.sleep(for: pause)
    guard !Task.isCancelled, viewModel.itemPhase == .celebrating else { return }
    if UIAccessibility.isVoiceOverRunning { return }
    viewModel.advanceAfterCelebration()
}
```

Keep the Continue/Finish button (now "advance now"). `reduceMotion` is already an `@Environment` in this view (used at `:173`).

- [ ] **Step 5: Run tests + smoke + commit**

`test_sim` (PASS), then `build_run_sim` and smoke: correct trace → ~1s pause → next character with no tap. Toggle Reduce Motion → longer pause. VoiceOver → manual button.

```bash
git add Fidel/Views/TracingSessionView.swift Fidel/ViewModels/TracingSessionViewModel.swift FidelTests/TracingSessionSizeTests.swift
git commit -m "feat(tracing): tier-driven session size + auto-advance on success

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 10: Pace picker in Settings + Today parity

**Files:**
- Modify: `Fidel/Views/ProgressView.swift` (settings area), `Fidel/ContentView.swift` (Today routing/copy)

- [ ] **Step 1: Tier picker UI**

In the You/Progress settings section add a segmented `Picker` bound to `AppSettingsStore().dailyGoalTier` over `DailyGoalTier.allCases`, each row showing `displayName` + `subtitle`. On change, optionally set `dailyXPGoal = tier.suggestedDailyXP` **only if** the user hasn't customized it (guard against overwriting; simplest: offer it as the default when first set, don't force). Keep the existing `dailyXPGoal` stepper.

- [ ] **Step 2: Today routing/copy**

Point the Today "Continue" CTA at the recommended action (reuse `NextStepPlanner` or route to Journey's recommended session). Update copy to be pace/recommendation oriented; remove any "unlock the next stage" language and the "N of 50 recognized" gating subtitle.

- [ ] **Step 3: Build + smoke + commit**

`build_run_sim`; change tier in Settings, confirm the Journey recommended session and tracing size react. Screenshot for review.

```bash
git add Fidel/Views/ProgressView.swift Fidel/ContentView.swift
git commit -m "feat(pace): add pace-tier picker and align Today with recommendations

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 11: Streak with slack (retention)

**Files:**
- Modify: `Fidel/Models/Models.swift` (`UserProgress` fields + `checkStreak`)
- Test: `FidelTests/StreakSlackTests.swift`

**Interfaces:**
- Produces: `UserProgress.streakFreezesAvailable: Int`, `weeklyStreakCount: Int`, `lastFreezeGrantWeek: Int`; `checkStreak()` auto-grants and auto-consumes freezes.

- [ ] **Step 1: Write the failing test**

```swift
// FidelTests/StreakSlackTests.swift — behavioral spec
// 1) A missed single day WITH a freeze available preserves currentStreak and decrements the freeze.
// 2) A missed day WITHOUT a freeze resets currentStreak but weeklyStreakCount is unaffected within the same week.
// 3) checkStreak grants at most the weekly freeze allotment once per ISO week.
// Implement with injected/simulated dates via lastPracticeDate manipulation (as the existing checkStreak tests do).
```

Implementer: write concrete assertions mirroring the existing `checkStreak` test style (manipulate `lastPracticeDate`), one XCTest func per numbered behavior.

- [ ] **Step 2: Run test to verify it fails** (`test_sim`). Expected: FAIL — fields/logic absent.

- [ ] **Step 3: Implement** additive fields (defaults `0`) and slack logic in `checkStreak()`: on a 2-day gap, if `streakFreezesAvailable > 0` consume one and keep the streak; else reset `currentStreak` (leave `weeklyStreakCount`). Grant `min(2, ...)` freezes at most once per ISO week using `lastFreezeGrantWeek`. Keep existing streak-increment behavior for consecutive days.

- [ ] **Step 4: Run tests** (`test_sim`). Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Fidel/Models/Models.swift FidelTests/StreakSlackTests.swift
git commit -m "feat(streak): add streak freezes + weekly streak slack

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 12: Round-trip new fields in backup/restore

**Files:**
- Modify: `Fidel/Services/ProgressExportService.swift`

- [ ] **Step 1: Extend the snapshot** — add `dailyGoalTier` (from `AppSettingsStore`) and the streak-slack fields to the export struct(s) (`:45`, `:94`) and the write-back (`:184`, `:224`). Keep all existing fields; make new fields optional-with-default on decode for backward compatibility with old backups.

- [ ] **Step 2: Merge logic** — for `streakFreezesAvailable`/`weeklyStreakCount` use the same "take max/union" convention as neighboring fields (`:184-189`); restore `dailyGoalTier` into settings like `dailyXPGoal` (`:224`).

- [ ] **Step 3: Build + test + commit**

`build_sim` + `test_sim` (add a round-trip test if the service is unit-tested today; otherwise a manual export/import smoke).

```bash
git add Fidel/Services/ProgressExportService.swift
git commit -m "feat(backup): round-trip pace tier and streak-slack fields

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 13: Final integration — build green, suite green, smoke

**Files:** none new (verification + cleanup)

- [ ] **Step 1:** `session_show_defaults`, then `build_sim` — zero errors, no references to deleted gating symbols anywhere (`grep` for `fidelRecognitionTarget`, `StageCriterion`, `checkAndAdvanceStage`, `isStageUnlocked`, `lockedStages` → expect no hits).
- [ ] **Step 2:** `test_sim` — full `FidelTests` suite green.
- [ ] **Step 3:** `build_run_sim` manual smoke: fresh install → recommended CTA present, no locks, can open any lesson; complete Lesson 1 → its characters show recognized in the Fidel chart and its mastery ring advances; tracing auto-advances on success; change pace tier → session size + recommendation react.
- [ ] **Step 4:** Update `Fidel/README.md`, `Fidel/CLAUDE.md`, and `Fidel/LEVEL_SYSTEM.md` where they describe the 4-stage gate / "Recognize 50+ characters" — replace with the open-path model. Commit docs separately (`docs: ...`).

```bash
git commit -am "chore(path): final integration verification

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review (author checklist — completed)

**Spec coverage:** §1 gate removal → Tasks 6–8; §2 interleave → Tasks 2–3; §3 mastery → Task 4 (+7 display); §4 NextStepPlanner → Task 5 (+6 wiring); §5 pace tiers → Tasks 1, 9, 10; §6 open-path UI → Task 7; §7 tracing → Task 9; §8 streak slack → Task 11; §9 migration/backup → Tasks 8, 12; testing → per-task + Task 13. All spec sections mapped.

**Placeholder scan:** Pure-logic tasks (1–5, 9) carry complete code. UI/refactor tasks (6–8, 10) specify exact files, interfaces, deletions, and per-step actions with the critical snippets, and explicitly iterate against XcodeBuildMCP (compiler-in-the-loop) — appropriate for SwiftUI where verbatim view code would be speculative. Behavioral test specs (Tasks 11–12) name each concrete assertion to write.

**Type consistency:** `DailyGoalTier` (`newCap`/`reviewCap`/`tracingSessionSize`/`suggestedDailyXP`) used identically in Tasks 1/5/9/10. `RecommendedSession`/`RecommendedSession.Kind`/`heroAction: HeroAction` consistent across Tasks 5/6/7. `MasteryTier` (`.new`…`.mastered`, `.label`) consistent across Tasks 4/6/7. `CurriculumService.shared.characterIds(in:)`/`characters(in:)`/`mastery(for:learnedItemIds:recognizedCharIds:)` consistent across Tasks 2/3/4/6.
