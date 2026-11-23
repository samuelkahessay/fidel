import { useMemo, useState } from 'preact/hooks'
import { charId, wordId } from '../../content/types'
import { playContent } from '../audio'
import { href, navigate } from '../router'
import { actions, recognizedCharIds, requireContent } from '../store'
import { Amharic, Icon, PlayButton, ScreenHeader } from '../ui'

const tabs = [
  { id: 'fidel', label: 'Fidel' },
  { id: 'phrases', label: 'Quick Phrases' },
  { id: 'vocabulary', label: 'Vocabulary' },
  { id: 'culture', label: 'Culture' },
  { id: 'numbers', label: 'Numbers' },
]

export function Reference({ tab = 'fidel' }: { tab?: string }) {
  const [query, setQuery] = useState('')
  return (
    <div class="stack">
      <ScreenHeader title="Reference" amharic="መዝገብ" subtitle="Phrasebook, words, cultural notes, and numbers for quick lookup." />
      <div class="segmented" role="tablist" aria-label="Reference sections">
        {tabs.map((t) => (
          <button key={t.id} role="tab" aria-selected={tab === t.id} onClick={() => navigate('reference', t.id)}>{t.label}</button>
        ))}
      </div>
      {(tab === 'phrases' || tab === 'vocabulary') && (
        <>
          <label class="visually-hidden" for="ref-search">Search</label>
          <input id="ref-search" class="text" type="search" placeholder="Search in English, Amharic or transliteration"
            value={query} onInput={(e) => setQuery(e.currentTarget.value)} />
        </>
      )}
      {tab === 'fidel' && <Chart />}
      {tab === 'phrases' && <Phrases query={query} />}
      {tab === 'vocabulary' && <Vocabulary query={query} />}
      {tab === 'numbers' && <Numbers />}
      {tab === 'culture' && <Culture />}
    </div>
  )
}

const matches = (q: string, ...fields: string[]) => {
  const needle = q.trim().toLowerCase()
  return !needle || fields.some((f) => f.toLowerCase().includes(needle))
}

function Chart() {
  const content = requireContent()
  const known = recognizedCharIds.value
  return (
    <>
      <p class="secondary" style={{ margin: 0 }}>34 consonants × 7 vowel forms. Tap to hear a character; trace it from the button below.</p>
      <div class="chart" role="grid" aria-label="Fidel chart">
        {content.fidelChart.map((row) => (
          <div key={row[0]!.rowIndex} role="row" style={{ display: 'contents' }}>
            {row.map((c) => (
              <button key={charId(c)} role="gridcell" data-known={known.has(charId(c))}
                onClick={() => { void playContent('fidelCharacter', charId(c)); actions.recognizeCharacter(charId(c)) }}
                onDblClick={() => navigate('practice', 'tracing', charId(c))}>
                <span class="glyph" lang="am">{c.character}</span>{' '}
                <span class="roman">{c.romanization}</span>
              </button>
            ))}
          </div>
        ))}
      </div>
      <a class="btn secondary block" href={href('practice', 'tracing')}><Icon name="hint" /> Trace the letters</a>
    </>
  )
}

function Phrases({ query }: { query: string }) {
  const content = requireContent()
  const list = content.phrases.filter((p) => matches(query, p.english, p.amharic, p.transliteration))
  return (
    <div class="list">
      <p class="muted" style={{ margin: 0 }}>{list.length} phrases</p>
      {list.slice(0, 200).map((p) => (
        <div key={p.id} class="list-item">
          <span class="grow">
            <Amharic text={p.amharic} translit={p.transliteration} english={p.english} size="md" />
            {p.notes && <div class="muted" style={{ fontSize: 14 }}>{p.notes}</div>}
          </span>
          <PlayButton kind="phrase" id={String(p.id)} />
        </div>
      ))}
      {list.length > 200 && <p class="muted">Showing 200 of {list.length}. Search to narrow down.</p>}
    </div>
  )
}

function Vocabulary({ query }: { query: string }) {
  const content = requireContent()
  const [category, setCategory] = useState<string>('All')
  const list = useMemo(
    () => content.vocabulary.filter((w) => (category === 'All' || w.category === category) && matches(query, w.english, w.amharic, w.transliteration)),
    [query, category],
  )
  return (
    <div class="list">
      <label class="row">
        <span class="secondary">Category</span>
        <select class="text" style={{ flex: 1 }} value={category} onChange={(e) => setCategory(e.currentTarget.value)}>
          <option>All</option>
          {content.vocabularyCategories.map((c) => <option key={c}>{c}</option>)}
        </select>
      </label>
      <p class="muted" style={{ margin: 0 }}>{list.length} words</p>
      {list.slice(0, 200).map((w) => (
        <div key={wordId(w)} class="list-item">
          <span class="grow"><Amharic text={w.amharic} translit={w.transliteration} english={w.english} size="md" /></span>
          <PlayButton kind="vocabulary" id={wordId(w)} />
        </div>
      ))}
      {list.length > 200 && <p class="muted">Showing 200 of {list.length}. Search or pick a category to narrow down.</p>}
    </div>
  )
}

function Numbers() {
  const { numbers } = requireContent()
  const section = (title: string, rows: { key: string; left: string; amharic: string; translit: string }[]) => (
    <section>
      <h2 class="section-label">{title}</h2>
      <div class="list">
        {rows.map((r) => (
          <div key={r.key} class="list-item">
            <strong style={{ minWidth: 72 }}>{r.left}</strong>
            <span class="grow"><span class="amharic-md" lang="am">{r.amharic}</span> <span class="translit">{r.translit}</span></span>
          </div>
        ))}
      </div>
    </section>
  )
  return (
    <>
      {section('Numbers', numbers.numbers.map((n) => ({ key: `n${n.value}`, left: n.value.toLocaleString(), amharic: n.amharic, translit: n.transliteration })))}
      {section('Ethiopian months', numbers.months.map((m) => ({ key: `m${m.month}`, left: m.gregorian, amharic: m.amharic, translit: m.transliteration })))}
      {section('Ordinals', numbers.ordinals.map((o) => ({ key: `o${o.value}`, left: `#${o.value}`, amharic: o.amharic, translit: o.transliteration })))}
      {section('Fractions', numbers.fractions.map((f) => ({ key: `f${f.english}`, left: f.english, amharic: f.amharic, translit: f.transliteration })))}
    </>
  )
}

function Culture() {
  const content = requireContent()
  return (
    <div class="list">
      {content.culturalNotes.map((n) => (
        <details key={n.id} class="card">
          <summary>{n.title} <span lang="am" class="am muted">{n.amharicTitle}</span></summary>
          <p style={{ marginBottom: 0 }}>{n.content}</p>
        </details>
      ))}
    </div>
  )
}
