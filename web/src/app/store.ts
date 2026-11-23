// App state as signals, persisted to IndexedDB on every change. Screens call
// the actions here instead of touching progress or storage directly.
import { computed, signal } from '@preact/signals'
import type { Content } from '../content/content'
import { charId, wordId } from '../content/types'
import { exportBackup, defaultSettings, importBackup, type Settings } from '../logic/backup'
import { charactersInLesson, masteryMinStability } from '../logic/curriculum'
import { cardKey, type CardProgress, isDue, newCard, type Rating, reviewCard } from '../logic/fsrs'
import * as rules from '../logic/progress'
import { recordCompletion, type TraceMastery } from '../logic/trace/session'
import type { Database } from './db'

export const content = signal<Content | null>(null)
export const progress = signal<rules.UserProgress>(rules.emptyProgress())
export const settings = signal<Settings>(defaultSettings())
export const cards = signal<Map<string, CardProgress>>(new Map())
export const trace = signal<Map<string, TraceMastery>>(new Map())

let db: Database | null = null
const now = () => new Date()

export function hydrate(database: Database, snapshot: Awaited<ReturnType<Database['load']>>) {
  db = database
  if (snapshot.progress) progress.value = { ...rules.emptyProgress(), ...snapshot.progress }
  if (snapshot.settings) settings.value = { ...defaultSettings(), ...snapshot.settings }
  cards.value = new Map(snapshot.cards.map((c) => [cardKey(c.itemType, c.itemId), c]))
  trace.value = new Map(snapshot.trace.map((m) => [m.characterId, m]))
}

function setProgress(next: rules.UserProgress) {
  if (next === progress.value) return
  progress.value = next
  void db?.saveProgress(next)
}

export const actions = {
  addXP: (amount: number) => setProgress(rules.addXP(progress.value, amount, now())),
  markLessonStarted: (id: number) => setProgress(rules.markLessonStarted(progress.value, id)),
  /** ProgressRepository.completeLesson: also credits the Fidel characters the lesson uses. */
  completeLesson(id: number) {
    const t = now()
    let next = rules.completeLesson(progress.value, id, t)
    const lesson = content.value?.lessons.find((l) => l.id === id)
    if (lesson) for (const c of charactersInLesson(lesson, content.value!.fidelChart)) next = rules.recognizeCharacter(next, charId(c), t)
    setProgress(next)
  },
  learnPattern: (id: string) => setProgress(rules.learnPattern(progress.value, id, now())),
  masterVocabulary: (id: string) => setProgress(rules.masterVocabulary(progress.value, id, now())),
  practiceConversation: (id: number) => setProgress(rules.practiceConversation(progress.value, id, now())),
  recognizeCharacter: (id: string) => setProgress(rules.recognizeCharacter(progress.value, id, now())),

  reviewCard(itemId: string, itemType: string, rating: Rating) {
    const key = cardKey(itemType, itemId)
    const card = reviewCard(cards.value.get(key) ?? newCard(itemId, itemType, now()), rating, now())
    cards.value = new Map(cards.value).set(key, card)
    void db?.saveCard(card)
  },

  /** Records a completed trace; returns XP awarded and whether the level rose. */
  completeTrace(characterId: string, level: number, score: number, misses: number) {
    const result = recordCompletion(trace.value.get(characterId), characterId, level, score, misses, now())
    trace.value = new Map(trace.value).set(characterId, result.mastery)
    void db?.saveTrace(result.mastery)
    if (result.firstTrace) setProgress(rules.traceCharacter(progress.value, characterId, now()))
    else setProgress(rules.addXP(progress.value, result.xp, now()))
    return result
  },

  updateSettings(patch: Partial<Settings>) {
    settings.value = { ...settings.value, ...patch }
    void db?.saveSettings(settings.value)
  },

  exportBackup: () => exportBackup(progress.value, [...cards.value.values()], settings.value, now()),

  async importBackup(json: string) {
    const merged = importBackup(json, { progress: progress.value, cards: [...cards.value.values()], settings: settings.value })
    progress.value = merged.progress
    settings.value = merged.settings
    cards.value = new Map(merged.cards.map((c) => [cardKey(c.itemType, c.itemId), c]))
    await db?.replaceAll(merged.progress, merged.cards, merged.settings)
  },
}

/** Vocabulary flashcards due now (FlashcardManager.getDueItems(type: "vocabulary")). */
export const dueVocabulary = computed(() => {
  const t = now()
  return [...cards.value.values()].filter((c) => c.itemType === 'vocabulary' && isDue(c, t))
})

/** Items counted as learned for mastery rings (JourneyViewModel.buildPathSections). */
export const learnedItemIds = computed(() => {
  const ids = new Set(progress.value.vocabularyMastered)
  for (const c of cards.value.values()) if (c.stability >= masteryMinStability) ids.add(c.itemId)
  return ids
})

export const recognizedCharIds = computed(() => new Set(progress.value.fidelCharactersRecognized))

export function requireContent(): Content {
  if (!content.value) throw new Error('Content not loaded')
  return content.value
}

export { charId, wordId }
