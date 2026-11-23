import { mastery, pathSections } from '../../logic/curriculum'
import { recommend } from '../../logic/planner'
import { href } from '../router'
import { dueVocabulary, learnedItemIds, progress, recognizedCharIds, requireContent, settings } from '../store'
import { Icon, Ring, ScreenHeader } from '../ui'

export function Learn() {
  const content = requireContent()
  const p = progress.value
  const session = recommend(p, content.lessons.map((l) => l.id), settings.value.dailyGoalTier, dueVocabulary.value.length)
  const completed = new Set(p.lessonsCompleted)
  const heroHref = session.heroAction.kind === 'lesson' ? href('lesson', session.heroAction.id) : href('practice', 'flashcards')

  return (
    <div class="stack">
      <ScreenHeader title="Learn" amharic="መማር" subtitle="A guided path from letters and sounds into everyday Amharic." />

      <section class="card hero-dark stack" aria-labelledby="learn-hero">
        <p class="eyebrow-label">{session.eyebrow}</p>
        <div>
          <h2 id="learn-hero" style={{ margin: 0 }}>{session.title}</h2>
          <p style={{ margin: '4px 0 0' }}>{session.detail}</p>
        </div>
        <a class="btn pill" href={heroHref}>Start <Icon name="chevron" /></a>
      </section>

      {pathSections.map((section) => (
        <section key={section.id} aria-labelledby={`section-${section.id}`}>
          <h2 class="section-title" id={`section-${section.id}`}>
            {section.title} <span lang="am" class="am">{section.amharicTitle}</span>
          </h2>
          <div class="list">
            {section.lessonIds.length === 0 && (
              <>
                <a class="list-item" href={href('reference', 'fidel')}>
                  <span class="amharic-md" lang="am" aria-hidden="true">ሀ</span>
                  <span class="grow"><span class="title">The Fidel chart</span><br /><span class="sub">238 characters with audio</span></span>
                  <Icon name="chevron" />
                </a>
                <a class="list-item" href={href('practice', 'tracing')}>
                  <span class="amharic-md" lang="am" aria-hidden="true">ለ</span>
                  <span class="grow"><span class="title">Practice Fidel</span><br /><span class="sub">Trace characters to learn them — adapts to what you know</span></span>
                  <Icon name="chevron" />
                </a>
              </>
            )}
            {section.lessonIds.map((id) => {
              const lesson = content.lessons.find((l) => l.id === id)!
              const m = mastery(lesson, content.fidelChart, learnedItemIds.value, recognizedCharIds.value)
              return (
                <a key={id} class="list-item" href={href('lesson', id)}>
                  <Ring value={m.fraction} size={48} stroke={5} label={`${m.tier}, ${Math.round(m.fraction * 100)}% learned`}>
                    {completed.has(id) ? <span style={{ color: 'var(--eucalyptus)', fontWeight: 700 }}>✓</span> : <strong style={{ fontSize: 14 }}>{id}</strong>}
                  </Ring>
                  <span class="grow">
                    <span class="title">{lesson.title}</span><br />
                    <span class="sub">{lesson.description}</span><br />
                    <span class="chip" style={{ marginTop: 6 }}>{m.tier}</span>{completed.has(id) && <span class="visually-hidden">, completed</span>}
                  </span>
                  {m.tier === 'New' && !completed.has(id) ? <span class="pill-small" aria-hidden="true">Start</span> : <Icon name="chevron" />}
                </a>
              )
            })}
            {section.id === 'sentences' && (
              <a class="list-item" href={href('conversations')}>
                <span class="amharic-md" lang="am" aria-hidden="true">ውይይት</span>
                <span class="grow"><span class="title">Conversations</span><br /><span class="sub">{content.conversations.length} dialogues</span></span>
                <Icon name="chevron" />
              </a>
            )}
          </div>
        </section>
      ))}
    </div>
  )
}
