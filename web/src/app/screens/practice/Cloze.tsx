import { useMemo, useState } from 'preact/hooks'
import type { SentenceExercise } from '../../../content/types'
import { wordClip } from '../../audio'
import { actions, requireContent } from '../../store'
import { Bar, PlayButton, Result, shuffle, TopBar } from '../../ui'

interface Question {
  exercise: SentenceExercise
  blank: number
  answer: string
  options: { amharic: string; transliteration: string }[]
}

/** ClozeViewModel.makeQuestion: blank the middle token, offer up to 4 options. */
export function makeQuestion(exercise: SentenceExercise): Question | null {
  const tokens = exercise.amharicTokens
  if (tokens.length < 2) return null
  const blank = Math.floor(tokens.length / 2)
  const answer = tokens[blank]!
  const options = [{ amharic: answer.amharic, transliteration: answer.transliteration }]
  const add = (o: { amharic: string; transliteration: string }) => {
    if (options.length < 4 && !options.some((x) => x.amharic === o.amharic)) options.push(o)
  }
  exercise.amharicDistractors.forEach(add)
  if (options.length < 2) tokens.filter((t) => t.amharic !== answer.amharic).forEach(add)
  return { exercise, blank, answer: answer.amharic, options: shuffle(options) }
}

export function Cloze() {
  const content = requireContent()
  const [round, setRound] = useState(0)
  const questions = useMemo(
    () => shuffle(content.sentenceExercises.filter((e) => e.amharicTokens.length >= 2)).slice(0, 8).map(makeQuestion).filter((q): q is Question => !!q),
    [round],
  )
  const [index, setIndex] = useState(0)
  const [score, setScore] = useState(0)
  const [chosen, setChosen] = useState<string | null>(null)

  const restart = () => { setRound(round + 1); setIndex(0); setScore(0); setChosen(null) }
  if (index >= questions.length) {
    return (
      <div class="stack">
        <TopBar title="Fill the Blank" />
        <Result title="Nicely done" detail={`${score} of ${questions.length} correct`} xp={score * 10} onAgain={restart} />
      </div>
    )
  }
  const q = questions[index]!
  const correct = chosen !== null && chosen === q.answer
  const next = () => {
    if (index === questions.length - 1 && score > 0) actions.addXP(score * 10)
    setIndex(index + 1); setChosen(null)
  }

  return (
    <div class="stack">
      <TopBar title="Fill the Blank"><span class="chip">{index + 1}/{questions.length}</span></TopBar>
      <Bar value={index / questions.length} label="Progress" />
      <div class="card stack">
        <p class="secondary" style={{ margin: 0 }}>{q.exercise.english}</p>
        <p class="amharic-lg" lang="am" style={{ margin: 0 }}>
          {q.exercise.amharicTokens.map((t, i) => (i === q.blank
            ? <span key={i} style={{ borderBottom: '3px solid var(--terracotta)', padding: '0 12px' }}>{chosen ?? '   '}</span>
            : <span key={i}>{t.amharic}</span>)).reduce<preact.ComponentChild[]>((acc, el, i) => (i ? [...acc, ' ', el] : [el]), [])}
        </p>
      </div>
      <div class="options">
        {q.options.map((o) => (
          <button key={o.amharic} class="list-item option" disabled={chosen !== null}
            onClick={() => { setChosen(o.amharic); if (o.amharic === q.answer) setScore(score + 1) }}
            data-state={chosen !== null && o.amharic === q.answer ? 'correct' : chosen === o.amharic ? 'wrong' : undefined}>
            <span class="grow"><span class="amharic-md" lang="am">{o.amharic}</span><br /><span class="translit">{o.transliteration}</span></span>
          </button>
        ))}
      </div>
      {chosen !== null && (
        <>
          <div class={`feedback ${correct ? 'good' : 'bad'}`} role="status">
            <div class="spread">
              <span>{correct ? 'Correct!' : 'Not quite.'} <span lang="am" class="am">{q.exercise.amharic}</span></span>
              <PlayButton path={wordClip(q.answer)} label="Play the missing word" />
            </div>
            <div class="translit">{q.exercise.transliteration}</div>
          </div>
          <button class="btn primary block" onClick={next}>{index === questions.length - 1 ? 'See results' : 'Next'}</button>
        </>
      )}
    </div>
  )
}
