import { recommend, tiers } from '../../logic/planner'
import { todayXP } from '../../logic/progress'
import { href } from '../router'
import { dueVocabulary, progress, requireContent, settings } from '../store'
import { Amharic, Icon, PlayButton, Ring, ScreenHeader } from '../ui'

export function Today() {
  const content = requireContent()
  const p = progress.value
  const tier = settings.value.dailyGoalTier
  const session = recommend(p, content.lessons.map((l) => l.id), tier, dueVocabulary.value.length)
  const goal = settings.value.dailyXPGoal
  const xp = todayXP(p, new Date())
  const heroHref = session.heroAction.kind === 'lesson' ? href('lesson', session.heroAction.id) : href('practice', 'flashcards')
  const dayIndex = Math.floor(Date.now() / 86_400_000)
  const phrase = content.phrases[dayIndex % content.phrases.length]!

  return (
    <div class="stack">
      <ScreenHeader title="Today" amharic="ዛሬ" subtitle="A calm path through Fidel, words, practice, and conversation." />

      <section class="card stack" aria-labelledby="hero-title">
        <div class="spread">
          <div>
            <p class="muted" style={{ margin: 0, fontWeight: 600 }}>{session.eyebrow}</p>
            <h2 id="hero-title" style={{ margin: '4px 0' }}>{session.title}</h2>
            <p class="secondary" style={{ margin: 0 }}>{session.detail}</p>
          </div>
          <Ring value={xp / goal} size={88} stroke={8} color="var(--gold)" label={`${xp} of ${goal} XP today`}>
            <strong style={{ fontSize: 22 }}>{xp}</strong>
            <div class="muted" style={{ fontSize: 12 }}>/{goal}</div>
          </Ring>
        </div>
        <a class="btn primary block" href={heroHref}>
          <Icon name="play" /> Continue
        </a>
        <p class="muted" style={{ margin: 0, fontSize: 14 }}>
          Pace: {tiers[tier].displayName} · <a href={href('you')}>change</a>
        </p>
      </section>

      <h2 class="section-label">Quick paths</h2>
      <div class="scroll-row">
        <a class="tile terracotta" href={href('reference', 'fidel')}>Fidel grid<small>Browse letters</small></a>
        <a class="tile eucalyptus" href={href('practice')}>Practice<small>Flashcards and drills</small></a>
        <a class="tile plum" href={href('conversations')}>Converse<small>Guided phrases</small></a>
        <a class="tile deep" href={href('reference', 'phrases')}>Reference<small>Phrasebook</small></a>
        <a class="tile gold" href={href('practice', 'tracing')}>Trace<small>Write the letters</small></a>
      </div>

      <h2 class="section-label">Phrase of the day</h2>
      <section class="card spread">
        <Amharic text={phrase.amharic} translit={phrase.transliteration} english={phrase.english} />
        <PlayButton kind="phrase" id={String(phrase.id)} />
      </section>
    </div>
  )
}
