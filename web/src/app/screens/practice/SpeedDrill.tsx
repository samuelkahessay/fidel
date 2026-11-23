import { useEffect, useMemo, useState } from 'preact/hooks'
import { actions, requireContent } from '../../store'
import { Amharic, Icon, PlayButton, Result, shuffle, TopBar } from '../../ui'

const seconds = 60

/** SpeedDrillView: 20 random phrases, 60 seconds, self-graded; 5 XP per correct answer. */
export function SpeedDrill() {
  const content = requireContent()
  const [round, setRound] = useState(0)
  const phrases = useMemo(() => shuffle(content.phrases).slice(0, 20), [round])
  const [index, setIndex] = useState(0)
  const [score, setScore] = useState(0)
  const [left, setLeft] = useState(seconds)
  const [shown, setShown] = useState(false)
  const over = left <= 0 || index >= phrases.length

  useEffect(() => {
    if (over) return
    const t = setInterval(() => setLeft((s) => s - 1), 1000)
    return () => clearInterval(t)
  }, [over, round])
  useEffect(() => {
    if (over && score > 0) actions.addXP(score * 5)
  }, [over])

  const restart = () => { setRound(round + 1); setIndex(0); setScore(0); setLeft(seconds); setShown(false) }
  if (over) {
    return (
      <div class="stack">
        <TopBar title="Speed Drill" />
        <Result title="Time's up!" detail={`Final score: ${score}/${phrases.length}`} xp={score * 5} onAgain={restart} />
      </div>
    )
  }
  const phrase = phrases[index]!
  const next = (gotIt: boolean) => { if (gotIt) setScore(score + 1); setIndex(index + 1); setShown(false) }

  return (
    <div class="stack">
      <TopBar title="Speed Drill">
        <span class="chip accent" role="timer" aria-label={`${left} seconds left`}>{left}s</span>
      </TopBar>
      <p class="secondary" style={{ margin: 0 }}>Score {score} · {index}/{phrases.length}</p>
      <div class="card stack" style={{ textAlign: 'center', justifyItems: 'center', minHeight: 220, alignContent: 'center' }}>
        <p class="muted" style={{ margin: 0 }}>Translate to Amharic:</p>
        <p style={{ margin: 0, fontSize: 24, fontWeight: 600 }}>{phrase.english}</p>
        {shown && (
          <div class="row">
            <Amharic text={phrase.amharic} translit={phrase.transliteration} />
            <PlayButton kind="phrase" id={String(phrase.id)} />
          </div>
        )}
      </div>
      <div class="grid-3" style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 8 }}>
        <button class="btn secondary" onClick={() => setShown(true)} disabled={shown}><Icon name="eye" /> Show</button>
        <button class="btn primary" onClick={() => next(true)}><Icon name="check" /> Correct</button>
        <button class="btn secondary" onClick={() => next(false)}>Skip</button>
      </div>
    </div>
  )
}
