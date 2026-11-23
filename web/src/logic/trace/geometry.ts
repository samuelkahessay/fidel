// Port of TraceTuning, TraceableStroke and TraceGeometry (Fidel/Services/TraceGeometry.swift)
// plus StrokeSmoother.smoothCGPath and StrokeRegionBuilder.decimate. Checked against the
// Swift engine with tests/golden/trace.json.

export interface Point {
  x: number
  y: number
}

export interface RecordedStroke {
  penWidth: number
  points: Point[]
}

export interface Tuning {
  corridorFactor: number
  minCorridorRadius: number
  maxCorridorRadiusRatio: number
  smallStrokeLengthRatio: number
  smallStrokeCorridorBoost: number
  startRadiusFactor: number
  endRadiusFactor: number
  completionProgress: number
  shortStrokeCompletionProgress: number
  shortStrokeLength: number
  dotLengthThreshold: number
  backwardSlackFraction: number
  forwardWindowFactor: number
  forwardWindowLengthFraction: number
  deviationGrace: number
  missesBeforeAutoHint: number
  hesitationHintDelay: number
  magnetCompletionFraction: number
  magnetEndRadiusFactor: number
  snapDuration: number
}

export const standardTuning: Tuning = {
  corridorFactor: 2.9, minCorridorRadius: 32, maxCorridorRadiusRatio: 0.16, smallStrokeLengthRatio: 0.15,
  smallStrokeCorridorBoost: 1.3, startRadiusFactor: 2.0, endRadiusFactor: 2.2, completionProgress: 0.82,
  shortStrokeCompletionProgress: 0.72, shortStrokeLength: 60, dotLengthThreshold: 18, backwardSlackFraction: 0.05,
  forwardWindowFactor: 2.5, forwardWindowLengthFraction: 0.08, deviationGrace: 0.45, missesBeforeAutoHint: 2,
  hesitationHintDelay: 4.0, magnetCompletionFraction: 0.8, magnetEndRadiusFactor: 2.4, snapDuration: 0.28,
}
export const level2Tuning: Tuning = { ...standardTuning, missesBeforeAutoHint: 3 }

export interface TraceableStroke {
  index: number
  polyline: Point[]
  cumulative: number[]
  totalLength: number
  startPoint: Point
  endPoint: Point
  corridorRadius: number
  isDot: boolean
}

export interface Projection {
  arcLength: number
  distance: number
  point: Point
}

const tieTolerance = 0.5
const ulp = Number.EPSILON
const dist = (a: Point, b: Point) => Math.hypot(a.x - b.x, a.y - b.y)

type Segment = { kind: 'move'; to: Point } | { kind: 'line'; to: Point } | { kind: 'curve'; c1: Point; c2: Point; to: Point }

/** `StrokeSmoother.smoothCGPath`: Catmull-Rom (tension 0.5) as cubic Béziers. */
export function smoothPath(points: Point[], width: number, height: number, tension = 0.5): Segment[] {
  if (points.length === 0) return []
  const s = points.map((p) => ({ x: p.x * width, y: p.y * height }))
  const at = (i: number) => s[i]!
  const path: Segment[] = [{ kind: 'move', to: at(0) }]
  if (s.length < 3) {
    for (const p of s.slice(1)) path.push({ kind: 'line', to: p })
    return path
  }
  const mirror = (p: Point, c: Point) => ({ x: 2 * c.x - p.x, y: 2 * c.y - p.y })
  for (let i = 0; i < s.length - 1; i++) {
    const p0 = i > 0 ? at(i - 1) : mirror(at(1), at(0))
    const p1 = at(i)
    const p2 = at(i + 1)
    const p3 = i + 2 < s.length ? at(i + 2) : mirror(at(s.length - 2), at(s.length - 1))
    const k = 6 * tension
    path.push({
      kind: 'curve',
      c1: { x: p1.x + (p2.x - p0.x) / k, y: p1.y + (p2.y - p0.y) / k },
      c2: { x: p2.x - (p3.x - p1.x) / k, y: p2.y - (p3.y - p1.y) / k },
      to: p2,
    })
  }
  return path
}

/** SVG path data for the same smoothed stroke, for rendering guides. */
export function pathData(segments: Segment[]): string {
  return segments
    .map((s) =>
      s.kind === 'move' ? `M${s.to.x} ${s.to.y}` : s.kind === 'line' ? `L${s.to.x} ${s.to.y}` : `C${s.c1.x} ${s.c1.y} ${s.c2.x} ${s.c2.y} ${s.to.x} ${s.to.y}`,
    )
    .join('')
}

/** `StrokeRegionBuilder.decimate`. */
export function decimate(points: Point[], minSpacing: number): Point[] {
  if (points.length <= 2) return points
  const kept = [points[0]!]
  for (const p of points.slice(1)) if (dist(p, kept[kept.length - 1]!) >= minSpacing) kept.push(p)
  const final = points[points.length - 1]!
  const last = kept[kept.length - 1]!
  if (final.x !== last.x || final.y !== last.y) kept.push(final)
  return kept
}

/** `TraceGeometry.flattenedPoints`: 48 steps per cubic, dedupe, then ~2pt decimation. */
function flatten(path: Segment[]): Point[] {
  const cubicSteps = 48
  const points: Point[] = []
  let current = { x: 0, y: 0 }
  for (const seg of path) {
    if (seg.kind === 'move' || seg.kind === 'line') {
      points.push(seg.to)
      current = seg.to
    } else {
      for (let step = 1; step <= cubicSteps; step++) {
        const t = step / cubicSteps
        const u = 1 - t
        points.push({
          x: u * u * u * current.x + 3 * u * u * t * seg.c1.x + 3 * u * t * t * seg.c2.x + t * t * t * seg.to.x,
          y: u * u * u * current.y + 3 * u * u * t * seg.c1.y + 3 * u * t * t * seg.c2.y + t * t * t * seg.to.y,
        })
      }
      current = seg.to
    }
  }
  const deduped: Point[] = []
  for (const p of points) {
    const last = deduped[deduped.length - 1]
    if (!last || dist(p, last) > 0.001) deduped.push(p)
  }
  return decimate(deduped, 2.0)
}

function remap(points: Point[], recordingGlyphScale: number): Point[] {
  if (Math.abs(recordingGlyphScale - 1) <= ulp) return points
  const offset = (1 - recordingGlyphScale) / 2
  return points.map((p) => ({ x: (p.x - offset) / recordingGlyphScale, y: (p.y - offset) / recordingGlyphScale }))
}

export function traceableStrokes(
  strokes: RecordedStroke[],
  canvas: { width: number; height: number },
  glyphStrokeWidth: number,
  recordingGlyphScale: number,
  tuning: Tuning,
): TraceableStroke[] {
  const result: TraceableStroke[] = []
  strokes.forEach((stroke, index) => {
    const polyline = flatten(smoothPath(remap(stroke.points, recordingGlyphScale), canvas.width, canvas.height))
    const first = polyline[0]
    if (!first) return
    const cumulative = [0]
    for (let i = 1; i < polyline.length; i++) cumulative.push(cumulative[i - 1]! + dist(polyline[i]!, polyline[i - 1]!))
    const totalLength = cumulative[cumulative.length - 1] ?? 0
    let corridorBase = Math.max(stroke.penWidth * canvas.width, glyphStrokeWidth) * tuning.corridorFactor
    if (totalLength < tuning.smallStrokeLengthRatio * canvas.width) corridorBase *= tuning.smallStrokeCorridorBoost
    const corridorRadius = Math.min(Math.max(corridorBase, tuning.minCorridorRadius), canvas.width * tuning.maxCorridorRadiusRatio)
    result.push({
      index, polyline, cumulative, totalLength, startPoint: first, endPoint: polyline[polyline.length - 1] ?? first,
      corridorRadius, isDot: totalLength < tuning.dotLengthThreshold,
    })
  })
  return result
}

/** `TraceGeometry.project`: nearest point within the arc window; ties prefer the later arc. */
export function project(point: Point, stroke: TraceableStroke, lowerArc: number, upperArc: number): Projection | null {
  if (stroke.polyline.length <= 1) return null
  let best: Projection | null = null
  let bestDistance = Number.MAX_VALUE
  for (let i = 0; i < stroke.polyline.length - 1; i++) {
    const arcStart = stroke.cumulative[i]!
    const arcEnd = stroke.cumulative[i + 1]!
    if (arcEnd < lowerArc || arcStart > upperArc) continue
    const length = arcEnd - arcStart
    if (length <= ulp) continue
    const tMin = Math.max(0, (lowerArc - arcStart) / length)
    const tMax = Math.min(1, (upperArc - arcStart) / length)
    if (tMin > tMax) continue
    const a = stroke.polyline[i]!
    const b = stroke.polyline[i + 1]!
    const dx = b.x - a.x
    const dy = b.y - a.y
    const raw = ((point.x - a.x) * dx + (point.y - a.y) * dy) / (length * length)
    const t = Math.min(Math.max(raw, tMin), tMax)
    const projected = { x: a.x + t * dx, y: a.y + t * dy }
    const distance = dist(point, projected)
    const arc = arcStart + t * length
    if (distance < bestDistance - tieTolerance) {
      best = { arcLength: arc, distance, point: projected }
      bestDistance = distance
    } else if (distance <= bestDistance + tieTolerance) {
      bestDistance = Math.min(bestDistance, distance)
      if (arc > (best?.arcLength ?? -Number.MAX_VALUE)) best = { arcLength: arc, distance, point: projected }
    }
  }
  return best
}

/** `TraceGeometry.point(at:on:)`. */
export function pointAt(arcLength: number, stroke: TraceableStroke): Point {
  if (stroke.polyline.length <= 1) return stroke.startPoint
  const clamped = Math.min(Math.max(arcLength, 0), stroke.totalLength)
  for (let i = 1; i < stroke.polyline.length; i++) {
    if (stroke.cumulative[i]! < clamped) continue
    const arcStart = stroke.cumulative[i - 1]!
    const length = stroke.cumulative[i]! - arcStart
    if (length <= ulp) continue
    const t = (clamped - arcStart) / length
    const a = stroke.polyline[i - 1]!
    const b = stroke.polyline[i]!
    return { x: a.x + t * (b.x - a.x), y: a.y + t * (b.y - a.y) }
  }
  return stroke.endPoint
}
