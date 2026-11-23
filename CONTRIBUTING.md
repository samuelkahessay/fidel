# Contributing to Fidel

Thanks for helping people learn Amharic. There are two kinds of contribution, and the first needs no Swift at all.

## Fixing Amharic content

All learner-facing content lives in plain JSON in [`Fidel/Data`](Fidel/Data):

| File | What it holds |
|---|---|
| `vocabulary.json` | Words: `amharic`, `transliteration`, `english`, `category` |
| `phrases.json` | Phrases with optional usage `notes` |
| `patterns.json` | Grammar patterns, examples and substitutions |
| `conversations.json` | Dialogues, line by line |
| `cultural_notes.json` | Culture notes linked to lessons and conversations |
| `reading_passages.json` | Graded reading passages with questions |
| `fidel_chart.json` | The 238 Fidel characters and their romanizations |

If you spot a wrong translation, an unnatural phrase, a misspelling or a transliteration that doesn't match how the word is said:

- **Quickest:** open a [content correction issue](../../issues/new?template=content-correction.yml) with the current text and your suggested fix.
- **Or edit directly:** change the JSON and open a pull request. Explain the correction and, if you can, how you know (native speaker, dictionary, region).

Transliteration follows the app's simplified scheme (for example `t'ena yist'illiany` for ጤና ይስጥልኝ). Keep new entries consistent with the ones around them. Changing Amharic text in `phrases.json`, `vocabulary.json` or `conversations.json` may leave its bundled pronunciation clip out of date. That's fine; mention it in the pull request.

## Changing the app

Requirements: Xcode 26 and an iOS 26 simulator. See the [README](README.md#building) to build and run the tests.

Before opening a pull request, run the same checks CI runs:

```bash
xcrun swift-format format --in-place --recursive Fidel FidelTests
```

```bash
swiftlint lint --strict --baseline .swiftlint-baseline.json
```

```bash
xcodebuild test -project Fidel.xcodeproj -scheme Fidel -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO
```

Guidelines:

- **Keep changes focused.** One feature or fix per pull request, with tests for logic changes. Use [Conventional Commits](https://www.conventionalcommits.org) for commit messages (`feat:`, `fix:`, `docs:`, …).
- **Architecture:** SwiftUI views, `@Observable` view models, repositories for data access, services for logic. Content comes from `Fidel/Data` through `LessonRepository`.
- **Zero warnings.** CI fails on build warnings. `.swiftlint-baseline.json` lists known structural debt; please don't add to it.
- **No secrets.** The app must keep working offline with no API keys.
- **Run `git config blame.ignoreRevsFile .git-blame-ignore-revs`** once so `git blame` skips the bulk reformat.

## Changing the web version

The browser version in `web/` mirrors the app's logic in TypeScript. If you change scheduling, recommendations, streaks, backups or tracing in Swift, regenerate the shared fixtures and make the web pass them too:

```bash
xcodebuild test -project Fidel.xcodeproj -scheme Fidel -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:FidelTests/GoldenFixtureTests CODE_SIGNING_ALLOWED=NO TEST_RUNNER_FIDEL_WRITE_GOLDEN=1
```

```bash
cd web && npm test && npm run e2e
```

## Reporting bugs

Use the [bug report template](../../issues/new?template=bug-report.yml). Include the iOS version, device, and steps to reproduce.

## Code of conduct

Be kind and assume good faith. Many contributors are sharing their own language and culture, so treat that with care.
