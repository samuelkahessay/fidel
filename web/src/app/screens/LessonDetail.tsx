import { useEffect, useState } from 'preact/hooks'
import { wordId } from '../../content/types'
import { wordClip } from '../audio'
import { href } from '../router'
import { actions, progress, requireContent } from '../store'
import { Amharic, Empty, PlayButton, TopBar } from '../ui'

const sections = ['Patterns', 'Vocabulary', 'Phrases', 'Culture'] as const

export function LessonDetail({ id }: { id: number }) {
  const content = requireContent()
  const lesson = content.lessons.find((l) => l.id === id)
  const [tab, setTab] = useState<(typeof sections)[number]>('Patterns')
  const [done, setDone] = useState(false)

  useEffect(() => {
    if (lesson) actions.markLessonStarted(lesson.id)
  }, [lesson?.id])

  if (!lesson) return <Empty>That lesson doesn't exist. <a href={href('learn')}>Back to Learn</a></Empty>
  const notes = content.culturalNotes.filter((n) => n.lessonIds.includes(lesson.id))
  const completed = progress.value.lessonsCompleted.includes(lesson.id)

  return (
    <div class="stack">
      <TopBar title={lesson.title} />
      <p class="secondary" style={{ margin: 0 }}>{lesson.description}</p>

      <div class="segmented" role="tablist" aria-label="Lesson sections">
        {sections.map((s) => (
          <button key={s} role="tab" aria-selected={tab === s} onClick={() => setTab(s)}>{s}</button>
        ))}
      </div>

      <div class="list" role="tabpanel" aria-label={tab}>
        {tab === 'Patterns' && lesson.patterns.map((p) => (
          <details key={p.id} class="card">
            <summary>
              <span style={{ fontWeight: 600 }}>{p.description}</span>
              <span class="muted" style={{ display: 'block', fontSize: 13, fontWeight: 400 }}>{p.category}</span>
              <span class="amharic-lg" lang="am" style={{ display: 'block', color: 'var(--terracotta-deep)', marginTop: 8 }}>{p.structure}</span>
            </summary>
            {p.examples.slice(0, 3).map((e) => (
              <div key={e.amharic} class="spread" style={{ marginTop: 10 }}>
                <Amharic text={e.amharic} translit={e.transliteration} english={e.english} size="md" />
                <PlayButton path={wordClip(e.amharic)} />
              </div>
            ))}
            <button class="btn secondary" style={{ marginTop: 12 }} onClick={() => actions.learnPattern(p.id)}
              disabled={progress.value.patternsLearned.includes(p.id)}>
              {progress.value.patternsLearned.includes(p.id) ? 'Learned' : 'Mark as learned (+10 XP)'}
            </button>
          </details>
        ))}
        {tab === 'Vocabulary' && lesson.vocabulary.map((w) => (
          <div key={wordId(w)} class="list-item">
            <span class="grow"><Amharic text={w.amharic} translit={w.transliteration} english={w.english} size="md" /></span>
            <PlayButton kind="vocabulary" id={wordId(w)} path={undefined} />
          </div>
        ))}
        {tab === 'Phrases' && lesson.phrases.map((p) => (
          <div key={p.id} class="list-item">
            <span class="grow">
              <Amharic text={p.amharic} translit={p.transliteration} english={p.english} size="md" />
              {p.notes && <div class="muted" style={{ fontSize: 14 }}>{p.notes}</div>}
            </span>
            <PlayButton kind="phrase" id={String(p.id)} />
          </div>
        ))}
        {tab === 'Culture' && (notes.length ? notes.map((n) => (
          <article key={n.id} class="card">
            <h3 style={{ margin: 0 }}>{n.title}</h3>
            <p class="am" lang="am" style={{ margin: '2px 0 8px', color: 'var(--terracotta-deep)' }}>{n.amharicTitle}</p>
            <p style={{ margin: 0 }}>{n.content}</p>
          </article>
        )) : <Empty>No culture notes for this lesson yet.</Empty>)}
      </div>

      {done ? (
        <div class="feedback good" role="status">Lesson complete! You earned 25 XP.</div>
      ) : (
        <button class="btn primary block" onClick={() => { actions.completeLesson(lesson.id); setDone(true) }}>
          {completed ? 'Complete again' : 'Complete lesson'}
        </button>
      )}
    </div>
  )
}
