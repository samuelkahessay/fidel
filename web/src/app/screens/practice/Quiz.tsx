import { useMemo, useState } from 'preact/hooks'
import { type VocabularyWord, wordId } from '../../../content/types'
import { actions, requireContent } from '../../store'
import { Bar, Icon, PlayButton, Result, shuffle, TopBar } from '../../ui'

type Kind = 'multipleChoice' | 'translation' | 'transliteration'
interface Question {
  kind: Kind
  word: VocabularyWord
  prompt: string
  answer: string
  options: string[]
  hint?: string
}

/** QuizMode: the type chooser shown before a quiz. */
const quizModes = [
  { id: 'mixed', title: 'Mixed', detail: 'All question types combined', kinds: ['multipleChoice', 'translation', 'transliteration'] },
  { id: 'multipleChoice', title: 'Multiple Choice', detail: 'Tap the correct answer', kinds: ['multipleChoice'] },
  { id: 'translation', title: 'Type Translation', detail: 'Type the English meaning', kinds: ['translation'] },
  { id: 'transliteration', title: 'Type Pronunciation', detail: "Type how it's pronounced", kinds: ['transliteration'] },
] as const

/** QuizView.generateQuestions: 12 words; "Mixed" cycles through the three question types. */
function generate(vocabulary: VocabularyWord[], kinds: readonly Kind[]): Question[] {
  return shuffle(
    shuffle(vocabulary).slice(0, 12).map((word, i): Question => {
      const kind = kinds[i % kinds.length]!
      if (kind === 'multipleChoice') {
        const wrong = shuffle(vocabulary.filter((w) => w.english !== word.english)).slice(0, 3).map((w) => w.english)
        return { kind, word, prompt: 'What does this word mean?', answer: word.english, options: shuffle([word.english, ...wrong]) }
      }
      if (kind === 'translation') return { kind, word, prompt: 'Type the English meaning:', answer: word.english, options: [] }
      return {
        kind, word, prompt: 'How is this word pronounced? (Type in English letters)',
        answer: word.transliteration.toLowerCase(), options: [], hint: `${word.transliteration.slice(0, 2)}...`,
      }
    }),
  )
}

export function levenshtein(a: string, b: string): number {
  const m = a.length
  const n = b.length
  if (!m) return n
  if (!n) return m
  let prev = Array.from({ length: n + 1 }, (_, j) => j)
  for (let i = 1; i <= m; i++) {
    const row = [i]
    for (let j = 1; j <= n; j++) row[j] = Math.min(prev[j]! + 1, row[j - 1]! + 1, prev[j - 1]! + (a[i - 1] === b[j - 1] ? 0 : 1))
    prev = row
  }
  return prev[n]!
}

/** QuizView.isCloseEnough: allow one typo per four characters. */
export const isCloseEnough = (answer: string, correct: string) =>
  answer === correct || levenshtein(answer, correct) <= Math.max(1, Math.floor(correct.length / 4))

export function Quiz() {
  const content = requireContent()
  const [round, setRound] = useState(0)
  const [mode, setMode] = useState<(typeof quizModes)[number] | null>(null)
  const questions = useMemo(() => (mode ? generate(content.vocabulary, mode.kinds) : []), [round, mode])
  const [index, setIndex] = useState(0)
  const [score, setScore] = useState(0)
  const [chosen, setChosen] = useState<string | null>(null)
  const [typed, setTyped] = useState('')
  const [correct, setCorrect] = useState<boolean | null>(null)

  const restart = () => { setRound(round + 1); setIndex(0); setScore(0); setChosen(null); setTyped(''); setCorrect(null) }
  if (!mode) {
    return (
      <div class="stack">
        <TopBar title="Quiz" />
        <h2 style={{ margin: 0 }}>Choose Quiz Type</h2>
        <div class="list">
          {quizModes.map((m) => (
            <button key={m.id} class="list-item" onClick={() => setMode(m)}>
              <span class="grow"><span class="title">{m.title}</span><br /><span class="sub">{m.detail}</span></span>
              <Icon name="chevron" />
            </button>
          ))}
        </div>
      </div>
    )
  }
  if (index >= questions.length) {
    return (
      <div class="stack">
        <TopBar title="Quiz" />
        <Result title="Quiz complete" detail={`${score} of ${questions.length} correct`} xp={score * 10} onAgain={restart} />
      </div>
    )
  }
  const q = questions[index]!
  const grade = (answer: string) => {
    if (correct !== null) return
    const a = answer.trim().toLowerCase()
    const ok = q.kind === 'multipleChoice' ? a === q.answer.toLowerCase() : isCloseEnough(a, q.answer.toLowerCase())
    setChosen(answer)
    setCorrect(ok)
    if (ok) setScore(score + 1)
  }
  const next = () => {
    if (index === questions.length - 1 && score > 0) actions.addXP(score * 10)
    setIndex(index + 1); setChosen(null); setTyped(''); setCorrect(null)
  }

  return (
    <div class="stack">
      <TopBar title="Quiz"><span class="chip">{index + 1}/{questions.length}</span></TopBar>
      <Bar value={index / questions.length} label="Quiz progress" />
      <div class="card stack" style={{ textAlign: 'center', justifyItems: 'center' }}>
        <p class="secondary" style={{ margin: 0 }}>{q.prompt}</p>
        <div class="amharic-xl" lang="am">{q.word.amharic}</div>
        {q.hint && <p class="muted" style={{ margin: 0 }}>Hint: {q.hint}</p>}
        <PlayButton kind="vocabulary" id={wordId(q.word)} />
      </div>

      {q.kind === 'multipleChoice' ? (
        <div class="options">
          {q.options.map((o) => (
            <button key={o} class="list-item option" disabled={correct !== null} onClick={() => grade(o)}
              data-state={correct !== null && o === q.answer ? 'correct' : chosen === o && !correct ? 'wrong' : undefined}>
              {o}
            </button>
          ))}
        </div>
      ) : (
        <form class="stack" onSubmit={(e) => { e.preventDefault(); grade(typed) }}>
          <label class="visually-hidden" for="quiz-answer">Your answer</label>
          <input id="quiz-answer" class="text" value={typed} onInput={(e) => setTyped(e.currentTarget.value)}
            autoComplete="off" autoCapitalize="off" spellcheck={false} disabled={correct !== null} autoFocus />
          {correct === null && <button class="btn primary" type="submit" disabled={!typed.trim()}>Check</button>}
        </form>
      )}

      {correct !== null && (
        <>
          <div class={`feedback ${correct ? 'good' : 'bad'}`} role="status">
            {correct ? 'Correct!' : `Answer: ${q.kind === 'transliteration' ? q.word.transliteration : q.answer}`}
          </div>
          <button class="btn primary block" onClick={next}>{index === questions.length - 1 ? 'See results' : 'Next'}</button>
        </>
      )}
    </div>
  )
}
