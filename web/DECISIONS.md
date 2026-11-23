# Web stack decisions

Each choice was settled by a prototype or a measurement on 2026-11-22: macOS 27.2, Node 22.19, Vite 6.4, Chromium 1223 (Playwright build), Lighthouse 12. The prototypes lived in a scratch folder; the commands and numbers are recorded here so they can be rerun.

## 1. Shared logic: TypeScript port, not SwiftWasm

**Experiment.** I installed the official Swift 6.4.2 WebAssembly SDK (`swift-6.4.2-RELEASE_wasm`, sha256 `83baca83…0da5`) and built a package with the FSRS scheduler exported to JavaScript (`@_expose(wasm)`). I tried both the full SDK and the embedded SDK.

**Result.** Neither built with Xcode's toolchain:

- **Full SDK:** `unableToFind(tool: "swift-autolink-extract")`. The linker step fails because Xcode's toolchain has no WebAssembly linker tooling.
- **Embedded SDK:** `compiled module was created by a different version of the compiler`.

SwiftWasm needs the separate open-source swift.org toolchain, installed side by side with Xcode, on every contributor's machine and on CI. The TypeScript port of the same FSRS code is **461 bytes** minified and gzipped.

**Decision.** Port the small amount of pure shared logic to TypeScript: FSRS (about 80 Swift lines), `NextStepPlanner` (about 70), mastery tiers, streak rules and the trace engine. Keep the two in step with golden JSON fixtures that run in both XCTest and Vitest (Part E). If a fixture changes on one side, CI fails on the other.

## 2. UI: Preact

The same Flashcards screen (flip card, four rating buttons, FSRS update, counter) was built three ways with Vite and measured with Lighthouse's default mobile profile (simulated slow 4G, 4× CPU), median of 3 runs.

| Variant | JS (min) | JS (gzip) | First contentful paint | Performance | Source lines |
|---|---|---|---|---|---|
| Plain TypeScript (`innerHTML`) | 2.6 KB | 1.2 KB | 901 ms | 100 | 20 |
| **Preact 10** | 15.6 KB | 6.4 KB | 1,051 ms | 100 | 20 |
| Svelte 5 | 49.4 KB | 18.5 KB | 1,201 ms | 100 | 18 |

**Decision: Preact.** All three are fast. Plain TypeScript is 150 ms quicker to first paint, but its string templates would have to grow to about 20 screens with manual HTML escaping of every content string, which is a correctness and security risk once contributors edit the JSON. Preact costs 5 KB more gzipped for typed components and DOM diffing. Svelte 5's runtime is three times Preact's and wins nothing measurable.

## 3. Tracing: Canvas for live ink, SVG for the guide; TypeScript port of `TraceEngine`

**Which Swift code to match.** The app scores live tracing with `TraceEngine` and `TraceGeometry`: arc-length progress through a forgiving corridor, with a "magnet" snap on release. `DrawingEvaluator` is only a secondary check. The web port therefore reimplements `TraceEngine` and `TraceGeometry`, including `StrokeSmoother`'s Catmull-Rom smoothing and flattening. Parity is checked by replaying the same recorded and perturbed touch sequences through both engines (Part E).

**Rendering experiment.** 600 pointer moves drawing a spiral, with CPU throttled 4×, median of 3 runs. Time is the per-event handler cost.

| Ink rendering | Mean | p95 | Mean over the last 100 moves |
|---|---|---|---|
| **Canvas** (`lineTo` per move) | 0.026 ms | 0.100 ms | 0.023 ms |
| SVG (rewrite `path d`) | 0.155 ms | 0.500 ms | 0.237 ms |

Canvas stays flat. SVG grows with stroke length because the whole path is rebuilt on every move, and it adds style and paint work after the handler returns.

**Decision.** Live ink on Canvas. The static guide (glyph outline and stroke-order arrows) as SVG, which scales crisply and takes the theme's CSS colors.

**Stroke data.** `fidel_stroke_data.json` is 10.2 MB raw (1.83 MB gzipped). The build writes one file per character, rounded to 4 decimal places (about 0.04 px at 360 px): 0.45 MB gzipped in total, about 1.7 KB per character, loaded when that character is traced. Part E checks that rounding doesn't change any pass/fail result.

## 4. Audio: lazy, cached per clip, with opt-in full download

The manifest references 3,320 clips totalling 41.6 MB (median 11.4 KB, p95 20.2 KB): words 11.8 MB, vocabulary 11.8 MB, phrases 10.0 MB, conversation lines 5.4 MB, Fidel characters 2.7 MB.

| Strategy | Slow 4G (1.6 Mbps) | 10 Mbps | 50 Mbps |
|---|---|---|---|
| Precache everything on install | 208 s | 33 s | 7 s |
| Fetch one median clip on first play | 57 ms | 9 ms | 2 ms |

**Decision.** The service worker precaches the app shell, the content JSON and the fonts, then fetches each clip on first play and keeps it (cache-first). Anything heard once works offline. The You tab gets an opt-in **"Download all audio (42 MB)"** for full offline use. The build turns the 1.76 MB audio manifest into a compact id-to-file map.

## Content pipeline

The web build reads `Fidel/Data/*.json`, `Fidel/Audio` and `Fidel/fidel_stroke_data.json` directly and writes derived assets into the build output only. Nothing under `web/` stores a copy of content. Gzipped sizes of the content JSON: vocabulary 21 KB, phrases 25 KB, patterns 15 KB, conversations 17 KB, cultural notes 18 KB, everything else under 5 KB each.
