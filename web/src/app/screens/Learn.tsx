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
      <ScreenHeader title="Learn" amharic="ተማር" subtitle="Every lesson is open. Start anywhere; the ring shows how much you know." />

      <a class="card row" href={heroHref} style={{ textDecoration: 'none', color: 'inherit' }}>
        <div style={{ flex: 1 }}>
          <p class="muted" style={{ margin: 0, fontWeight: 600 }}>{session.eyebrow}</p>
          <h2 style={{ margin: '4px 0' }}>{session.title}</h2>
          <p class="secondary" style={{ margin: 0 }}>{session.detail}</p>
        </div>
        <span class="icon-btn" aria-hidden="true"><Icon name="chevron" /></span>
      </a>

      {pathSections.map((section) => (
        <section key={section.id} aria-labelledby={`section-${section.id}`}>
          <h2 class="section-label" id={`section-${section.id}`}>
            {section.title} · <span lang="am" class="am">{section.amharicTitle}</span>
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
                  <span class="grow"><span class="title">Trace the letters</span><br /><span class="sub">Guided stroke order</span></span>
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
                    <strong style={{ fontSize: 14 }}>{id}</strong>
                  </Ring>
                  <span class="grow">
                    <span class="title">{lesson.title}</span><br />
                    <span class="sub">{completed.has(id) ? 'Completed · ' : ''}{m.tier}</span>
                  </span>
                  <Icon name="chevron" />
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
