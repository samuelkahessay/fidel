import { useEffect, useMemo, useRef, useState } from 'preact/hooks'
import { hasClip, playContent } from '../../audio'
import { requireContent } from '../../store'
import { Amharic, Icon, shuffle, TopBar } from '../../ui'

/** Listen to a bundled clip, record yourself, and compare. Recordings stay on the device. */
export function Pronunciation() {
  const content = requireContent()
  const phrases = useMemo(() => shuffle(content.phrases.filter((p) => hasClip('phrase', String(p.id)))).slice(0, 10), [])
  const [index, setIndex] = useState(0)
  const [recording, setRecording] = useState(false)
  const [takeUrl, setTakeUrl] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const recorder = useRef<MediaRecorder | null>(null)
  const canRecord = typeof window !== 'undefined' && 'MediaRecorder' in window && !!navigator.mediaDevices?.getUserMedia

  useEffect(() => () => { if (takeUrl) URL.revokeObjectURL(takeUrl) }, [takeUrl])
  const phrase = phrases[index % phrases.length]!

  const start = async () => {
    setError(null)
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      const chunks: Blob[] = []
      const r = new MediaRecorder(stream)
      r.ondataavailable = (e) => chunks.push(e.data)
      r.onstop = () => {
        stream.getTracks().forEach((t) => t.stop())
        setTakeUrl(URL.createObjectURL(new Blob(chunks, { type: r.mimeType })))
      }
      r.start()
      recorder.current = r
      setRecording(true)
    } catch {
      setError('Microphone access was blocked. You can still listen and repeat aloud.')
    }
  }
  const stop = () => { recorder.current?.stop(); setRecording(false) }

  return (
    <div class="stack">
      <TopBar title="Pronunciation"><span class="chip">{index + 1}/{phrases.length}</span></TopBar>
      <div class="card stack" style={{ textAlign: 'center', justifyItems: 'center' }}>
        <Amharic text={phrase.amharic} translit={phrase.transliteration} english={phrase.english} size="xl" />
        <button class="btn primary" onClick={() => void playContent('phrase', String(phrase.id))}><Icon name="speaker" /> Listen</button>
      </div>
      {canRecord ? (
        <div class="card stack">
          <p class="secondary" style={{ margin: 0 }}>Record yourself, then compare with the native recording. Nothing leaves your device.</p>
          {recording ? (
            <button class="btn primary" onClick={stop}><Icon name="stop" /> Stop recording</button>
          ) : (
            <button class="btn secondary" onClick={start}><Icon name="mic" /> {takeUrl ? 'Record again' : 'Record yourself'}</button>
          )}
          {takeUrl && !recording && <audio controls src={takeUrl} aria-label="Your recording" style={{ width: '100%' }} />}
          {error && <p class="muted" role="alert" style={{ margin: 0 }}>{error}</p>}
        </div>
      ) : (
        <p class="muted">Listen and repeat aloud. This browser can't record audio.</p>
      )}
      <button class="btn secondary block" onClick={() => { setIndex(index + 1); setTakeUrl(null) }}>Next phrase</button>
    </div>
  )
}
