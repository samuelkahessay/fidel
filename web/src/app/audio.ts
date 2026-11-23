// Plays bundled pronunciation clips by content key. Clips are fetched on first
// play and cached by the service worker.
import { signal } from '@preact/signals'
import { content } from './store'

export type AudioKind = 'phrase' | 'vocabulary' | 'conversationLine' | 'fidelCharacter'

export const playing = signal<string | null>(null)
let current: HTMLAudioElement | null = null

export function clipPath(kind: AudioKind, id: string): string | null {
  return content.value?.audio[`${kind}:${id}`] ?? null
}

export function hasClip(kind: AudioKind, id: string): boolean {
  return clipPath(kind, id) !== null
}

/** Words inside sentences are keyed by the Amharic text itself (the words-v1 set). */
export function wordClip(amharic: string): string | null {
  return content.value?.audio[`vocabulary:${amharic}`] ?? null
}

const blobs = new Map<string, Promise<string>>()

/**
 * Fetches the whole clip (a cacheable 200, unlike the 206 range responses an
 * <audio> element requests), so the service worker keeps it for offline use.
 */
function clipUrl(path: string): Promise<string> {
  if (!blobs.has(path)) {
    blobs.set(
      path,
      fetch(`${import.meta.env.BASE_URL}audio/${path}`).then(async (r) => {
        if (!r.ok) throw new Error(`audio ${path}: HTTP ${r.status}`)
        return URL.createObjectURL(await r.blob())
      }),
    )
  }
  return blobs.get(path)!
}

export async function play(path: string | null, key = path ?? ''): Promise<void> {
  if (!path) return
  current?.pause()
  playing.value = key
  let src: string
  try {
    src = await clipUrl(path)
  } catch {
    blobs.delete(path)
    playing.value = null
    return
  }
  const audio = new Audio(src)
  current = audio
  playing.value = key
  audio.onended = audio.onerror = () => {
    if (current === audio) playing.value = null
  }
  try {
    await audio.play()
  } catch {
    playing.value = null
  }
}

export const playContent = (kind: AudioKind, id: string) => play(clipPath(kind, id), `${kind}:${id}`)

/** Downloads every clip into the service worker cache for full offline use. */
export async function downloadAllAudio(onProgress: (done: number, total: number) => void): Promise<void> {
  const paths = [...new Set(Object.values(content.value?.audio ?? {}))]
  const cache = await caches.open('fidel-audio')
  let done = 0
  const queue = [...paths]
  const worker = async () => {
    for (let path = queue.shift(); path; path = queue.shift()) {
      const url = `${import.meta.env.BASE_URL}audio/${path}`
      if (!(await cache.match(url))) {
        const response = await fetch(url)
        if (response.ok) await cache.put(url, response)
      }
      onProgress(++done, paths.length)
    }
  }
  await Promise.all(Array.from({ length: 6 }, worker))
}
