// Port of TraceEngine (Fidel/Services/TraceEngine.swift): a synchronous state
// machine driven by touches with explicit timestamps. The view reports back when
// its snap and hint animations finish.
import { type Point, project, type RecordedStroke, standardTuning, type TraceableStroke, traceableStrokes, type Tuning } from './geometry'

export type StrokePhase = 'waitingForStart' | 'tracing' | 'snapping' | 'playingHint' | 'strokeComplete' | 'characterComplete'

export interface AttemptStats {
  misses: number
  hintsAutoPlayed: number
  duration: number
  accessibilityCompletions: number
}

export type EngineEvent =
  | { type: 'strokeStarted'; index: number }
  | { type: 'strokeCompleted'; index: number }
  | { type: 'miss'; index: number; count: number }
  | { type: 'hintAutoPlayed'; index: number }
  | { type: 'characterCompleted'; stats: AttemptStats }

const quantizationSteps = 128
const dist = (a: Point, b: Point) => Math.hypot(a.x - b.x, a.y - b.y)
/** Swift `rounded()` is half away from zero. */
const roundSwift = (x: number) => Math.sign(x) * Math.round(Math.abs(x))

export class TraceEngine {
  strokes: TraceableStroke[] = []
  activeStrokeIndex = 0
  phase: StrokePhase = 'waitingForStart'
  displayProgress = 0
  snapStartProgress = 0
  fingerSnapPoint: Point | null = null
  missCountForActiveStroke = 0
  tuning: Tuning = standardTuning
  onEvent: ((event: EngineEvent) => void) | null = null

  private currentArc = 0
  private outsideSince: number | null = null
  private totalMisses = 0
  private totalHintsAutoPlayed = 0
  private totalAccessibilityCompletions = 0
  private firstTouchTime: number | null = null
  private lastTouchTime = 0

  get activeStroke(): TraceableStroke | undefined {
    return this.strokes[this.activeStrokeIndex]
  }

  configure(strokes: RecordedStroke[], canvas: { width: number; height: number }, glyphStrokeWidth: number, recordingGlyphScale: number, tuning: Tuning = standardTuning) {
    this.tuning = tuning
    this.strokes = traceableStrokes(strokes, canvas, glyphStrokeWidth, recordingGlyphScale, tuning)
    this.reset()
  }

  reset() {
    this.activeStrokeIndex = 0
    this.phase = 'waitingForStart'
    this.displayProgress = 0
    this.snapStartProgress = 0
    this.fingerSnapPoint = null
    this.missCountForActiveStroke = 0
    this.currentArc = 0
    this.outsideSince = null
    this.totalMisses = 0
    this.totalHintsAutoPlayed = 0
    this.totalAccessibilityCompletions = 0
    this.firstTouchTime = null
    this.lastTouchTime = 0
  }

  touchBegan(point: Point, time: number) {
    const stroke = this.activeStroke
    if (this.phase !== 'waitingForStart' || !stroke) return
    this.firstTouchTime ??= time
    this.lastTouchTime = time
    if (dist(point, stroke.startPoint) > stroke.corridorRadius * this.tuning.startRadiusFactor) return
    if (stroke.isDot) return this.completeActiveStroke()
    this.currentArc = 0
    this.outsideSince = null
    this.displayProgress = 0
    this.fingerSnapPoint = stroke.startPoint
    this.phase = 'tracing'
    this.emit({ type: 'strokeStarted', index: this.activeStrokeIndex })
  }

  touchMoved(point: Point, time: number) {
    const stroke = this.activeStroke
    if (this.phase !== 'tracing' || !stroke) return
    this.lastTouchTime = time
    const lowerArc = this.currentArc - this.tuning.backwardSlackFraction * stroke.totalLength
    const upperArc =
      this.currentArc +
      Math.max(this.tuning.forwardWindowFactor * stroke.corridorRadius, this.tuning.forwardWindowLengthFraction * stroke.totalLength)
    const projection = project(point, stroke, lowerArc, upperArc)
    if (!projection || projection.distance > stroke.corridorRadius) {
      this.outsideSince ??= time
      return
    }
    this.outsideSince = null
    if (projection.arcLength > this.currentArc) this.currentArc = projection.arcLength
    this.displayProgress = this.quantize(this.currentArc / stroke.totalLength)
    this.fingerSnapPoint = projection.point
    if (this.currentArc / stroke.totalLength >= 0.995) this.completeActiveStroke()
  }

  touchEnded(point: Point, time: number) {
    const stroke = this.activeStroke
    if (this.phase !== 'tracing' || !stroke) return
    this.lastTouchTime = time
    const threshold = stroke.totalLength < this.tuning.shortStrokeLength ? this.tuning.shortStrokeCompletionProgress : this.tuning.magnetCompletionFraction
    const progress = stroke.totalLength > Number.EPSILON ? this.currentArc / stroke.totalLength : 1
    const nearEnd = dist(point, stroke.endPoint) <= stroke.corridorRadius * this.tuning.magnetEndRadiusFactor
    if (progress >= threshold && (nearEnd || progress >= 0.95)) this.magnetSnapToComplete()
    else this.registerGiveUp()
  }

  strokeMagnetSnapFinished() {
    if (this.phase !== 'snapping') return
    this.displayProgress = 1
    this.emit({ type: 'strokeCompleted', index: this.activeStrokeIndex })
    this.advanceAfterStrokeFinished()
  }

  strokeSnapFinished() {
    if (this.phase === 'strokeComplete') this.advanceAfterStrokeFinished()
  }

  requestHint() {
    if (this.phase === 'waitingForStart') this.phase = 'playingHint'
  }

  accessibilityCompleteActiveStroke() {
    if ((this.phase !== 'waitingForStart' && this.phase !== 'tracing') || !this.activeStroke) return
    this.totalAccessibilityCompletions += 1
    this.completeActiveStroke()
  }

  hintPlaybackFinished() {
    if (this.phase === 'playingHint') this.phase = 'waitingForStart'
  }

  private advanceAfterStrokeFinished() {
    if (this.activeStrokeIndex < this.strokes.length - 1) {
      this.activeStrokeIndex += 1
      this.currentArc = 0
      this.displayProgress = 0
      this.snapStartProgress = 0
      this.fingerSnapPoint = null
      this.missCountForActiveStroke = 0
      this.outsideSince = null
      this.phase = 'waitingForStart'
    } else {
      this.phase = 'characterComplete'
      this.emit({
        type: 'characterCompleted',
        stats: {
          misses: this.totalMisses,
          hintsAutoPlayed: this.totalHintsAutoPlayed,
          duration: this.firstTouchTime === null ? 0 : this.lastTouchTime - this.firstTouchTime,
          accessibilityCompletions: this.totalAccessibilityCompletions,
        },
      })
    }
  }

  private registerGiveUp() {
    this.missCountForActiveStroke += 1
    this.totalMisses += 1
    this.currentArc = 0
    this.displayProgress = 0
    this.snapStartProgress = 0
    this.fingerSnapPoint = null
    this.outsideSince = null
    this.emit({ type: 'miss', index: this.activeStrokeIndex, count: this.missCountForActiveStroke })
    if (this.missCountForActiveStroke >= this.tuning.missesBeforeAutoHint) {
      this.missCountForActiveStroke = 0
      this.totalHintsAutoPlayed += 1
      this.phase = 'playingHint'
      this.emit({ type: 'hintAutoPlayed', index: this.activeStrokeIndex })
    } else {
      this.phase = 'waitingForStart'
    }
  }

  private magnetSnapToComplete() {
    const stroke = this.activeStroke
    if (!stroke) return
    this.snapStartProgress = this.displayProgress
    this.currentArc = stroke.totalLength
    this.fingerSnapPoint = null
    this.outsideSince = null
    this.phase = 'snapping'
  }

  private completeActiveStroke() {
    const stroke = this.activeStroke
    if (!stroke) return
    this.currentArc = stroke.totalLength
    this.displayProgress = 1
    this.snapStartProgress = 1
    this.fingerSnapPoint = null
    this.outsideSince = null
    this.phase = 'strokeComplete'
    this.emit({ type: 'strokeCompleted', index: this.activeStrokeIndex })
  }

  private quantize(progress: number) {
    const clamped = Math.min(Math.max(progress, 0), 1)
    return roundSwift(clamped * quantizationSteps) / quantizationSteps
  }

  private emit(event: EngineEvent) {
    this.onEvent?.(event)
  }
}

/** `TracingSessionViewModel.guidedScore` and `sessionScore` live in scoring.ts. */
export const recordingGlyphScale = 0.58
export const canvasSize = { width: 300, height: 300 }
