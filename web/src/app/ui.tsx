import type { ComponentChildren, JSX } from 'preact'
import { type AudioKind, clipPath, play, playing } from './audio'
import { back } from './router'

const paths: Record<string, string> = {
  sun: 'M12 4V2m0 20v-2m8-8h2M2 12h2m13.66-5.66 1.41-1.41M4.93 19.07l1.41-1.41m0-11.32L4.93 4.93m14.14 14.14-1.41-1.41M12 7a5 5 0 1 0 0 10 5 5 0 0 0 0-10z',
  map: 'M9 4 3 6v14l6-2 6 2 6-2V4l-6 2-6-2zm0 0v14m6-12v14',
  stack: 'M12 3 2 8l10 5 10-5-10-5zm-10 9 10 5 10-5M2 16l10 5 10-5',
  chat: 'M21 12a8 8 0 0 1-11.6 7.1L4 20l1-4.6A8 8 0 1 1 21 12z',
  person: 'M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8zm-8 9a8 8 0 0 1 16 0',
  back: 'M15 18l-6-6 6-6',
  play: 'M8 5v14l11-7z',
  speaker: 'M11 5 6 9H3v6h3l5 4V5zm4.5 3.5a5 5 0 0 1 0 7M18.5 5.5a9 9 0 0 1 0 13',
  check: 'M5 12.5 10 17l9-10',
  x: 'M6 6l12 12M18 6 6 18',
  chevron: 'M9 6l6 6-6 6',
  book: 'M4 5a2 2 0 0 1 2-2h13v16H6a2 2 0 0 0-2 2V5zm0 14a2 2 0 0 1 2-2h13',
  sparkles: 'M12 3l1.8 4.7L18.5 9.5l-4.7 1.8L12 16l-1.8-4.7L5.5 9.5l4.7-1.8L12 3zm7 11 .9 2.1 2.1.9-2.1.9L19 20l-.9-2.1L16 17l2.1-.9L19 14z',
  flame: 'M12 22c4 0 7-3 7-7 0-4-3-6-4-10-1 3-3 4-4 4 0-2-1-4-3-6 0 4-3 6-3 11 0 4 3 8 7 8z',
  download: 'M12 3v12m-5-5 5 5 5-5M4 21h16',
  upload: 'M12 21V9m-5 5 5-5 5 5M4 3h16',
  refresh: 'M4 4v6h6M20 20v-6h-6M5 13a7 7 0 0 0 12.5 3.5M19 11A7 7 0 0 0 6.5 7.5',
  eye: 'M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12zm10-3a3 3 0 1 0 0 6 3 3 0 0 0 0-6z',
  mic: 'M12 3a3 3 0 0 0-3 3v6a3 3 0 0 0 6 0V6a3 3 0 0 0-3-3zM5 11a7 7 0 0 0 14 0M12 18v3',
  stop: 'M7 7h10v10H7z',
  hint: 'M9 18h6M10 21h4M12 3a6 6 0 0 0-3.5 10.9c.6.5 1 1.2 1 2.1h5c0-.9.4-1.6 1-2.1A6 6 0 0 0 12 3z',
}

export function Icon({ name, label }: { name: keyof typeof paths | string; label?: string }) {
  return (
    <svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"
      aria-hidden={label ? undefined : 'true'} role={label ? 'img' : undefined} aria-label={label}>
      <path d={paths[name] ?? ''} />
    </svg>
  )
}

export function ScreenHeader({ title, amharic, subtitle }: { title: string; amharic?: string; subtitle?: string }) {
  return (
    <header class="screen-header">
      <h1>{title}</h1>
      {amharic && <p class="am-title" lang="am">{amharic}</p>}
      {subtitle && <p>{subtitle}</p>}
    </header>
  )
}

export function TopBar({ title, children }: { title: string; children?: ComponentChildren }) {
  return (
    <div class="topbar">
      <button class="icon-btn" onClick={back} aria-label="Back">
        <Icon name="back" />
      </button>
      <h1>{title}</h1>
      {children}
    </div>
  )
}

export function Ring({ value, size = 56, stroke = 6, color = 'var(--terracotta)', children, label }: {
  value: number; size?: number; stroke?: number; color?: string; children?: ComponentChildren; label?: string
}) {
  const r = (size - stroke) / 2
  const c = 2 * Math.PI * r
  return (
    <div class="ring" style={{ width: size, height: size }} role="img" aria-label={label ?? `${Math.round(value * 100)}%`}>
      <svg width={size} height={size} aria-hidden="true">
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke="var(--paper-accent)" stroke-width={stroke} />
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke={color} stroke-width={stroke} stroke-linecap="round"
          stroke-dasharray={c} stroke-dashoffset={c * (1 - Math.min(Math.max(value, 0), 1))} />
      </svg>
      {children && <div class="label">{children}</div>}
    </div>
  )
}

export function Bar({ value, label }: { value: number; label: string }) {
  return (
    <div class="bar" role="progressbar" aria-label={label} aria-valuemin={0} aria-valuemax={100} aria-valuenow={Math.round(value * 100)}>
      <span style={{ width: `${Math.min(Math.max(value, 0), 1) * 100}%` }} />
    </div>
  )
}

/** Speaker button for a bundled clip; renders nothing when no clip exists. */
export function PlayButton({ kind, id, path, label = 'Play pronunciation' }: { kind?: AudioKind; id?: string; path?: string | null; label?: string }) {
  const clip = path ?? (kind && id ? clipPath(kind, id) : null)
  if (!clip) return null
  const key = kind && id ? `${kind}:${id}` : clip
  return (
    <button class="icon-btn" type="button" aria-label={label} aria-pressed={playing.value === key} onClick={(e) => {
      e.stopPropagation()
      void play(clip, key)
    }}>
      <Icon name="speaker" />
    </button>
  )
}

export function Amharic({ text, translit, english, size = 'lg' }: { text: string; translit?: string; english?: string; size?: 'xl' | 'lg' | 'md' }) {
  return (
    <div>
      <div class={`amharic-${size}`} lang="am">{text}</div>
      {translit && <div class="translit">{translit}</div>}
      {english && <div class="secondary">{english}</div>}
    </div>
  )
}

export function Result({ title, detail, xp, onAgain, children }: { title: string; detail: string; xp: number; onAgain: () => void; children?: ComponentChildren }) {
  return (
    <div class="card stack" style={{ textAlign: 'center' }} role="status">
      <h2 style={{ margin: 0 }}>{title}</h2>
      <p class="secondary" style={{ margin: 0 }}>{detail}</p>
      <p style={{ margin: 0 }}><span class="chip accent">+{xp} XP</span></p>
      {children}
      <div class="grid-2">
        <button class="btn secondary" onClick={back}>Done</button>
        <button class="btn primary" onClick={onAgain}>Again</button>
      </div>
    </div>
  )
}

export function Empty({ children }: { children: ComponentChildren }) {
  return <div class="empty">{children}</div>
}

export const shuffle = <T,>(list: readonly T[]): T[] => {
  const a = [...list]
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1))
    ;[a[i], a[j]] = [a[j]!, a[i]!]
  }
  return a
}

export type Handler = JSX.MouseEventHandler<HTMLElement>
