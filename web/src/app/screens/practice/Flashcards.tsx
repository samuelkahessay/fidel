import { useMemo, useState } from 'preact/hooks'
import { type VocabularyWord, wordId } from '../../../content/types'
import { actions, dueVocabulary, requireContent } from '../../store'
import { Bar, Icon, PlayButton, Result, shuffle, TopBar } from '../../ui'

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

  return (
    <div class="stack">
      <TopBar title="Flashcards"><span class="chip">{index + 1}/{deck.length}</span></TopBar>
      <Bar value={index / deck.length} label="Session progress" />
      <button class="card flashcard" onClick={() => setFlipped(!flipped)} aria-expanded={flipped}>
        <div class="stack" style={{ justifyItems: 'center' }}>
          <div class="amharic-xl" lang="am">{word.amharic}</div>
          {flipped ? (
            <>
              <div class="translit" style={{ fontSize: 20 }}>{word.transliteration}</div>
              <div style={{ fontSize: 22, fontWeight: 600 }}>{word.english}</div>
              <span class="chip">{word.category}</span>
            </>
          ) : (
            <p class="muted">Tap to reveal</p>
          )}
        </div>
      </button>
      <div class="row" style={{ justifyContent: 'center' }}>
        <PlayButton kind="vocabulary" id={wordId(word)} />
      </div>
      {flipped && (
        <div class="grid-2">
          <button class="btn secondary" onClick={() => rate(false)}><Icon name="x" /> Still learning</button>
          <button class="btn primary" onClick={() => rate(true)}><Icon name="check" /> I knew it</button>
        </div>
      )}
    </div>
  )
}
