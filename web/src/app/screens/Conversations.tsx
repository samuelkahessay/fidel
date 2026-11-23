import { useState } from 'preact/hooks'
import { href } from '../router'
import { actions, progress, requireContent } from '../store'
import { Empty, Icon, PlayButton, TopBar } from '../ui'

export function Conversations() {
  const content = requireContent()
  const practiced = new Set(progress.value.conversationsPracticed)
  return (
    <div class="stack">
      <TopBar title="Conversations" />
      <div class="list">
        {content.conversations.map((c) => (
          <a key={c.id} class="list-item" href={href('conversation', c.id)}>
            <span class="grow">
              <span class="title">{c.title}</span><br />
              <span class="sub">{c.lines.length} lines · {'●'.repeat(c.difficulty)}{practiced.has(c.id) ? ' · Practiced' : ''}</span>
            </span>
            <Icon name="chevron" />
          </a>
        ))}
      </div>
    </div>
  )
}

export function ConversationDetail({ id }: { id: number }) {
  const content = requireContent()
  const conversation = content.conversations.find((c) => c.id === id)
  const [roleplay, setRoleplay] = useState<string | null>(null)
  const [revealed, setRevealed] = useState<Set<number>>(new Set())
  const [done, setDone] = useState(false)
  if (!conversation) return <Empty>That conversation doesn't exist.</Empty>

  const speakers = [...new Set(conversation.lines.map((l) => l.speaker))]
  const lines = conversation.lines
  const notes = content.culturalNotes.filter((n) => n.conversationIds.includes(conversation.id))
  const level = ['Beginner', 'Intermediate', 'Advanced'][conversation.difficulty - 1] ?? 'Beginner'

  return (
    <div class="stack">
      <TopBar title={conversation.title} />
      <div class="card spread">
        <span><span style={{ color: 'var(--eucalyptus)' }}>{'★'.repeat(conversation.difficulty)}</span><span class="muted">{'☆'.repeat(3 - conversation.difficulty)}</span> {level}</span>
        <span class="muted">{lines.length} lines</span>
      </div>
      {notes.map((n) => (
        <details key={n.id} class="card" style={{ background: 'color-mix(in srgb, var(--gold) 14%, var(--card))' }}>
          <summary><span class="secondary" style={{ fontSize: 13 }}>Cultural Context</span><br />{n.title}</summary>
          <p style={{ marginBottom: 0 }}>{n.content}</p>
        </details>
      ))}
      <div class="segmented" role="group" aria-label="Role-play">
        <button aria-pressed={roleplay === null} onClick={() => setRoleplay(null)}>Read along</button>
        {speakers.map((s) => (
          <button key={s} aria-pressed={roleplay === s} onClick={() => { setRoleplay(s); setRevealed(new Set()) }}>Be {s}</button>
        ))}
      </div>
      <div class="stack" style={{ gap: 10 }} aria-live="polite">
        {lines.map((l) => {
          const hidden = roleplay === l.speaker && !revealed.has(l.lineNum)
          return (
            <div key={l.lineNum} class={`conversation-line ${speakers.indexOf(l.speaker) % 2 ? 'right' : ''}`}>
              <div class="spread">
                <strong>{l.speaker}</strong>
                <PlayButton kind="conversationLine" id={`${conversation.id}-${l.lineNum}`} />
              </div>
              {hidden ? (
                <>
                  <div class="secondary">{l.english}</div>
                  <button class="btn ghost" onClick={() => setRevealed(new Set(revealed).add(l.lineNum))}>Say it, then reveal</button>
                </>
              ) : (
                <>
                  <div class="amharic-md" lang="am">{l.amharic}</div>
                  <div class="translit">{l.transliteration}</div>
                  <div class="secondary">{l.english}</div>
                </>
              )}
            </div>
          )
        })}
      </div>
      {!done && (
        <button class="btn primary block" onClick={() => { actions.practiceConversation(conversation.id); setDone(true) }}>
          Finish conversation
        </button>
      )}
      {done && <div class="feedback good" role="status">Conversation practiced! +20 XP the first time.</div>}
    </div>
  )
}
