import { useState } from 'preact/hooks'
import { wordClip } from '../../audio'
import { href, navigate } from '../../router'
import { requireContent } from '../../store'
import { Empty, Icon, PlayButton, TopBar } from '../../ui'

export function Reading({ id }: { id?: string }) {
  const content = requireContent()
  const passage = content.readingPassages.find((p) => p.id === id)
  const [showEnglish, setShowEnglish] = useState(false)
  const [answers, setAnswers] = useState<Record<number, number>>({})

  if (!id) {
    return (
      <div class="stack">
        <TopBar title="Reading" />
        <div class="list">
          {content.readingPassages.map((p) => (
            <a key={p.id} class="list-item" href={href('practice', 'reading', p.id)}>
              <span class="grow"><span class="title">{p.title}</span><br /><span class="sub">{p.cefr} · {p.sentences.length} sentences</span></span>
              <Icon name="chevron" />
            </a>
          ))}
        </div>
      </div>
    )
  }
  if (!passage) return <Empty>That passage doesn't exist. <a href={href('practice', 'reading')}>All passages</a></Empty>

  const answered = Object.keys(answers).length
  const correct = passage.questions.filter((q, i) => answers[i] === q.answerIndex).length
  return (
    <div class="stack">
      <TopBar title={passage.title}><span class="chip">{passage.cefr}</span></TopBar>
      <label class="row" style={{ gap: 8 }}>
        <input type="checkbox" checked={showEnglish} onChange={(e) => setShowEnglish(e.currentTarget.checked)} />
        Show translation
      </label>
      <article class="card stack">
        {passage.sentences.map((s) => (
          <div key={s.amharic} class="spread" style={{ alignItems: 'flex-start' }}>
            <div>
              <div class="amharic-md" lang="am">{s.amharic}</div>
              <div class="translit">{s.transliteration}</div>
              {showEnglish && <div class="secondary">{s.english}</div>}
            </div>
            <PlayButton path={wordClip(s.amharic)} />
          </div>
        ))}
      </article>
      <details class="card">
        <summary>Glossary ({passage.glossary.length})</summary>
        <dl style={{ display: 'grid', gridTemplateColumns: 'auto 1fr', gap: '6px 16px', margin: '12px 0 0' }}>
          {passage.glossary.map((g) => (
            <>
              <dt key={`${g.amharic}-t`} class="am" lang="am">{g.amharic}</dt>
              <dd key={`${g.amharic}-d`} style={{ margin: 0 }}>{g.english}</dd>
            </>
          ))}
        </dl>
      </details>
      <h2 class="section-label">Check your understanding</h2>
      {passage.questions.map((q, i) => (
        <fieldset key={q.question} class="card stack" style={{ border: 0 }}>
          <legend style={{ fontWeight: 600, padding: 0 }}>{q.question}</legend>
          <div class="options">
            {q.options.map((o, k) => (
              <button key={o} class="list-item option" disabled={answers[i] !== undefined}
                onClick={() => setAnswers({ ...answers, [i]: k })}
                data-state={answers[i] !== undefined && k === q.answerIndex ? 'correct' : answers[i] === k ? 'wrong' : undefined}>
                {o}
              </button>
            ))}
          </div>
        </fieldset>
      ))}
      {answered === passage.questions.length && (
        <div class="feedback good" role="status">
          {correct} of {passage.questions.length} correct.{' '}
          <button class="btn ghost" onClick={() => navigate('practice', 'reading')}>Another passage</button>
        </div>
      )}
    </div>
  )
}
