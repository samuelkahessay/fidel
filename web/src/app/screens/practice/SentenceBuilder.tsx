import { useState } from 'preact/hooks'
import type { Example, Pattern } from '../../../content/types'
import { wordClip } from '../../audio'
import { requireContent } from '../../store'
import { Amharic, Icon, PlayButton, TopBar } from '../../ui'

/** SentenceBuilderView.buildSentence: substitute the slot in the pattern structure and description. */
export function buildSentence(pattern: Pattern, sub: Example) {
  let amharic = pattern.structure
  let english = pattern.description
  if (amharic.includes('[adjective]')) {
    amharic = amharic.replaceAll('[adjective]', sub.amharic)
    english = english.replaceAll('[adjective/state]', sub.english).replaceAll('[adjective]', sub.english)
  }
  if (amharic.includes('[noun]')) {
    amharic = amharic.replaceAll('[noun]', sub.amharic)
    english = english.replaceAll('[noun]', sub.english)
  }
  return { amharic, transliteration: sub.transliteration, english }
}

export function SentenceBuilder() {
  const content = requireContent()
  const patterns = content.patterns.filter((p) => p.substitutions.length > 0)
  const [pattern, setPattern] = useState<Pattern | null>(null)
  const [sub, setSub] = useState<Example | null>(null)

  if (!pattern) {
    return (
      <div class="stack">
        <TopBar title="Sentence Builder" />
        <p class="secondary" style={{ margin: 0 }}>Pick a pattern, then swap words into it.</p>
        <div class="list">
          {patterns.map((p) => (
            <button key={p.id} class="list-item" onClick={() => { setPattern(p); setSub(null) }}>
              <span class="grow"><span class="title">{p.description}</span><br /><span class="sub am" lang="am">{p.structure}</span></span>
              <Icon name="chevron" />
            </button>
          ))}
        </div>
      </div>
    )
  }

  const built = sub ? buildSentence(pattern, sub) : null
  return (
    <div class="stack">
      <div class="topbar">
        <button class="icon-btn" onClick={() => setPattern(null)} aria-label="Back to patterns"><Icon name="back" /></button>
        <h1>Sentence Builder</h1>
      </div>
      <div class="card stack">
        <p class="muted" style={{ margin: 0 }}>{pattern.category}</p>
        <p style={{ margin: 0, fontWeight: 600 }}>{pattern.description}</p>
        <p class="amharic-md" lang="am" style={{ margin: 0 }}>{pattern.structure}</p>
      </div>
      <h2 class="section-label">Choose a word</h2>
      <div class="row" style={{ flexWrap: 'wrap', gap: 8 }}>
        {pattern.substitutions.map((s) => (
          <button key={s.amharic} class="word-tile" lang="am" aria-pressed={sub?.amharic === s.amharic}
            data-state={sub?.amharic === s.amharic ? 'selected' : undefined} onClick={() => setSub(sub?.amharic === s.amharic ? null : s)}>
            {s.amharic} <small style={{ fontFamily: 'var(--font)', color: 'var(--ink-muted)' }}>{s.english}</small>
          </button>
        ))}
      </div>
      {built && (
        <div class="card spread" role="status">
          <Amharic text={built.amharic} translit={built.transliteration} english={built.english} />
          <PlayButton path={wordClip(sub!.amharic)} label="Play the chosen word" />
        </div>
      )}
      <h2 class="section-label">Examples</h2>
      <div class="list">
        {pattern.examples.slice(0, 3).map((e) => (
          <div key={e.amharic} class="list-item">
            <span class="grow"><Amharic text={e.amharic} translit={e.transliteration} english={e.english} size="md" /></span>
            <PlayButton path={wordClip(e.amharic)} />
          </div>
        ))}
      </div>
    </div>
  )
}
