import { href } from '../router'
import { dueVocabulary } from '../store'
import { Empty, Icon, ScreenHeader } from '../ui'
import { Cloze } from './practice/Cloze'
import { Flashcards } from './practice/Flashcards'
import { Grammar } from './practice/Grammar'
import { MatchPairs } from './practice/MatchPairs'
import { Pronunciation } from './practice/Pronunciation'
import { Quiz } from './practice/Quiz'
import { Reading } from './practice/Reading'
import { SentenceBuilder } from './practice/SentenceBuilder'
import { SpeedDrill } from './practice/SpeedDrill'
import { Tracing } from './practice/Tracing'
import { WordOrder } from './practice/WordOrder'

/** PracticeMode in Fidel/Models/Models.swift, in the same order. */
const modes = [
  { id: 'flashcards', title: 'Flashcards', detail: 'Review vocabulary with spaced repetition' },
  { id: 'quiz', title: 'Quiz', detail: 'Test your knowledge with multiple choice' },
  { id: 'pronunciation', title: 'Pronunciation', detail: 'Listen and practice speaking' },
  { id: 'sentence-builder', title: 'Sentence Builder', detail: 'Build sentences using patterns' },
  { id: 'word-order', title: 'Word Order', detail: 'Tap word tiles into the right order to translate' },
  { id: 'cloze', title: 'Fill the Blank', detail: 'Fill in the missing word in a sentence' },
  { id: 'grammar', title: 'Grammar', detail: 'Learn the rules behind the sentences' },
  { id: 'reading', title: 'Reading', detail: 'Read short passages and check comprehension' },
  { id: 'match', title: 'Match Pairs', detail: 'Tap each Amharic word and its meaning' },
  { id: 'speed-drill', title: 'Speed Drill', detail: 'Rapid-fire translation practice' },
  { id: 'tracing', title: 'Character Tracing', detail: 'Trace the Fidel letters stroke by stroke' },
]

export function Practice() {
  const due = dueVocabulary.value.length
  return (
    <div class="stack">
      <ScreenHeader title="Practice" amharic="ልምምድ"
        subtitle={due ? `${due} word${due === 1 ? '' : 's'} due for review.` : 'Pick any drill. Everything is open.'} />
      <div class="list">
        {modes.map((m) => (
          <a key={m.id} class="list-item" href={href('practice', m.id)}>
            <span class="grow"><span class="title">{m.title}</span><br /><span class="sub">{m.detail}</span></span>
            <Icon name="chevron" />
          </a>
        ))}
      </div>
    </div>
  )
}

export function PracticeMode({ mode, arg }: { mode: string; arg?: string }) {
  switch (mode) {
    case 'flashcards': return <Flashcards />
    case 'quiz': return <Quiz />
    case 'pronunciation': return <Pronunciation />
    case 'sentence-builder': return <SentenceBuilder />
    case 'word-order': return <WordOrder />
    case 'cloze': return <Cloze />
    case 'grammar': return <Grammar />
    case 'reading': return <Reading id={arg} />
    case 'match': return <MatchPairs />
    case 'speed-drill': return <SpeedDrill />
    case 'tracing': return <Tracing characterId={arg} />
    default: return <Empty>Unknown practice mode. <a href={href('practice')}>Back to Practice</a></Empty>
  }
}
