import { useState } from 'preact/hooks'
import type { Pattern } from '../../../content/types'
import { wordClip } from '../../audio'
import { requireContent } from '../../store'
import { Amharic, PlayButton, TopBar } from '../../ui'

/** GrammarExplainerViewModel.blurbs: English-only summaries keyed by the data's category strings. */
const blurbs: Record<string, string> = {
  'BASIC PRESENT TENSE (Subject + Verb)':
    'Amharic “to be” changes its ending for each subject — I, you (masculine), you (feminine), he, she, we, and they each take a different form. The describing word (an adjective or state) sits in the middle. Compare the endings across the examples to see the pattern.',
  'POSSESSIVE PHRASES':
    'Possession is built with a possessive marker before the noun (“my”, “your”, and so on). Notice how the marker changes with the owner while the noun itself stays the same.',
  'BASIC QUESTIONS':
    'Questions are formed with a question word (who, what, where, when, how much). Word order stays close to a statement — the question word and intonation do the work.',
  'BASIC RESPONSES': 'Short, high-frequency answers — yes, no, agreement, and polite acknowledgements — that keep a conversation moving.',
  'COMMON EXPRESSIONS': 'Fixed everyday expressions for wants, thanks, and social situations. Learn these as whole chunks rather than word by word.',
  'PAST TENSE':
    'The past (perfect) is built on the verb stem with a person ending — a different suffix for I / you / he / she / we / they. Track how the ending shifts per subject in the examples.',
  'FUTURE TENSE':
    'The future/present is built with a subject prefix on the verb plus an auxiliary ending. The prefix marks who does the action; the ending completes the tense.',
  NEGATION:
    'Negation wraps the verb: a marker attaches before it and another after it. The same word turns positive → negative by adding this frame — watch the beginning and end of the verb.',
  'COMMANDS & REQUESTS':
    'Commands change with who you address — masculine, feminine, or plural take different endings — and polite requests add a “please” word. Choose the form that matches the listener.',
  'ABILITY & PREFERENCE':
    'Expressing what you can do, want, or prefer uses helper verbs before or around the main verb. These let you move from stating facts to expressing intentions and choices.',
}
const fallback = 'Study the sentence patterns below. Watch how the Amharic changes across the worked examples.'

/** "BASIC PRESENT TENSE (Subject + Verb)" → "Basic Present Tense". */
export const titleFor = (category: string) =>
  (category.split('(')[0] ?? category).trim().split(' ').map((w) => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase()).join(' ')

export function Grammar() {
  const content = requireContent()
  const groups = new Map<string, Pattern[]>()
  for (const p of content.patterns) groups.set(p.category, [...(groups.get(p.category) ?? []), p])
  const topics = [...groups.entries()]
    .map(([category, patterns]) => ({ category, unit: Math.min(...patterns.map((p) => p.unit)), title: titleFor(category), patterns: patterns.sort((a, b) => a.id.localeCompare(b.id)) }))
    .sort((a, b) => a.unit - b.unit || a.title.localeCompare(b.title))
  const [open, setOpen] = useState<string | null>(null)
  const topic = topics.find((t) => t.category === open)

  if (topic) {
    return (
      <div class="stack">
        <TopBar title={topic.title} />
        <div class="card"><p style={{ margin: 0 }}>{blurbs[topic.category] ?? fallback}</p></div>
        {topic.patterns.map((p) => (
          <section key={p.id} class="card stack">
            <h2 style={{ margin: 0, fontSize: 18 }}>{p.description}</h2>
            <p class="amharic-md" lang="am" style={{ margin: 0 }}>{p.structure}</p>
            {p.examples.map((e) => (
              <div key={e.amharic} class="spread">
                <Amharic text={e.amharic} translit={e.transliteration} english={e.english} size="md" />
                <PlayButton path={wordClip(e.amharic)} />
              </div>
            ))}
          </section>
        ))}
        <button class="btn secondary" onClick={() => setOpen(null)}>All topics</button>
      </div>
    )
  }
  return (
    <div class="stack">
      <TopBar title="Grammar" />
      <div class="list">
        {topics.map((t) => (
          <button key={t.category} class="list-item" onClick={() => setOpen(t.category)}>
            <span class="grow"><span class="title">{t.title}</span><br /><span class="sub">Unit {t.unit} · {t.patterns.length} patterns</span></span>
          </button>
        ))}
      </div>
    </div>
  )
}
