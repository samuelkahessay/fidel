import { useEffect, useMemo, useReducer, useRef, useState } from 'preact/hooks'
import { charId, type FidelCharacter } from '../../../content/types'
import { tiers } from '../../../logic/planner'
import { canvasSize, type EngineEvent, recordingGlyphScale, TraceEngine } from '../../../logic/trace/engine'
import { level2Tuning, pointAt, type RecordedStroke, standardTuning, type TraceableStroke } from '../../../logic/trace/geometry'
import { composeSession, curriculumOrder, type SessionItem, sessionScore } from '../../../logic/trace/session'
import { playContent } from '../../audio'
import { actions, requireContent, settings, trace } from '../../store'
import { Empty, Icon, Result, TopBar } from '../../ui'

const strokeCache = new Map<string, Promise<RecordedStroke[]>>()
function loadStrokes(id: string): Promise<RecordedStroke[]> {
  if (!strokeCache.has(id)) {
    strokeCache.set(id, fetch(`${import.meta.env.BASE_URL}strokes/${id}.json`).then((r) => {
      if (!r.ok) throw new Error(`strokes/${id}.json: HTTP ${r.status}`)
      return r.json().then((d: { strokes: RecordedStroke[] }) => d.strokes)
    }))
  }
  return strokeCache.get(id)!
}

const pathFor = (s: TraceableStroke, upTo = s.totalLength) => {
  const points = s.polyline.filter((_, i) => s.cumulative[i]! <= upTo)
  const end = pointAt(upTo, s)
  return `M${points.map((p) => `${p.x} ${p.y}`).join(' L')} L${end.x} ${end.y}`
}

const levelLabel = (level: number) => (level <= 1 ? 'Full guide' : level === 2 ? 'Faint guide' : 'From memory')

/** One character: draw each stroke in order inside the forgiving corridor. */
function TraceCanvas({ item, onComplete }: { item: SessionItem; onComplete: (score: number, misses: number) => void }) {
  const content = requireContent()
  const id = charId(item.character)
  const engine = useMemo(() => new TraceEngine(), [id])
  const [, rerender] = useReducer((n: number) => n + 1, 0)
  const [ready, setReady] = useState(false)
  const [hintAt, setHintAt] = useState<number | null>(null)
  const [snapAt, setSnapAt] = useState<number | null>(null)
  const canvas = useRef<HTMLCanvasElement>(null)
  const last = useRef<{ x: number; y: number } | null>(null)

  useEffect(() => {
    let cancelled = false
    void loadStrokes(id).then((strokes) => {
      if (cancelled) return
      engine.configure(strokes, canvasSize, content.glyphStrokeWidths[id] ?? 0, recordingGlyphScale, item.level >= 2 ? level2Tuning : standardTuning)
      engine.onEvent = (e: EngineEvent) => {
        if (e.type === 'characterCompleted') onComplete(sessionScore(e.stats, false), e.stats.misses)
        if (e.type === 'miss' || e.type === 'strokeCompleted') navigator.vibrate?.(e.type === 'miss' ? [10, 60, 10] : 12)
      }
      setReady(true)
      setHintAt(item.level === 1 ? performance.now() : null)
      engine.requestHint()
      if (item.level !== 1) engine.hintPlaybackFinished()
      rerender(0)
    })
    return () => { cancelled = true }
  }, [id])

  // View-owned animations, reported back to the engine as the iOS canvas does.
  useEffect(() => {
    if (engine.phase === 'snapping') {
      setSnapAt(performance.now())
      const t = setTimeout(() => { engine.strokeMagnetSnapFinished(); setSnapAt(null); rerender(0) }, standardTuning.snapDuration * 1000)
      return () => clearTimeout(t)
    }
    if (engine.phase === 'strokeComplete') {
      const t = setTimeout(() => { engine.strokeSnapFinished(); rerender(0) }, 160)
      return () => clearTimeout(t)
    }
    if (engine.phase === 'playingHint' && hintAt === null) setHintAt(performance.now())
  })
  useEffect(() => {
    if (hintAt === null && snapAt === null) return
    let frame = requestAnimationFrame(function tick() {
      if (hintAt !== null && performance.now() - hintAt > 1400) {
        setHintAt(null)
        engine.hintPlaybackFinished()
      }
      rerender(0)
      frame = requestAnimationFrame(tick)
    })
    return () => cancelAnimationFrame(frame)
  }, [hintAt, snapAt])

  const toCanvas = (e: PointerEvent) => {
    const rect = (e.currentTarget as HTMLElement).getBoundingClientRect()
    return { x: ((e.clientX - rect.left) / rect.width) * canvasSize.width, y: ((e.clientY - rect.top) / rect.height) * canvasSize.height }
  }
  const ink = (from: { x: number; y: number }, to: { x: number; y: number }) => {
    const ctx = canvas.current?.getContext('2d')
    if (!ctx) return
    ctx.lineWidth = 7
    ctx.lineCap = ctx.lineJoin = 'round'
    ctx.strokeStyle = getComputedStyle(canvas.current!).getPropertyValue('--terracotta') || '#b55130'
    ctx.beginPath()
    ctx.moveTo(from.x, from.y)
    ctx.lineTo(to.x, to.y)
    ctx.stroke()
  }
  const clearInk = () => canvas.current?.getContext('2d')?.clearRect(0, 0, canvasSize.width, canvasSize.height)

  const onDown = (e: PointerEvent) => {
    if (engine.phase === 'playingHint') { setHintAt(null); engine.hintPlaybackFinished() }
    ;(e.currentTarget as HTMLElement).setPointerCapture(e.pointerId)
    const p = toCanvas(e)
    clearInk()
    last.current = p
    engine.touchBegan(p, e.timeStamp / 1000)
    rerender(0)
  }
  const onMove = (e: PointerEvent) => {
    if (!last.current) return
    const p = toCanvas(e)
    ink(last.current, p)
    last.current = p
    engine.touchMoved(p, e.timeStamp / 1000)
    rerender(0)
  }
  const onUp = (e: PointerEvent) => {
    if (!last.current) return
    last.current = null
    engine.touchEnded(toCanvas(e), e.timeStamp / 1000)
    clearInk()
    rerender(0)
  }

  if (!ready) return <div class="trace-wrap" aria-busy="true" />
  const active = engine.activeStroke
  const guideOpacity = item.level <= 1 ? 0.22 : item.level === 2 ? 0.1 : 0
  const snapProgress = snapAt === null ? null : Math.min(1, (performance.now() - snapAt) / (standardTuning.snapDuration * 1000))
  const fill = engine.phase === 'snapping' && snapProgress !== null ? engine.snapStartProgress + (1 - engine.snapStartProgress) * snapProgress : engine.displayProgress
  const hintProgress = hintAt === null ? null : Math.min(1, (performance.now() - hintAt) / 1200)

  return (
    <div class="stack">
      <div class="trace-wrap" onPointerDown={onDown} onPointerMove={onMove} onPointerUp={onUp} onPointerCancel={onUp}
        role="img" aria-label={`Trace ${item.character.character}, stroke ${engine.activeStrokeIndex + 1} of ${engine.strokes.length}`}>
        <svg viewBox={`0 0 ${canvasSize.width} ${canvasSize.height}`} aria-hidden="true">
          {engine.strokes.map((s) => {
            const done = s.index < engine.activeStrokeIndex || engine.phase === 'characterComplete'
            const isActive = s.index === engine.activeStrokeIndex && engine.phase !== 'characterComplete'
            return (
              <g key={s.index}>
                {!done && guideOpacity > 0 && (
                  <path d={pathFor(s)} fill="none" stroke="var(--ink)" stroke-opacity={isActive ? guideOpacity : guideOpacity / 2}
                    stroke-width={Math.min(s.corridorRadius * 0.7, 26)} stroke-linecap="round" stroke-linejoin="round" />
                )}
                {(done || (isActive && fill > 0)) && (
                  <path d={pathFor(s, done ? s.totalLength : fill * s.totalLength)} fill="none" stroke="var(--ink)"
                    stroke-width="14" stroke-linecap="round" stroke-linejoin="round" />
                )}
              </g>
            )
          })}
          {active && engine.phase === 'waitingForStart' && item.level < 3 && (
            <circle cx={active.startPoint.x} cy={active.startPoint.y} r="11" fill="var(--terracotta)" />
          )}
          {active && hintProgress !== null && (() => {
            const p = pointAt(hintProgress * active.totalLength, active)
            return <circle cx={p.x} cy={p.y} r="12" fill="var(--gold)" />
          })()}
        </svg>
        <canvas ref={canvas} width={canvasSize.width} height={canvasSize.height} />
      </div>
      <div class="row" style={{ justifyContent: 'center', flexWrap: 'wrap' }}>
        <span class="chip">{levelLabel(item.level)}</span>
        <span class="chip">Stroke {Math.min(engine.activeStrokeIndex + 1, engine.strokes.length)} of {engine.strokes.length}</span>
        <button class="btn ghost" onClick={() => { engine.requestHint(); setHintAt(performance.now()); rerender(0) }}
          disabled={engine.phase !== 'waitingForStart'}><Icon name="hint" /> Show me</button>
        <button class="btn ghost" onClick={() => { engine.accessibilityCompleteActiveStroke(); rerender(0) }}
          disabled={engine.phase !== 'waitingForStart' && engine.phase !== 'tracing'}>Skip stroke</button>
      </div>
    </div>
  )
}

export function Tracing({ characterId }: { characterId?: string }) {
  const content = requireContent()
  const [round, setRound] = useState(0)
  const items = useMemo<SessionItem[]>(() => {
    const all = content.fidelChart.flat()
    if (characterId) {
      const c = all.find((x) => charId(x) === characterId)
      return c ? [{ character: c, level: Math.min((trace.peek().get(characterId)?.level ?? 0) + 1, 3) }] : []
    }
    const ordered = curriculumOrder(content.fidelChart, (id) => id in content.glyphStrokeWidths)
    return composeSession([...trace.peek().values()], ordered, tiers[settings.peek().dailyGoalTier].tracingSessionSize)
  }, [round, characterId])
  const [index, setIndex] = useState(0)
  const [celebrate, setCelebrate] = useState<{ xp: number; promoted: boolean; character: FidelCharacter } | null>(null)
  const [xp, setXp] = useState(0)

  if (!items.length) return <Empty>Nothing to trace right now.</Empty>
  const restart = () => { setRound(round + 1); setIndex(0); setXp(0); setCelebrate(null) }
  if (index >= items.length) {
    return (
      <div class="stack">
        <TopBar title="Character Tracing" />
        <Result title="Session complete" detail={`${items.length} character${items.length === 1 ? '' : 's'} traced`} xp={xp} onAgain={restart} />
      </div>
    )
  }
  const item = items[index]!
  const complete = (score: number, misses: number) => {
    const id = charId(item.character)
    const result = actions.completeTrace(id, item.level, score, misses)
    setXp((x) => x + result.xp)
    void playContent('fidelCharacter', id)
    setCelebrate({ xp: result.xp, promoted: result.promoted, character: item.character })
  }

  return (
    <div class="stack">
      <TopBar title="Character Tracing"><span class="chip">{index + 1}/{items.length}</span></TopBar>
      <div class="row" style={{ justifyContent: 'center' }}>
        <span class="amharic-lg" lang="am">{item.character.character}</span>
        <span class="translit">{item.character.romanization}</span>
        <button class="icon-btn" aria-label="Play sound" onClick={() => void playContent('fidelCharacter', charId(item.character))}><Icon name="speaker" /></button>
      </div>
      {celebrate ? (
        <div class="card stack" style={{ textAlign: 'center' }} role="status">
          <div class="amharic-xl" lang="am">{celebrate.character.character}</div>
          <p style={{ margin: 0 }}>{celebrate.promoted ? `Level up! ${levelLabel(item.level + 1 > 3 ? 3 : item.level)} done.` : 'Nice work.'} <span class="chip accent">+{celebrate.xp} XP</span></p>
          <button class="btn primary" autoFocus onClick={() => { setCelebrate(null); setIndex(index + 1) }}>Next</button>
        </div>
      ) : (
        <TraceCanvas key={`${round}-${index}`} item={item} onComplete={complete} />
      )}
    </div>
  )
}
