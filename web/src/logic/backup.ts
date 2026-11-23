// The iOS backup format (ProgressBackupSnapshot, Fidel/Services/ProgressExportService.swift),
// so a backup made on the web restores on iPhone and the reverse.
import type { CardProgress } from './fsrs'
import { cardKey } from './fsrs'
import { defaultTier, type Tier, tiers } from './planner'
import { emptyProgress, type UserProgress } from './progress'

export const backupVersion = 1

export interface Settings {
  dailyXPGoal: number
  preferredResponseLanguage: string
  showsTransliteration: boolean
  autoPlaysPronunciation: boolean
  hapticsEnabled: boolean
  selectedReferenceTab: number
  showsAITools: boolean
  onboardingComplete: boolean
  lastOpenedActivity: string | null
  dailyGoalTier: Tier
}

/** `AppSettingsStore.registerDefaults()`. */
export const defaultSettings = (): Settings => ({
  dailyXPGoal: 50, preferredResponseLanguage: 'mixed', showsTransliteration: true,
  autoPlaysPronunciation: true, hapticsEnabled: true, selectedReferenceTab: 0, showsAITools: true,
  onboardingComplete: false, lastOpenedActivity: null, dailyGoalTier: defaultTier,
})

export interface Backup {
  version: number
  exportedAt: string
  userProgress: UserProgress | null
  flashcards: CardProgress[]
  settings: Settings
}

/** Swift's JSONEncoder .iso8601 writes whole seconds with a Z suffix. */
const isoSeconds = (iso: string) => new Date(iso).toISOString().replace(/\.\d{3}Z$/, 'Z')

export function exportBackup(progress: UserProgress, cards: CardProgress[], settings: Settings, now: Date): string {
  const backup: Backup = {
    version: backupVersion,
    exportedAt: isoSeconds(now.toISOString()),
    userProgress: { ...progress, lastPracticeDate: progress.lastPracticeDate && isoSeconds(progress.lastPracticeDate) },
    flashcards: cards.map((c) => ({
      ...c,
      nextReviewDate: isoSeconds(c.nextReviewDate),
      lastReviewDate: c.lastReviewDate && isoSeconds(c.lastReviewDate),
    })),
    settings,
  }
  // Sorted keys, like the app's `.sortedKeys` output.
  return JSON.stringify(sortKeys(backup), null, 2)
}

function sortKeys(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(sortKeys)
  if (value && typeof value === 'object') {
    return Object.fromEntries(Object.keys(value).sort().map((k) => [k, sortKeys((value as Record<string, unknown>)[k])]))
  }
  return value
}

export class BackupError extends Error {}

const union = <T>(a: T[], b: T[]) => [...a, ...b.filter((x) => !a.includes(x))]
const maxDate = (a: string | null, b: string | null) => (!a ? b : !b ? a : new Date(a) >= new Date(b) ? a : b)

/** `ProgressExportService.importData`: merges, never discards local progress. */
export function importBackup(
  json: string,
  local: { progress: UserProgress; cards: CardProgress[]; settings: Settings },
): { progress: UserProgress; cards: CardProgress[]; settings: Settings } {
  let backup: Partial<Backup>
  try {
    backup = JSON.parse(json)
  } catch {
    throw new BackupError('This file is not a Fidel backup.')
  }
  if (backup.version !== backupVersion) throw new BackupError(`Unsupported Fidel backup version ${backup.version}.`)

  let progress = local.progress
  const s = backup.userProgress
  if (s) {
    const p = { ...emptyProgress(), ...local.progress }
    const lessonsCompleted = union(p.lessonsCompleted, s.lessonsCompleted ?? [])
    progress = {
      ...p,
      totalXP: Math.max(p.totalXP, s.totalXP ?? 0),
      currentStreak: Math.max(p.currentStreak, s.currentStreak ?? 0),
      longestStreak: Math.max(p.longestStreak, s.longestStreak ?? 0),
      lastPracticeDate: maxDate(p.lastPracticeDate, s.lastPracticeDate ?? null),
      lessonsCompleted,
      lessonsInProgress: union(p.lessonsInProgress, s.lessonsInProgress ?? []).filter((id) => !lessonsCompleted.includes(id)),
      patternsLearned: union(p.patternsLearned, s.patternsLearned ?? []),
      vocabularyMastered: union(p.vocabularyMastered, s.vocabularyMastered ?? []),
      conversationsPracticed: union(p.conversationsPracticed, s.conversationsPracticed ?? []),
      dailyGoal: s.dailyGoal ?? p.dailyGoal,
      todayXP: Math.max(p.todayXP, s.todayXP ?? 0),
      achievements: union(p.achievements, s.achievements ?? []),
      fidelCharactersRecognized: union(p.fidelCharactersRecognized, s.fidelCharactersRecognized ?? []),
      charactersTraced: union(p.charactersTraced, s.charactersTraced ?? []),
      currentStage: Math.max(p.currentStage, s.currentStage ?? 0),
      streakFreezesAvailable: Math.max(p.streakFreezesAvailable, s.streakFreezesAvailable ?? 0),
      weeklyStreakCount: Math.max(p.weeklyStreakCount, s.weeklyStreakCount ?? 0),
      lastFreezeGrantWeek: Math.max(p.lastFreezeGrantWeek, s.lastFreezeGrantWeek ?? 0),
    }
  }

  const byKey = new Map(local.cards.map((c) => [cardKey(c.itemType, c.itemId), c]))
  for (const incoming of backup.flashcards ?? []) {
    const key = cardKey(incoming.itemType, incoming.itemId)
    const existing = byKey.get(key)
    if (!existing || incoming.repetitions >= existing.repetitions) byKey.set(key, { ...incoming })
  }

  const t = backup.settings?.dailyGoalTier
  const settings: Settings = backup.settings
    ? { ...defaultSettings(), ...backup.settings, dailyGoalTier: t && t in tiers ? t : defaultTier }
    : local.settings

  return { progress, cards: [...byKey.values()], settings }
}
