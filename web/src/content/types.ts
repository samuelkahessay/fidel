// Shapes of the JSON in Fidel/Data. Field names match the Swift Codable models.

export interface FidelCharacter {
  character: string
  consonant: string
  rowIndex: number
  vowelOrder: number
  romanization: string
  audioHint: string
}

export interface Example {
  amharic: string
  transliteration: string
  english: string
}

export interface Pattern {
  id: string
  category: string
  unit: number
  description: string
  structure: string
  template: string
  examples: Example[]
  substitutions: Example[]
}

export interface VocabularyWord {
  category: string
  amharic: string
  transliteration: string
  english: string
}

export interface Phrase {
  id: number
  amharic: string
  transliteration: string
  english: string
  notes: string
}

export interface ConversationLine {
  lineNum: number
  speaker: string
  amharic: string
  transliteration: string
  english: string
}

export interface Conversation {
  id: number
  title: string
  difficulty: number
  lines: ConversationLine[]
}

export interface CulturalNote {
  id: string
  title: string
  amharicTitle: string
  content: string
  icon: string
  lessonIds: number[]
  conversationIds: number[]
}

export interface ReadingPassage {
  id: string
  title: string
  cefr: string
  sentences: Example[]
  glossary: { amharic: string; english: string }[]
  questions: { question: string; options: string[]; answerIndex: number }[]
}

export interface SentenceExercise {
  id: string
  unit: number
  english: string
  amharic: string
  transliteration: string
  amharicTokens: Example[]
  englishTokens: string[]
  amharicDistractors: Example[]
  englishDistractors: string[]
}

export interface NumericReference {
  numbers: { value: number; amharic: string; transliteration: string }[]
  months: { month: number; amharic: string; transliteration: string; gregorian: string }[]
  ordinals: { value: number; amharic: string; transliteration: string }[]
  fractions: Example[]
}

/** What `build/content.ts` serves as content.json. */
export interface RawContent {
  fidelChart: FidelCharacter[]
  patterns: Pattern[]
  vocabulary: VocabularyWord[]
  phrases: Phrase[]
  conversations: Conversation[]
  culturalNotes: CulturalNote[]
  readingPassages: ReadingPassage[]
  sentenceExercises: SentenceExercise[]
  numbers: NumericReference
  /** `${contentType}:${contentId}` → path under audio/ */
  audio: Record<string, string>
}

export interface Lesson {
  id: number
  title: string
  description: string
  patterns: Pattern[]
  vocabulary: VocabularyWord[]
  phrases: Phrase[]
}

/** `VocabularyWord.id` in Swift. */
export const wordId = (word: VocabularyWord) => `${word.category}-${word.amharic}`
/** `FidelCharacter.id` in Swift. */
export const charId = (c: Pick<FidelCharacter, 'rowIndex' | 'vowelOrder'>) => `${c.rowIndex}-${c.vowelOrder}`
