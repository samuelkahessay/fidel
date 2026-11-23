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
  const [shown, setShown] = useState(1)
  const [roleplay, setRoleplay] = useState<string | null>(null)
  const [revealed, setRevealed] = useState<Set<number>>(new Set())
  const [done, setDone] = useState(false)
  if (!conversation) return <Empty>That conversation doesn't exist.</Empty>

  const speakers = [...new Set(conversation.lines.map((l) => l.speaker))]
  const lines = conversation.lines.slice(0, shown)
  const finished = shown >= conversation.lines.length

  return (
    <div class="stack">
      <TopBar title={conversation.title} />
      <div class="segmented" role="group" aria-label="Role-play">
        <button aria-selected={roleplay === null} onClick={() => setRoleplay(null)}>Read along</button>
        {speakers.map((s) => (
          <button key={s} aria-selected={roleplay === s} onClick={() => { setRoleplay(s); setRevealed(new Set()) }}>Be {s}</button>
        ))}
      </div>
      <div class="stack" style={{ gap: 10 }} aria-live="polite">
        {lines.map((l, i) => {
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
              {i === lines.length - 1 && <span class="visually-hidden">Line {i + 1} of {conversation.lines.length}</span>}
            </div>
          )
        })}
      </div>
      {!finished && <button class="btn primary block" onClick={() => setShown(shown + 1)}>Next line</button>}
      {finished && !done && (
        <button class="btn primary block" onClick={() => { actions.practiceConversation(conversation.id); setDone(true) }}>
          Finish conversation
        </button>
      )}
      {done && <div class="feedback good" role="status">Conversation practiced! +20 XP the first time.</div>}
    </div>
  )
}
