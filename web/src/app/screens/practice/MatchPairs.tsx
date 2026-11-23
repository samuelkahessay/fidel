import { useEffect, useMemo, useState } from 'preact/hooks'
import { type VocabularyWord, wordId } from '../../../content/types'
import { playContent } from '../../audio'
import { actions, requireContent } from '../../store'
import { Result, shuffle, TopBar } from '../../ui'

const pairsPerRound = 5

/** MatchPairsViewModel.dedupedVocabulary: no two tiles share an English meaning or an Amharic spelling. */
function dedupe(vocabulary: VocabularyWord[]): VocabularyWord[] {
  const english = new Set<string>()
  const amharic = new Set<string>()
  return vocabulary.filter((w) => {
    const en = w.english.toLowerCase()
    if (english.has(en) || amharic.has(w.amharic)) return false
    english.add(en)
    amharic.add(w.amharic)
    return true
  })
}

/** MatchPairsViewModel: up to 3 rounds of 5 deduplicated words; 5 XP per pair (masterVocabulary) + 10 for a clean sweep. */
export function MatchPairs() {
  const content = requireContent()
  const [session, setSession] = useState(0)
  const words = useMemo(() => {
    const pool = shuffle(dedupe(content.vocabulary))
    const rounds = Math.max(1, Math.min(3, Math.floor(pool.length / pairsPerRound)))
    return pool.slice(0, rounds * pairsPerRound)
  }, [session])
  const rounds = Math.ceil(words.length / pairsPerRound)
  const [round, setRound] = useState(0)
  const roundWords = words.slice(round * pairsPerRound, (round + 1) * pairsPerRound)
  const columns = useMemo(() => ({ am: shuffle(roundWords), en: shuffle(roundWords) }), [session, round])
  const [selected, setSelected] = useState<{ id: string; am: boolean } | null>(null)
  const [matched, setMatched] = useState<Set<string>>(new Set())
  const [wrong, setWrong] = useState<string[]>([])
  const [total, setTotal] = useState(0)
  const [done, setDone] = useState(false)

  useEffect(() => {
    if (roundWords.length && roundWords.every((w) => matched.has(wordId(w)))) {
      const t = setTimeout(() => {
        if (round + 1 < rounds) { setRound(round + 1); setMatched(new Set()) }
        else {
          if (total === words.length) actions.addXP(10)
          setDone(true)
        }
      }, 450)
      return () => clearTimeout(t)
    }
  }, [matched])

  const restart = () => { setSession(session + 1); setRound(0); setMatched(new Set()); setTotal(0); setDone(false); setSelected(null) }
  if (done) {
    return (
      <div class="stack">
        <TopBar title="Match Pairs" />
        <Result title="All matched" detail={`${total} pairs`} xp={total * 5 + (total === words.length ? 10 : 0)} onAgain={restart} />
      </div>
    )
  }

  const tap = (w: VocabularyWord, am: boolean) => {
    const id = wordId(w)
    if (matched.has(id)) return
    if (am) void playContent('vocabulary', id)
    if (!selected || selected.am === am) return setSelected({ id, am })
    if (selected.id === id) {
      setMatched(new Set(matched).add(id))
      setTotal(total + 1)
      actions.masterVocabulary(id)
    } else {
      setWrong([`${selected.am ? 'am' : 'en'}:${selected.id}`, `${am ? 'am' : 'en'}:${id}`])
      setTimeout(() => setWrong([]), 600)
    }
    setSelected(null)
  }
  const state = (w: VocabularyWord, am: boolean) => {
    const id = wordId(w)
    if (matched.has(id)) return 'matched'
    if (wrong.includes(`${am ? 'am' : 'en'}:${id}`)) return 'wrong'
    if (selected?.id === id && selected.am === am) return 'selected'
    return undefined
  }

  return (
    <div class="stack">
      <TopBar title="Match Pairs"><span class="chip">Round {round + 1}/{rounds}</span></TopBar>
      <p class="secondary" style={{ margin: 0 }}>Tap an Amharic word, then its meaning.</p>
      <div class="grid-2">
        <div class="stack" style={{ gap: 10 }}>
          {columns.am.map((w) => (
            <button key={wordId(w)} class="word-tile" lang="am" data-state={state(w, true)} disabled={matched.has(wordId(w))}
              aria-pressed={state(w, true) === 'selected'} onClick={() => tap(w, true)}>{w.amharic}</button>
          ))}
        </div>
        <div class="stack" style={{ gap: 10 }}>
          {columns.en.map((w) => (
            <button key={wordId(w)} class="word-tile" style={{ fontFamily: 'var(--font)', fontSize: 16 }} data-state={state(w, false)}
              disabled={matched.has(wordId(w))} aria-pressed={state(w, false) === 'selected'} onClick={() => tap(w, false)}>{w.english}</button>
          ))}
        </div>
      </div>
    </div>
  )
}
