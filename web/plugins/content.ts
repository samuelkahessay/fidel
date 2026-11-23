/**
 * Build-time bridge from the iOS app's content to the web app.
 *
 * Everything under ../Fidel is the source of truth. This plugin reads it at
 * dev/build time and serves or emits derived assets; nothing is copied into
 * web/ source. Emitted:
 *   content.json       all learner content plus an audio lookup map
 *   audio/**           the MP3s referenced by audio_manifest.json
 *   strokes/<id>.json  per-character stroke data, rounded to 4 dp
 *   fonts/*.woff2      Noto Ethiopic fonts converted from the bundled TTFs
 */
import fs from 'node:fs'
import path from 'node:path'
import type { Plugin, ViteDevServer } from 'vite'

const appRoot = path.resolve(__dirname, '../../Fidel')
const dataDir = path.join(appRoot, 'Data')

const readJSON = (file: string) => JSON.parse(fs.readFileSync(path.join(dataDir, `${file}.json`), 'utf8'))

interface ManifestEntry {
  contentType: string
  contentId: string
  file: string
}

export function buildContent() {
  const manifest: ManifestEntry[] = readJSON('audio_manifest')
  const audio: Record<string, string> = {}
  for (const entry of manifest) audio[`${entry.contentType}:${entry.contentId}`] = entry.file.replace(/^Audio\//, '')
  return {
    fidelChart: readJSON('fidel_chart'),
    patterns: readJSON('patterns'),
    vocabulary: readJSON('vocabulary'),
    phrases: readJSON('phrases'),
    conversations: readJSON('conversations'),
    culturalNotes: readJSON('cultural_notes'),
    readingPassages: readJSON('reading_passages'),
    sentenceExercises: readJSON('sentence_exercises'),
    numbers: readJSON('numbers'),
    audio,
  }
}

const round = (value: unknown): unknown => {
  if (typeof value === 'number') return Math.round(value * 1e4) / 1e4
  if (Array.isArray(value)) return value.map(round)
  if (value && typeof value === 'object') {
    return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, round(v)]))
  }
  return value
}

function strokeFiles(): Map<string, string> {
  const raw = JSON.parse(fs.readFileSync(path.join(appRoot, 'fidel_stroke_data.json'), 'utf8'))
  const files = new Map<string, string>()
  for (const [id, character] of Object.entries(raw.characters)) files.set(id, JSON.stringify(round(character)))
  return files
}

async function woff2(ttf: string): Promise<Buffer> {
  const { compress } = await import('wawoff2')
  return Buffer.from(await compress(fs.readFileSync(path.join(appRoot, ttf))))
}

const fonts: Record<string, string> = {
  'fonts/NotoSansEthiopic.woff2': 'NotoSansEthiopic-Regular.ttf',
  'fonts/NotoSerifEthiopic.woff2': 'NotoSerifEthiopic-Regular.ttf',
}

const contentType = (file: string) =>
  file.endsWith('.mp3') ? 'audio/mpeg' : file.endsWith('.woff2') ? 'font/woff2' : 'application/json'

export function fidelContent(): Plugin {
  let outDir = 'dist'
  let strokes: Map<string, string> | undefined
  const fontCache = new Map<string, Buffer>()

  return {
    name: 'fidel-content',
    configResolved(config) {
      outDir = path.resolve(config.root, config.build.outDir)
    },
    configureServer(server: ViteDevServer) {
      server.middlewares.use(async (req, res, next) => {
        const url = decodeURIComponent((req.url ?? '').split('?')[0] ?? '').replace(server.config.base, '/')
        try {
          if (url === '/content.json') {
            res.setHeader('Content-Type', contentType(url))
            return res.end(JSON.stringify(buildContent()))
          }
          if (url.startsWith('/audio/')) {
            const file = path.join(appRoot, 'Audio', url.slice('/audio/'.length))
            if (!file.startsWith(path.join(appRoot, 'Audio')) || !fs.existsSync(file)) return next()
            res.setHeader('Content-Type', contentType(file))
            return fs.createReadStream(file).pipe(res)
          }
          if (url.startsWith('/strokes/')) {
            strokes ??= strokeFiles()
            const body = strokes.get(path.basename(url, '.json'))
            if (!body) return next()
            res.setHeader('Content-Type', contentType(url))
            return res.end(body)
          }
          const ttf = fonts[url.slice(1)]
          if (ttf) {
            if (!fontCache.has(url)) fontCache.set(url, await woff2(ttf))
            res.setHeader('Content-Type', contentType(url))
            return res.end(fontCache.get(url))
          }
        } catch (error) {
          return next(error)
        }
        next()
      })
    },
    // Precached by the service worker, so emitted into the bundle itself.
    async generateBundle() {
      this.emitFile({ type: 'asset', fileName: 'content.json', source: JSON.stringify(buildContent()) })
      for (const [target, ttf] of Object.entries(fonts)) {
        this.emitFile({ type: 'asset', fileName: target, source: await woff2(ttf) })
      }
    },
    // Cached on first use at runtime (see vite.config.ts), so copied after bundling.
    async closeBundle() {
      if (!fs.existsSync(outDir)) return
      const content = buildContent()
      for (const file of new Set(Object.values(content.audio))) {
        const target = path.join(outDir, 'audio', file)
        fs.mkdirSync(path.dirname(target), { recursive: true })
        fs.copyFileSync(path.join(appRoot, 'Audio', file), target)
      }

      fs.mkdirSync(path.join(outDir, 'strokes'), { recursive: true })
      for (const [id, body] of strokeFiles()) fs.writeFileSync(path.join(outDir, 'strokes', `${id}.json`), body)
    },
  }
}
