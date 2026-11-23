import type { FidelCharacter, Lesson, Phrase, RawContent, VocabularyWord } from './types'

export interface Content extends Omit<RawContent, 'fidelChart'> {
  /** Rows of 7 vowel forms, ordered by rowIndex then vowelOrder (AmharicDataLoader.fidelChart). */
  fidelChart: FidelCharacter[][]
  lessons: Lesson[]
  vocabularyCategories: string[]
}

export function groupChart(flat: FidelCharacter[]): FidelCharacter[][] {
  const rows = new Map<number, FidelCharacter[]>()
  for (const c of flat) rows.set(c.rowIndex, [...(rows.get(c.rowIndex) ?? []), c])
  return [...rows.keys()].sort((a, b) => a - b).map((k) => rows.get(k)!.sort((a, b) => a.vowelOrder - b.vowelOrder))
}

const inCategories = (words: VocabularyWord[], categories: string[]) => words.filter((w) => categories.includes(w.category))
const phraseRange = (phrases: Phrase[], ...ranges: [number, number][]) =>
  phrases.filter((p) => ranges.some(([lo, hi]) => p.id >= lo && p.id <= hi))

/** Mirrors `AmharicData.lessons` exactly; checked by the lesson-composition golden fixture. */
export function buildLessons(raw: Pick<RawContent, 'patterns' | 'vocabulary' | 'phrases'>): Lesson[] {
  const { patterns, vocabulary: v, phrases: p } = raw
  const units = (...u: number[]) => patterns.filter((x) => u.includes(x.unit))
  return [
    { id: 1, title: 'Greetings & Introductions', description: 'Learn basic greetings and how to introduce yourself',
      patterns: units(1), vocabulary: inCategories(v, ['Family', 'Common Adjectives']), phrases: p.slice(0, 15) },
    { id: 2, title: 'Possessives & Family', description: 'Talk about your family and possessions',
      patterns: units(2), vocabulary: inCategories(v, ['Family']), phrases: phraseRange(p, [16, 25]) },
    { id: 3, title: 'Questions & Directions', description: 'Ask questions and find your way around',
      patterns: units(3), vocabulary: inCategories(v, ['Directions', 'Places']), phrases: phraseRange(p, [20, 30]) },
    { id: 4, title: 'Food & Shopping', description: 'Order food, shop at markets, and handle money',
      patterns: units(4, 5), vocabulary: inCategories(v, ['Food & Drink']), phrases: phraseRange(p, [31, 40]) },
    { id: 5, title: 'Making Plans & Time', description: 'Talk about time, make plans, and schedule activities',
      patterns: units(5), vocabulary: inCategories(v, ['Time', 'Days']), phrases: phraseRange(p, [41, 50]) },
    { id: 6, title: 'Health & Body', description: 'Describe symptoms, visit the doctor, and discuss health',
      patterns: units(6, 7), vocabulary: inCategories(v, ['Body Parts', 'Emotions', 'Occupations']), phrases: phraseRange(p, [59, 65]) },
    { id: 7, title: 'Travel & Transportation', description: 'Navigate airports, take taxis, and travel around Ethiopia',
      patterns: units(8, 9), vocabulary: inCategories(v, ['Transportation', 'Clothing', 'Weather & Nature']),
      phrases: phraseRange(p, [51, 58], [81, 85]) },
    { id: 8, title: 'Ethiopian Culture & Celebrations', description: 'Experience holidays, ceremonies, and cultural traditions',
      patterns: units(10), vocabulary: inCategories(v, ['Household', 'Animals', 'Food & Drink']),
      phrases: phraseRange(p, [71, 80], [86, 90]) },
  ]
}

export function buildContent(raw: RawContent): Content {
  return {
    ...raw,
    fidelChart: groupChart(raw.fidelChart),
    lessons: buildLessons(raw),
    vocabularyCategories: [...new Set(raw.vocabulary.map((w) => w.category))].sort(),
  }
}

export async function loadContent(base = import.meta.env.BASE_URL): Promise<Content> {
  const response = await fetch(`${base}content.json`)
  if (!response.ok) throw new Error(`content.json: HTTP ${response.status}`)
  return buildContent((await response.json()) as RawContent)
}
