// Port of FSRSAlgorithm (Fidel/Services/SpacedRepetition.swift). Keep in step
// with the Swift version; tests/golden/fsrs.json is checked by both XCTest and Vitest.
import { addDays, wholeDaysBetween } from './calendar'

export type Rating = 1 | 2 | 3 | 4 // again, hard, good, easy

const decay = -0.5
const factor = 19 / 81
const weights = [
  0.40255, 1.18385, 3.173, 15.69105, 7.1949, 0.5345, 1.4604, 0.0046, 1.54575, 0.1192, 1.01925, 1.9395, 0.11,
  0.29605, 2.2698, 0.2315, 2.9898, 0.51655, 0.6621,
]
const w = (i: number) => weights[i]!
export const requestRetention = 0.9
export const maximumInterval = 36500

const clamp = (x: number, lo: number, hi: number) => Math.min(Math.max(x, lo), hi)

export function forgettingCurve(elapsedDays: number, stability: number): number {
  return stability > 0 ? Math.pow(1 + (factor * elapsedDays) / stability, decay) : 0
}

const initStability = (g: Rating) => Math.max(w(g - 1), 0.1)
const initDifficulty = (g: Rating) => clamp(w(4) - Math.exp((g - 1) * w(5)) + 1, 1, 10)

function nextRecallStability(d: number, s: number, r: number, g: Rating) {
  const hardPenalty = g === 2 ? w(15) : 1
  const easyBonus = g === 4 ? w(16) : 1
  const next = s * (1 + Math.exp(w(8)) * (11 - d) * Math.pow(s, -w(9)) * (Math.exp((1 - r) * w(10)) - 1) * hardPenalty * easyBonus)
  return clamp(next, 0.01, maximumInterval)
}

function nextForgetStability(d: number, s: number, r: number) {
  return clamp(w(11) * Math.pow(d, -w(12)) * (Math.pow(s + 1, w(13)) - 1) * Math.exp((1 - r) * w(14)), 0.01, maximumInterval)
}

function nextDifficulty(d: number, g: Rating) {
  const next = d + (-w(6) * (g - 3) * (10 - d)) / 9
  return clamp(w(7) * initDifficulty(4) + (1 - w(7)) * next, 1, 10)
}

/** Swift `round` rounds half away from zero; JS Math.round rounds half up. */
const roundHalfAwayFromZero = (x: number) => Math.sign(x) * Math.round(Math.abs(x))

export function nextInterval(stability: number): number {
  const interval = stability * ((Math.pow(requestRetention, 1 / decay) - 1) / factor)
  return clamp(roundHalfAwayFromZero(interval), 1, maximumInterval)
}

export function calculateNextReview(rating: Rating, currentStability: number, currentDifficulty: number, elapsedDays: number) {
  let stability = currentStability
  let difficulty = currentDifficulty
  if (stability === 0 && difficulty === 0) {
    stability = initStability(rating)
    difficulty = initDifficulty(rating)
  } else {
    const r = forgettingCurve(elapsedDays, stability)
    stability = rating === 1 ? nextForgetStability(difficulty, stability, r) : nextRecallStability(difficulty, stability, r, rating)
    difficulty = nextDifficulty(difficulty, rating)
  }
  return { interval: nextInterval(stability), stability, difficulty }
}

/** Mirrors `FlashcardProgress` and `FlashcardProgressSnapshot` (backup format). */
export interface CardProgress {
  itemId: string
  itemType: 'vocabulary' | 'phrase' | string
  easeFactor: number
  interval: number
  repetitions: number
  nextReviewDate: string // ISO-8601
  lastReviewDate: string | null
  stability: number
  difficulty: number
  lapses: number
}

export function newCard(itemId: string, itemType: string, now: Date): CardProgress {
  return {
    itemId, itemType, easeFactor: 2.5, interval: 0, repetitions: 0,
    nextReviewDate: now.toISOString(), lastReviewDate: null, stability: 0, difficulty: 0, lapses: 0,
  }
}

/** `FSRSAlgorithm.updateFlashcardProgress`. Returns a new card. */
export function reviewCard(card: CardProgress, rating: Rating, now: Date): CardProgress {
  const elapsed = card.lastReviewDate ? wholeDaysBetween(new Date(card.lastReviewDate), now) : 0
  const result = calculateNextReview(rating, card.stability, card.difficulty, elapsed)
  return {
    ...card,
    interval: result.interval,
    stability: result.stability,
    difficulty: result.difficulty,
    lastReviewDate: now.toISOString(),
    nextReviewDate: addDays(now, result.interval).toISOString(),
    repetitions: card.repetitions + 1,
    lapses: card.lapses + (rating === 1 ? 1 : 0),
  }
}

export const isDue = (card: CardProgress, now: Date) => new Date(card.nextReviewDate) <= now
export const cardKey = (itemType: string, itemId: string) => `${itemType}::${itemId}`
