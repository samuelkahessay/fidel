import { href } from '../router'
import { dueVocabulary, progress } from '../store'
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
  { id: 'flashcards', title: 'Flashcards', detail: 'Review vocabulary with spaced repetition', icon: 'stack', tint: 'var(--terracotta-deep)' },
  { id: 'quiz', title: 'Quiz', detail: 'Test your knowledge with multiple choice', icon: 'hint', tint: 'var(--plum)' },
  { id: 'pronunciation', title: 'Pronunciation', detail: 'Listen and practice speaking', icon: 'mic', tint: 'var(--eucalyptus)' },
  { id: 'sentence-builder', title: 'Sentence Builder', detail: 'Build sentences using patterns', icon: 'book', tint: 'var(--gold)' },
  { id: 'word-order', title: 'Word Order', detail: 'Tap word tiles into the right order to translate', icon: 'refresh', tint: 'var(--eucalyptus)' },
  { id: 'cloze', title: 'Fill the Blank', detail: 'Fill in the missing word in a sentence', icon: 'check', tint: 'var(--terracotta)' },
  { id: 'grammar', title: 'Grammar', detail: 'Learn the rules behind the sentences', icon: 'book', tint: 'var(--plum)' },
  { id: 'reading', title: 'Reading', detail: 'Read short passages and check comprehension', icon: 'book', tint: 'var(--terracotta-deep)' },
  { id: 'match', title: 'Match Pairs', detail: 'Match Amharic words to their English meaning', icon: 'sparkles', tint: 'var(--gold)' },
  { id: 'speed-drill', title: 'Speed Drill', detail: 'Rapid-fire translation practice', icon: 'flame', tint: 'var(--red)' },
  { id: 'tracing', title: 'Character Tracing', detail: 'Practice writing Fidel characters', icon: 'hint', tint: 'var(--eucalyptus)' },
]

export function Practice() {
  const due = dueVocabulary.value.length
  const lessons = progress.value.lessonsCompleted.length
  // PracticeView.recommendedSubtitle
  const detail = due
    ? `${due} word${due === 1 ? '' : 's'} due for review. Keep them fresh before moving on.`
    : lessons === 0
      ? 'Start with the words already bundled in Fidel, then come back after your first lesson.'
      : `You have ${lessons} completed lesson${lessons === 1 ? '' : 's'}. Keep those words active before moving on.`
  return (
    <div class="stack">
      <ScreenHeader title="Practice" amharic="ልምምድ"
        subtitle="Short, focused rounds for recall, sound, sentence rhythm, and Fidel muscle memory." />
      <section class="card stack" aria-labelledby="practice-rec">
        <div class="row" style={{ alignItems: 'flex-start' }}>
          <span class="mode-icon large"><Icon name="stack" /></span>
          <div>
            <h2 id="practice-rec" style={{ margin: 0 }}>Recommended review</h2>
            <p class="secondary" style={{ margin: '4px 0 0' }}>{detail}</p>
          </div>
        </div>
        <a class="btn green" href={href('practice', 'flashcards')}>Start flashcards <Icon name="chevron" /></a>
      </section>
      <h2 class="section-label">Modes</h2>
      <div class="list">
        {modes.map((m) => (
          <a key={m.id} class="list-item" href={href('practice', m.id)}>
            <span class="mode-icon" style={{ color: m.tint }}><Icon name={m.icon} /></span>
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
