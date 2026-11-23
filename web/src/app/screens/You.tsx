import { useState } from 'preact/hooks'
import { achievements } from '../../logic/achievements'
import { BackupError } from '../../logic/backup'
import { type Tier, tiers, tierSubtitle } from '../../logic/planner'
import { level, levelProgress, todayXP } from '../../logic/progress'
import { downloadAllAudio } from '../audio'
import { actions, progress, settings, trace } from '../store'
import { Bar, Icon, Ring, ScreenHeader } from '../ui'

export function You() {
  const p = progress.value
  const s = settings.value
  const [message, setMessage] = useState<string | null>(null)
  const [download, setDownload] = useState<{ done: number; total: number } | null>(null)
  const traced = [...trace.value.values()].filter((m) => m.level > 0).length

  const exportFile = () => {
    const blob = new Blob([actions.exportBackup()], { type: 'application/json' })
    const a = document.createElement('a')
    a.href = URL.createObjectURL(blob)
    a.download = `Fidel-Backup-${new Date().toISOString().slice(0, 10)}.json`
    a.click()
    URL.revokeObjectURL(a.href)
    setMessage('Backup exported. Import it in the Fidel iOS app or another browser to continue there.')
  }
  const importFile = async (file: File | undefined) => {
    if (!file) return
    try {
      await actions.importBackup(await file.text())
      setMessage('Backup imported and merged with your progress.')
    } catch (e) {
      setMessage(e instanceof BackupError ? e.message : 'That file could not be read as a Fidel backup.')
    }
  }

  const metrics = [
    ['Total XP', p.totalXP],
    ['Day streak', p.currentStreak],
    ['Lessons', p.lessonsCompleted.length],
    ['Words', p.vocabularyMastered.length],
    ['Characters', p.fidelCharactersRecognized.length],
    ['Traced', traced],
  ] as const

  return (
    <div class="stack">
      <ScreenHeader title="You" amharic="አንተ" subtitle="Your learning record, pace, achievements and backups. Stored only in this browser." />

      <section class="card row">
        <Ring value={levelProgress(p)} size={96} stroke={9} color="var(--gold)" label={`Level ${level(p)}, ${p.totalXP % 100} of 100 XP to next level`}>
          <div class="muted" style={{ fontSize: 12 }}>LV</div>
          <strong style={{ fontSize: 26 }}>{level(p)}</strong>
        </Ring>
        <div>
          <p style={{ margin: 0, fontWeight: 600 }}><Icon name="flame" /> {p.currentStreak}-day streak · best {p.longestStreak}</p>
          <p class="secondary" style={{ margin: '4px 0 0' }}>{p.streakFreezesAvailable} streak freeze{p.streakFreezesAvailable === 1 ? '' : 's'} ready</p>
        </div>
      </section>

      <div class="grid-2 grid-3">
        {metrics.map(([label, value]) => (
          <div key={label} class="card"><div class="muted" style={{ fontSize: 13 }}>{label}</div><strong style={{ fontSize: 24 }}>{value}</strong></div>
        ))}
      </div>

      <h2 class="section-label">Pace</h2>
      <div class="list" role="radiogroup" aria-label="Daily pace">
        {(Object.keys(tiers) as Tier[]).map((t) => (
          <button key={t} class="list-item" role="radio" aria-checked={s.dailyGoalTier === t}
            onClick={() => actions.updateSettings({ dailyGoalTier: t, dailyXPGoal: tiers[t].suggestedDailyXP })}>
            <span class="grow"><span class="title">{tiers[t].displayName}</span><br /><span class="sub">{tierSubtitle(t)}</span></span>
            {s.dailyGoalTier === t && <Icon name="check" label="Selected" />}
          </button>
        ))}
      </div>

      <h2 class="section-label">Daily goal</h2>
      <section class="card stack">
        <div class="spread"><span>{todayXP(p, new Date())}/{s.dailyXPGoal} XP today</span></div>
        <Bar value={todayXP(p, new Date()) / s.dailyXPGoal} label="Daily goal" />
      </section>

      <h2 class="section-label">Achievements</h2>
      <div class="list">
        {achievements.map((a) => {
          const value = Math.min(a.measure(p), a.requirement)
          return (
            <div key={a.id} class="list-item">
              <span class="grow">
                <span class="title">{a.title}</span><br />
                <span class="sub">{a.description} · {value}/{a.requirement}</span>
                <Bar value={value / a.requirement} label={`${a.title} progress`} />
              </span>
            </div>
          )
        })}
      </div>

      <h2 class="section-label">Backup</h2>
      <section class="card stack">
        <p class="secondary" style={{ margin: 0 }}>The same file format as the iOS app. Move between devices by exporting here and importing there.</p>
        <div class="grid-2">
          <button class="btn secondary" onClick={exportFile}><Icon name="upload" /> Export</button>
          <label class="btn secondary">
            <Icon name="download" /> Import
            <input type="file" accept="application/json,.json" class="visually-hidden" onChange={(e) => void importFile(e.currentTarget.files?.[0])} />
          </label>
        </div>
        {message && <p role="status" style={{ margin: 0 }}>{message}</p>}
      </section>

      <h2 class="section-label">Offline</h2>
      <section class="card stack">
        <p class="secondary" style={{ margin: 0 }}>
          Lessons and practice work offline once loaded. Audio downloads as you listen; download everything (about 42 MB) to hear every clip offline.
        </p>
        {download && download.done < download.total ? (
          <Bar value={download.done / download.total} label="Audio download" />
        ) : (
          <button class="btn secondary" onClick={() => void downloadAllAudio((done, total) => setDownload({ done, total }))}>
            <Icon name="download" /> {download ? 'All audio downloaded' : 'Download all audio'}
          </button>
        )}
      </section>
    </div>
  )
}
