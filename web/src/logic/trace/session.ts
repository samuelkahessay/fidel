// Tracing session rules from TracingSessionViewModel and
// ProgressRepository.recordTraceCompletion.
import { charId, type FidelCharacter } from '../../content/types'
import type { AttemptStats } from './engine'

/** CharacterTraceMastery: 0 never, 1 full guide, 2 faint guide, 3 from memory. */
export interface TraceMastery {
  characterId: string
  level: number
  bestScore: number
  attempts: number
  totalMisses: number
  lastPracticedAt: string | null
}

export interface SessionItem {
  character: FidelCharacter
  level: number
}

export const tracePromotionScore = 70

export const guidedScore = (misses: number, hintsAutoPlayed: number) => Math.max(50, 100 - 10 * misses - 15 * hintsAutoPlayed)

export function sessionScore(stats: AttemptStats, usedGuideAssist: boolean): number {
  const base = stats.accessibilityCompletions > 0 ? 70 : guidedScore(stats.misses, stats.hintsAutoPlayed)
  return usedGuideAssist ? Math.min(base, 69) : base
}

/** Vowel-order-1 forms of every row first, then the rest, limited to characters with stroke data. */
export function curriculumOrder(chart: FidelCharacter[][], hasStrokes: (id: string) => boolean): FidelCharacter[] {
  const first = chart.map((row) => row.find((c) => c.vowelOrder === 1)).filter((c): c is FidelCharacter => !!c)
  const rest = chart.flatMap((row) => row.filter((c) => c.vowelOrder !== 1))
  return [...first, ...rest].filter((c) => hasStrokes(charId(c)))
}

/** `TracingSessionViewModel.composeStandardSession`. */
export function composeSession(
  mastery: TraceMastery[],
  ordered: FidelCharacter[],
  sessionSize: number,
  maxPromotionItems = Math.max(1, Math.floor(sessionSize * 0.4)),
): SessionItem[] {
  const byId = new Map(mastery.map((m) => [m.characterId, m]))
  const charById = new Map(ordered.map((c) => [charId(c), c]))
  const due = mastery
    .filter((m) => m.level >= 1 && m.level < 3)
    .sort((a, b) => (a.lastPracticedAt ?? '').localeCompare(b.lastPracticedAt ?? ''))
    .slice(0, maxPromotionItems)
    .flatMap((m) => {
      const c = charById.get(m.characterId)
      return c ? [{ character: c, level: m.level + 1 }] : []
    })
  const fresh = ordered
    .filter((c) => (byId.get(charId(c))?.level ?? 0) === 0)
    .slice(0, Math.max(0, sessionSize - due.length))
    .map((c) => ({ character: c, level: 1 }))

  const result: SessionItem[] = []
  while (result.length < sessionSize && (fresh.length || due.length)) {
    if (fresh.length) result.push(fresh.shift()!)
    if (result.length < sessionSize && due.length) result.push(due.shift()!)
  }
  return result
}

/** `recordTraceCompletion`: returns the updated mastery and the XP the learner earns. */
export function recordCompletion(
  existing: TraceMastery | undefined,
  characterId: string,
  completedLevel: number,
  score: number,
  misses: number,
  now: Date,
): { mastery: TraceMastery; xp: number; promoted: boolean; firstTrace: boolean } {
  const m: TraceMastery = existing
    ? { ...existing }
    : { characterId, level: 0, bestScore: 0, attempts: 0, totalMisses: 0, lastPracticedAt: null }
  m.attempts += 1
  m.totalMisses += misses
  m.bestScore = Math.max(m.bestScore, score)
  m.lastPracticedAt = now.toISOString()
  const promoted = completedLevel === m.level + 1 && score >= tracePromotionScore
  if (!promoted) return { mastery: m, xp: 1, promoted, firstTrace: false }
  m.level = completedLevel
  return { mastery: m, xp: completedLevel === 1 ? 5 : completedLevel === 2 ? 8 : 12, promoted, firstTrace: completedLevel === 1 }
}
