# Web ↔ iOS parity

The web version of Fidel runs in the browser with no install or build. It reads the same `Fidel/Data` content as the iOS app. This table records which app features it carries over and why. **Include** means the same behaviour. **Adapt** means the same learning goal with a browser-appropriate mechanism. **Exclude** means not on the web.

| Area | Feature | Web | Reason |
|---|---|---|---|
| **Shell** | Five-tab navigation (Today, Learn, Practice, Selam, You) | Adapt | Same four learning tabs. Selam depends on the decision below. A bottom tab bar on phones and a side rail on desktop. |
| **Today** | Recommended next session (`NextStepPlanner`), daily goal ring, quick paths, phrase of the day | Include | Pure logic over progress and content. |
| **Learn** | Open learning path: 8 lessons in four themed sections, recommended-next hero, mastery rings (New → Mastered) | Include | Pure logic (`CurriculumService`, mastery tiers). |
| | Lesson detail: patterns, vocabulary, phrases, culture tabs; "Complete" credits XP and Fidel characters | Include | Same content and crediting rules. |
| | Conversations: line-by-line dialogue, Amharic / transliteration / English, role-play, audio per line | Include | 261 conversation-line clips are bundled. |
| **Practice** | Flashcards with FSRS scheduling | Include | Same FSRS parameters; checked with shared golden fixtures. |
| | Quiz: multiple choice, typed translation, typed pronunciation | Include | |
| | Fill the Blank (cloze) | Include | |
| | Match Pairs | Include | |
| | Word Order | Include | Tap-to-place tiles work with touch and mouse. |
| | Sentence Builder | Include | |
| | Grammar reference (teach-first explainer over patterns) | Include | |
| | Reading: 5 graded passages with glossary and comprehension | Include | |
| | Speed Drill | Include | Timer-based, no platform dependency. |
| | Character Tracing: guided strokes, auto-advance, stroke-order animation | Adapt | Pointer Events drawing with the same stroke data. Scoring is reimplemented in TypeScript and checked against `DrawingEvaluator` with recorded strokes (Part C). PencilKit pressure is not available. |
| | Pronunciation practice (listen, record yourself, compare) | Adapt | Listen uses the bundled clips. Recording uses `MediaRecorder` with permission and is played back locally, never uploaded. Hidden if the browser has no microphone API. |
| **Reference** | Fidel chart with audio for all 238 characters | Include | 238 character clips are bundled. |
| | Phrasebook (706), vocabulary by category (1,038), search | Include | |
| | Numbers, Ethiopian months, ordinals, fractions | Include | |
| | Cultural notes (90) | Include | |
| **Audio** | Bundled Azure pronunciation clips (3,320) | Include | Served from the same files. Delivery strategy is decided by measurement in Part C. |
| | System text-to-speech fallback for text without a clip | Exclude | Browser voices for `am-ET` are rare and poor, so text without a clip just has no play button. |
| **Selam** | On-device AI tutor (Apple Foundation Models) | Exclude | Can't run in a browser. The tab becomes a card explaining the tutor runs privately on Apple devices, with an App Store link (decided 2026-11-22). |
| **You** | XP, levels, streaks with weekly freezes, achievements | Include | Same `UserProgress` rules (`checkStreak`, freeze grants). |
| | Daily goal tier (Casual / Regular / Serious / Intense) | Include | |
| | Backup export and import (JSON) | Include | Same file format as `ProgressExportService`, so a web backup imports on iOS and the reverse. Checked with round-trip tests (Part E). |
| | iCloud sync | Exclude | CloudKit is Apple-only. Backup files are the bridge between web and iOS. |
| | Sign in with Apple | Exclude | Not needed; the app works signed-out. |
| **Platform** | Offline after first load, installable | Adapt | A service worker and web app manifest (PWA). |
| | Dark mode | Include | The same light and dark palette from `Theme.swift`. |
| | Haptics, spring animations | Adapt | CSS transitions; `navigator.vibrate` where supported. |
| | Developer stroke tools | Exclude | Debug-only on iOS. |

## Selam on the web: options considered

1. **Point people to the iOS app (chosen).** The Selam tab is replaced by a short card explaining that the tutor runs privately on Apple devices, with an App Store link. No AI on the web, no keys, nothing to maintain.
2. **"Ask Fidel" lookup without AI.** Expose the same curriculum search Selam's tools use (words, grammar patterns, Fidel rows) as a smart search box. It's deterministic, works offline, and costs nothing, but it isn't a conversation.
3. **Chrome's built-in model (Prompt API, Gemini Nano)** with the same lookup tools. It's on-device and free, but works only in desktop Chrome with the feature available. Its Amharic support is untested, so it would need the same "quote only from tools" rule. It's experimental and could change under us.
4. **Bring your own API key** for a cloud model. This works everywhere, but it brings back the key handling that open-sourcing just removed, and it sends learner text to a third party.
