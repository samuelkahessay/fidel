// The TypeScript ports against the golden fixtures produced by the Swift app
// (FidelTests/GoldenFixtureTests.swift). A failure here means the web and iOS
// behaviour have drifted apart.
import fs from 'node:fs'
import path from 'node:path'
import { describe, expect, it } from 'vitest'
import { buildContent as buildRaw } from '../../plugins/content'
import { buildContent } from '../../src/content/content'
import { charId, wordId } from '../../src/content/types'
import { importBackup, defaultSettings } from '../../src/logic/backup'
import { charactersInLesson, mastery } from '../../src/logic/curriculum'
import { calculateNextReview, newCard, type Rating } from '../../src/logic/fsrs'
import { plan, type Tier } from '../../src/logic/planner'
import { addXP, completeLesson, emptyProgress, markLessonStarted } from '../../src/logic/progress'
import { TraceEngine, recordingGlyphScale } from '../../src/logic/trace/engine'

const golden = (name: string) =>
  JSON.parse(fs.readFileSync(path.resolve(__dirname, '../../../FidelTests/Golden', `${name}.json`), 'utf8'))

/** "yyyy-MM-ddTHH:mm" in local time, as the Swift fixture writer parses it. */
const local = (s: string) => {
  const [d, t] = s.split('T') as [string, string]
  const [y, m, day] = d.split('-').map(Number) as [number, number, number]
  const [h, min] = t.split(':').map(Number) as [number, number]
  return new Date(y, m - 1, day, h, min)
}

const content = buildContent(buildRaw() as never)

describe('FSRS', () => {
  for (const c of golden('fsrs').cases) {
    it(`rating ${c.rating} from s=${c.stability} d=${c.difficulty} after ${c.elapsedDays}d`, () => {
      const r = calculateNextReview(c.rating as Rating, c.stability, c.difficulty, c.elapsedDays)
      expect(r.interval).toBe(c.expected.interval)
      expect(r.stability).toBeCloseTo(c.expected.stability, 10)
      expect(r.difficulty).toBeCloseTo(c.expected.difficulty, 10)
    })
  }
})

describe('NextStepPlanner', () => {
  for (const c of golden('planner').cases) {
    it(JSON.stringify(c.input), () => {
      const s = plan({ ...c.input, tier: c.input.tier as Tier })
      expect({
        kind: s.kind, lessonId: s.lessonId ?? null, reviewCount: s.reviewCount, newCount: s.newCount,
        estimatedMinutes: s.estimatedMinutes, eyebrow: s.eyebrow, title: s.title, detail: s.detail,
      }).toEqual(c.expected)
    })
  }
})

describe('lessons and mastery', () => {
  const fixture = golden('lessons')
  for (const row of fixture.lessons) {
    it(`lesson ${row.id} has the same patterns, words, phrases and characters`, () => {
      const lesson = content.lessons.find((l) => l.id === row.id)!
      expect(lesson.patterns.map((p) => p.id)).toEqual(row.patternIds)
      expect(lesson.vocabulary.map(wordId)).toEqual(row.vocabularyIds)
      expect(lesson.phrases.map((p) => p.id)).toEqual(row.phraseIds)
      expect(charactersInLesson(lesson, content.fidelChart).map(charId)).toEqual(row.characterIds)
    })
  }
  for (const c of fixture.mastery) {
    it(`lesson ${c.lessonId} mastery with ${c.learnedItemIds.length} items learned`, () => {
      const lesson = content.lessons.find((l) => l.id === c.lessonId)!
      const m = mastery(lesson, content.fidelChart, new Set(c.learnedItemIds), new Set(c.recognizedCharIds))
      expect(m.tier).toBe(c.expected.tier)
      expect(m.fraction).toBeCloseTo(c.expected.fraction, 12)
    })
  }
})

describe('streaks and daily XP', () => {
  for (const c of golden('progress').cases) {
    it(c.name, () => {
      let p = { ...emptyProgress(), ...c.start, lastPracticeDate: c.start.lastPracticeDate ? local(c.start.lastPracticeDate).toISOString() : null }
      for (const step of c.steps) {
        const at = local(step.at)
        if (step.op === 'addXP') p = addXP(p, step.value, at)
        else if (step.op === 'markLessonStarted') p = markLessonStarted(p, step.value)
        else if (step.op === 'completeLesson') p = completeLesson(p, step.value, at)
      }
      for (const [key, value] of Object.entries(c.expected)) expect(p[key as keyof typeof p], key).toEqual(value)
    })
  }
})

describe('backup import', () => {
  for (const c of golden('backup').cases) {
    it(c.name, () => {
      const now = new Date('2026-03-04T12:00:00Z')
      const progress = { ...emptyProgress(), ...c.local }
      delete (progress as Record<string, unknown>).cards
      const cards = (c.local.cards ?? []).map((x: { itemId: string; repetitions: number }) => ({
        ...newCard(x.itemId, 'vocabulary', now), repetitions: x.repetitions,
      }))
      const result = importBackup(JSON.stringify(c.backup), { progress, cards, settings: defaultSettings() })
      expect(result.progress.totalXP).toBe(c.expected.totalXP)
      expect(result.progress.lessonsCompleted).toEqual(c.expected.lessonsCompleted)
      expect(result.progress.lessonsInProgress).toEqual(c.expected.lessonsInProgress)
      expect(result.settings.dailyGoalTier).toBe(c.expected.dailyGoalTier)
      const merged = [...result.cards].sort((a, b) => a.itemId.localeCompare(b.itemId))
      expect(merged.map((x) => ({ itemId: x.itemId, repetitions: x.repetitions, interval: x.interval }))).toEqual(c.expected.cards)
    })
  }
})

describe('tracing engine', () => {
  const fixture = golden('trace')
  const strokeData = JSON.parse(fs.readFileSync(path.resolve(__dirname, '../../../Fidel/fidel_stroke_data.json'), 'utf8')).characters
  const rounded = (v: unknown): unknown =>
    typeof v === 'number' ? Math.round(v * 1e4) / 1e4 : Array.isArray(v) ? v.map(rounded) : v && typeof v === 'object' ? Object.fromEntries(Object.entries(v).map(([k, x]) => [k, rounded(x)])) : v

  for (const precision of ['full', '4dp'] as const) {
    for (const c of fixture.characters) {
      const source = precision === 'full' ? strokeData[c.id] : rounded(strokeData[c.id])
      const canvas = { width: fixture.canvas[0], height: fixture.canvas[1] }

      it(`${c.id} ${c.character} (${precision}) builds the same traceable strokes`, () => {
        const engine = new TraceEngine()
        engine.configure(source.strokes, canvas, c.glyphStrokeWidth, recordingGlyphScale)
        expect(engine.strokes.length).toBe(c.strokes.length)
        engine.strokes.forEach((s, i) => {
          const expected = c.strokes[i]
          if (precision === 'full') {
            expect(s.totalLength).toBeCloseTo(expected.totalLength, 6)
            expect(s.corridorRadius).toBeCloseTo(expected.corridorRadius, 6)
          } else {
            // The shipped 4-dp stroke data shifts lengths by under 0.1%; replays below must still match exactly.
            expect(Math.abs(s.totalLength - expected.totalLength) / expected.totalLength).toBeLessThan(0.001)
            expect(Math.abs(s.corridorRadius - expected.corridorRadius) / expected.corridorRadius).toBeLessThan(0.001)
          }
          expect(s.isDot).toBe(expected.isDot)
          if (precision === 'full') expect(s.polyline.length).toBe(expected.polylineCount)
        })
      })

      for (const replay of c.replays) {
        it(`${c.id} ${c.character} (${precision}) ${replay.scenario} replay`, () => {
          const engine = new TraceEngine()
          engine.configure(source.strokes, canvas, c.glyphStrokeWidth, recordingGlyphScale)
          const events: string[] = []
          engine.onEvent = (e) => {
            if (e.type === 'strokeStarted') events.push(`started:${e.index}`)
            else if (e.type === 'strokeCompleted') events.push(`completed:${e.index}`)
            else if (e.type === 'miss') events.push(`miss:${e.index}:${e.count}`)
            else if (e.type === 'hintAutoPlayed') events.push(`hint:${e.index}`)
            else events.push(`character:${e.stats.misses}:${e.stats.hintsAutoPlayed}`)
          }
          for (const [phase, x, y, t] of replay.touches) {
            const p = { x, y }
            if (phase === 'began') engine.touchBegan(p, t)
            else if (phase === 'moved') engine.touchMoved(p, t)
            else engine.touchEnded(p, t)
            if (engine.phase === 'snapping') engine.strokeMagnetSnapFinished()
            else if (engine.phase === 'strokeComplete') engine.strokeSnapFinished()
            else if (engine.phase === 'playingHint') engine.hintPlaybackFinished()
          }
          expect(events).toEqual(replay.expected.events)
          expect(engine.phase).toBe(replay.expected.finalPhase)
          expect(engine.activeStrokeIndex).toBe(replay.expected.activeStrokeIndex)
        })
      }
    }
  }
})
