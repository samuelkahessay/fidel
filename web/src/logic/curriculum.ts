// Port of CurriculumService and MasteryTier (Fidel/Services/CurriculumService.swift).
import { charId, type FidelCharacter, type Lesson, wordId } from '../content/types'

export function charactersInLesson(lesson: Lesson, chart: FidelCharacter[][]): FidelCharacter[] {
  const index = new Map<string, FidelCharacter>()
  for (const row of chart) for (const c of row) index.set(c.character, c)
  const seen = new Set<string>()
  const result: FidelCharacter[] = []
  for (const text of [...lesson.vocabulary.map((v) => v.amharic), ...lesson.phrases.map((p) => p.amharic)]) {
    // Swift iterates grapheme clusters (`String.map`); Ethiopic syllables are single scalars.
    for (const glyph of Array.from(new Intl.Segmenter().segment(text), (s) => s.segment)) {
      const c = index.get(glyph)
      if (c && !seen.has(charId(c))) {
        seen.add(charId(c))
        result.push(c)
      }
    }
  }
  return result
}

export const masteryTiers = ['New', 'Started', 'Familiar', 'Proficient', 'Mastered'] as const
export type MasteryTier = (typeof masteryTiers)[number]

/** Minimum FSRS stability (days) for an item to count as learned (JourneyViewModel.masteryMinStability). */
export const masteryMinStability = 7

export function mastery(
  lesson: Lesson,
  chart: FidelCharacter[][],
  learnedItemIds: Set<string>,
  recognizedCharIds: Set<string>,
): { tier: MasteryTier; fraction: number } {
  const itemIds = [...lesson.vocabulary.map(wordId), ...lesson.phrases.map((p) => String(p.id))]
  const charIds = charactersInLesson(lesson, chart).map(charId)
  const total = itemIds.length + charIds.length
  if (total === 0) return { tier: 'New', fraction: 0 }
  const learned = itemIds.filter((id) => learnedItemIds.has(id)).length + charIds.filter((id) => recognizedCharIds.has(id)).length
  const fraction = learned / total
  const tier: MasteryTier =
    fraction === 1 ? 'Mastered' : fraction >= 0.8 ? 'Proficient' : fraction >= 0.5 ? 'Familiar' : fraction > 0 ? 'Started' : 'New'
  return { tier, fraction }
}

/** JourneyViewModel.sectionPartition with LearningStage titles. */
export const pathSections = [
  { id: 'script', title: 'Script & Sounds', amharicTitle: 'ፊደል', lessonIds: [] as number[] },
  { id: 'survival', title: 'Survival Phrases', amharicTitle: 'ሰላምታ', lessonIds: [1, 2] },
  { id: 'sentences', title: 'Building Sentences', amharicTitle: 'ዓረፍተ ነገር', lessonIds: [3, 4, 5] },
  { id: 'fluency', title: 'Fluency', amharicTitle: 'ብቃት', lessonIds: [6, 7, 8] },
]
