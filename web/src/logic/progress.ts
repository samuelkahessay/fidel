// Port of the UserProgress rules in Fidel/Models/Models.swift. Mutators return
// a new object so Preact state stays immutable.
import { startOfDay, weekKey, wholeDaysBetween } from './calendar'

/** Field names match `UserProgressSnapshot` in the backup format. */
export interface UserProgress {
  totalXP: number
  currentStreak: number
  longestStreak: number
  lastPracticeDate: string | null
  lessonsCompleted: number[]
  lessonsInProgress: number[]
  patternsLearned: string[]
  vocabularyMastered: string[]
  conversationsPracticed: number[]
  dailyGoal: number
  todayXP: number
  achievements: string[]
  fidelCharactersRecognized: string[]
  charactersTraced: string[]
  currentStage: number
  streakFreezesAvailable: number
  weeklyStreakCount: number
  lastFreezeGrantWeek: number
}

export const emptyProgress = (): UserProgress => ({
  totalXP: 0, currentStreak: 0, longestStreak: 0, lastPracticeDate: null,
  lessonsCompleted: [], lessonsInProgress: [], patternsLearned: [], vocabularyMastered: [],
  conversationsPracticed: [], dailyGoal: 50, todayXP: 0, achievements: [],
  fidelCharactersRecognized: [], charactersTraced: [], currentStage: 0,
  streakFreezesAvailable: 0, weeklyStreakCount: 0, lastFreezeGrantWeek: 0,
})

/** `UserProgress.checkStreak()`, including the weekly freeze grant. */
export function checkStreak(p: UserProgress, now: Date): UserProgress {
  const next = { ...p }
  const today = startOfDay(now)

  const week = weekKey(today)
  if (week !== next.lastFreezeGrantWeek) {
    next.streakFreezesAvailable = Math.min(next.streakFreezesAvailable + 1, 2)
    next.lastFreezeGrantWeek = week
    next.weeklyStreakCount += 1
  }

  if (next.lastPracticeDate) {
    const daysDiff = wholeDaysBetween(startOfDay(new Date(next.lastPracticeDate)), today)
    if (daysDiff === 1) {
      next.currentStreak += 1
      next.longestStreak = Math.max(next.longestStreak, next.currentStreak)
    } else if (daysDiff === 2) {
      if (next.streakFreezesAvailable > 0) next.streakFreezesAvailable -= 1
      else next.currentStreak = 1
    } else if (daysDiff > 2) {
      next.currentStreak = 1
    }
  } else {
    next.currentStreak = 1
  }
  next.lastPracticeDate = now.toISOString()
  return next
}

export function addXP(p: UserProgress, amount: number, now: Date): UserProgress {
  return checkStreak({ ...p, totalXP: p.totalXP + amount, todayXP: todayXP(p, now) + amount }, now)
}

const append = <T>(list: T[], item: T) => (list.includes(item) ? list : [...list, item])

export function recognizeCharacter(p: UserProgress, id: string, now: Date): UserProgress {
  if (p.fidelCharactersRecognized.includes(id)) return p
  return addXP({ ...p, fidelCharactersRecognized: [...p.fidelCharactersRecognized, id] }, 2, now)
}

export function traceCharacter(p: UserProgress, id: string, now: Date): UserProgress {
  if (p.charactersTraced.includes(id)) return p
  return addXP(
    { ...p, charactersTraced: [...p.charactersTraced, id], fidelCharactersRecognized: append(p.fidelCharactersRecognized, id) },
    5,
    now,
  )
}

export function markLessonStarted(p: UserProgress, id: number): UserProgress {
  if (p.lessonsCompleted.includes(id) || p.lessonsInProgress.includes(id)) return p
  return { ...p, lessonsInProgress: [...p.lessonsInProgress, id] }
}

export function completeLesson(p: UserProgress, id: number, now: Date): UserProgress {
  let next = p
  if (!p.lessonsCompleted.includes(id)) next = addXP({ ...p, lessonsCompleted: [...p.lessonsCompleted, id] }, 25, now)
  return { ...next, lessonsInProgress: next.lessonsInProgress.filter((x) => x !== id) }
}

export function learnPattern(p: UserProgress, id: string, now: Date): UserProgress {
  return p.patternsLearned.includes(id) ? p : addXP({ ...p, patternsLearned: [...p.patternsLearned, id] }, 10, now)
}

export function masterVocabulary(p: UserProgress, id: string, now: Date): UserProgress {
  return p.vocabularyMastered.includes(id) ? p : addXP({ ...p, vocabularyMastered: [...p.vocabularyMastered, id] }, 5, now)
}

export function practiceConversation(p: UserProgress, id: number, now: Date): UserProgress {
  return p.conversationsPracticed.includes(id) ? p : addXP({ ...p, conversationsPracticed: [...p.conversationsPracticed, id] }, 20, now)
}

/** XP earned today: the stored `todayXP` only counts if the last practice was today. */
export function todayXP(p: UserProgress, now: Date): number {
  if (!p.lastPracticeDate) return 0
  return wholeDaysBetween(startOfDay(new Date(p.lastPracticeDate)), startOfDay(now)) === 0 ? p.todayXP : 0
}

export const level = (p: UserProgress) => Math.max(Math.floor(p.totalXP / 100) + 1, 1)
export const levelProgress = (p: UserProgress) => (p.totalXP % 100) / 100
