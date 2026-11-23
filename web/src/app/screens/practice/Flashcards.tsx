import { useMemo, useState } from 'preact/hooks'
import { type VocabularyWord, wordId } from '../../../content/types'
import { actions, dueVocabulary, requireContent } from '../../store'
import { Icon, PlayButton, Result, shuffle, TopBar } from '../../ui'

/** FlashcardViewModel.startSession: due words first, then the rest shuffled, 20 cards. */
function buildDeck(vocabulary: VocabularyWord[], dueIds: Set<string>, count = 20) {
  const due = vocabulary.filter((w) => dueIds.has(wordId(w)))
  const fill = shuffle(vocabulary.filter((w) => !dueIds.has(wordId(w))))
  return [...due, ...fill].slice(0, count)
}

export function Flashcards() {
  const content = requireContent()
  const [round, setRound] = useState(0)
  const deck = useMemo(() => buildDeck(content.vocabulary, new Set(dueVocabulary.peek().map((c) => c.itemId))), [round])
  const [index, setIndex] = useState(0)
  const [flipped, setFlipped] = useState(false)
  const [correct, setCorrect] = useState(0)

  const restart = () => { setRound(round + 1); setIndex(0); setFlipped(false); setCorrect(0) }
  if (index >= deck.length) {
    return (
      <div class="stack">
        <TopBar title="Flashcards" />
        <Result title="Session complete" detail={`${correct} of ${deck.length} correct`} xp={correct * 5} onAgain={restart} />
      </div>
    )
  }

  const word = deck[index]!
  const rate = (good: boolean) => {
    actions.reviewCard(wordId(word), 'vocabulary', good ? 3 : 1)
    if (good) setCorrect(correct + 1)
    if (index === deck.length - 1 && correct + (good ? 1 : 0) > 0) actions.addXP((correct + (good ? 1 : 0)) * 5)
    setIndex(index + 1)
    setFlipped(false)
  }

  const missed = index - correct
  return (
    <div class="stack">
      <TopBar title="Flashcards" />
      <div class="spread">
        <span class="chip" style={{ color: 'var(--eucalyptus)' }}><Icon name="check" label="Known" /> {correct}</span>
        <strong>{index + 1}/{deck.length}</strong>
        <span class="chip" style={{ color: 'var(--red)' }}>{missed} <Icon name="x" label="Still learning" /></span>
      </div>
      <button class="card flashcard" onClick={() => setFlipped(!flipped)} aria-expanded={flipped}>
        <div class="stack" style={{ justifyItems: 'center' }}>
          <div class="amharic-xl" lang="am" style={{ color: 'var(--terracotta-deep)' }}>{word.amharic}</div>
          <div style={{ fontSize: 20, fontWeight: 600, color: 'var(--ink-secondary)' }}>{word.transliteration}</div>
          {flipped ? (
            <>
              <div style={{ fontSize: 22, fontWeight: 600 }}>{word.english}</div>
              <span class="chip">{word.category}</span>
            </>
          ) : (
            <p class="muted" style={{ margin: '24px 0 0' }}>Tap to flip</p>
          )}
        </div>
      </button>
      <div class="row" style={{ justifyContent: 'center' }}>
        <PlayButton kind="vocabulary" id={wordId(word)} />
      </div>
      {!flipped && <button class="btn primary block" onClick={() => setFlipped(true)}><Icon name="refresh" /> Show Answer</button>}
      <div class="row" style={{ justifyContent: 'center', gap: 32 }}>
        <button class="btn ghost" onClick={() => rate(false)} style={{ flexDirection: 'column', gap: 4 }}>
          <span class="icon-btn" style={{ background: 'var(--red)', color: 'var(--on-accent)' }}><Icon name="x" /></span>Still learning
        </button>
        <button class="btn ghost" onClick={() => rate(true)} style={{ flexDirection: 'column', gap: 4 }}>
          <span class="icon-btn" style={{ background: 'var(--eucalyptus)', color: 'var(--on-accent)' }}><Icon name="check" /></span>Got it!
        </button>
      </div>
    </div>
  )
}
