import { useMemo, useState } from 'preact/hooks'
import type { SentenceExercise } from '../../../content/types'
import { wordClip } from '../../audio'
import { actions, requireContent } from '../../store'
import { Bar, PlayButton, Result, shuffle, TopBar } from '../../ui'

interface Tile { key: string; text: string; translit?: string }
interface Question { exercise: SentenceExercise; toAmharic: boolean; answer: string[]; bank: Tile[] }

/** WordOrderViewModel.makeQuestion: alternate English→Amharic and Amharic→English. */
function makeQuestion(exercise: SentenceExercise, toAmharic: boolean): Question {
  const tiles = toAmharic
    ? [...exercise.amharicTokens, ...exercise.amharicDistractors].map((t, i) => ({ key: `${i}`, text: t.amharic, translit: t.transliteration }))
    : [...exercise.englishTokens, ...exercise.englishDistractors].map((t, i) => ({ key: `${i}`, text: t }))
  return { exercise, toAmharic, answer: toAmharic ? exercise.amharicTokens.map((t) => t.amharic) : exercise.englishTokens, bank: shuffle(tiles) }
}
const norm = (s: string) => s.trim().toLowerCase()

export function WordOrder() {
  const content = requireContent()
  const [round, setRound] = useState(0)
  const questions = useMemo(() => shuffle(content.sentenceExercises).slice(0, 8).map((e, i) => makeQuestion(e, i % 2 === 0)), [round])
  const [index, setIndex] = useState(0)
  const [placed, setPlaced] = useState<Tile[]>([])
  const [score, setScore] = useState(0)
  const [checked, setChecked] = useState<boolean | null>(null)

  const restart = () => { setRound(round + 1); setIndex(0); setPlaced([]); setScore(0); setChecked(null) }
  if (index >= questions.length) {
    return (
      <div class="stack">
        <TopBar title="Word Order" />
        <Result title="Sentences built" detail={`${score} of ${questions.length} correct`} xp={score * 10} onAgain={restart} />
      </div>
    )
  }
  const q = questions[index]!
  const bank = q.bank.filter((t) => !placed.includes(t))
  const check = () => {
    const ok = placed.map((t) => norm(t.text)).join(' ') === q.answer.map(norm).join(' ')
    setChecked(ok)
    if (ok) setScore(score + 1)
  }
  const next = () => {
    if (index === questions.length - 1 && score > 0) actions.addXP(score * 10)
    setIndex(index + 1); setPlaced([]); setChecked(null)
  }
  const tileStyle = q.toAmharic ? undefined : { fontFamily: 'var(--font)', fontSize: 16 }

  return (
    <div class="stack">
      <TopBar title="Word Order"><span class="chip">{index + 1}/{questions.length}</span></TopBar>
      <Bar value={index / questions.length} label="Progress" />
      <div class="card stack">
        <p class="muted" style={{ margin: 0 }}>{q.toAmharic ? 'Translate into Amharic' : 'Translate into English'}</p>
        {q.toAmharic ? (
          <p style={{ margin: 0, fontSize: 20, fontWeight: 600 }}>{q.exercise.english}</p>
        ) : (
          <div class="spread">
            <div><div class="amharic-lg" lang="am">{q.exercise.amharic}</div><div class="translit">{q.exercise.transliteration}</div></div>
            <PlayButton path={wordClip(q.exercise.amharic)} />
          </div>
        )}
      </div>
      <div class="tile-bank" role="group" aria-label="Your answer" aria-live="polite">
        {placed.map((t) => (
          <button key={t.key} class="word-tile" lang={q.toAmharic ? 'am' : undefined} style={tileStyle} disabled={checked !== null}
            onClick={() => setPlaced(placed.filter((x) => x !== t))}>{t.text}</button>
        ))}
      </div>
      <div class="row" style={{ flexWrap: 'wrap', gap: 8 }} role="group" aria-label="Word bank">
        {bank.map((t) => (
          <button key={t.key} class="word-tile" lang={q.toAmharic ? 'am' : undefined} style={tileStyle} disabled={checked !== null}
            onClick={() => setPlaced([...placed, t])}>{t.text}</button>
        ))}
      </div>
      {checked === null ? (
        <button class="btn primary block" disabled={!placed.length} onClick={check}>Check</button>
      ) : (
        <>
          <div class={`feedback ${checked ? 'good' : 'bad'}`} role="status">
            {checked ? 'Correct!' : 'Correct answer:'} <span lang={q.toAmharic ? 'am' : undefined}>{q.toAmharic ? q.exercise.amharic : q.exercise.english}</span>
          </div>
          <button class="btn primary block" onClick={next}>{index === questions.length - 1 ? 'See results' : 'Next'}</button>
        </>
      )}
    </div>
  )
}
