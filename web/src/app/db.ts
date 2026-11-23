// IndexedDB persistence: one record each for progress and settings, plus one
// row per flashcard and per traced character.
import { openDB, type IDBPDatabase } from 'idb'
import type { Settings } from '../logic/backup'
import type { CardProgress } from '../logic/fsrs'
import type { UserProgress } from '../logic/progress'
import type { TraceMastery } from '../logic/trace/session'

export interface Snapshot {
  progress: UserProgress | undefined
  settings: Settings | undefined
  cards: CardProgress[]
  trace: TraceMastery[]
}

const name = 'fidel'

export class Database {
  private constructor(private db: IDBPDatabase) {}

  static async open(): Promise<Database> {
    const db = await openDB(name, 1, {
      upgrade(db) {
        db.createObjectStore('kv')
        db.createObjectStore('cards')
        db.createObjectStore('trace', { keyPath: 'characterId' })
      },
    })
    return new Database(db)
  }

  async load(): Promise<Snapshot> {
    const [progress, settings, cards, trace] = await Promise.all([
      this.db.get('kv', 'progress'),
      this.db.get('kv', 'settings'),
      this.db.getAll('cards'),
      this.db.getAll('trace'),
    ])
    return { progress, settings, cards, trace }
  }

  saveProgress = (p: UserProgress) => this.db.put('kv', p, 'progress')
  saveSettings = (s: Settings) => this.db.put('kv', s, 'settings')
  saveCard = (c: CardProgress) => this.db.put('cards', c, `${c.itemType}::${c.itemId}`)
  saveTrace = (m: TraceMastery) => this.db.put('trace', m)

  async replaceAll(progress: UserProgress, cards: CardProgress[], settings: Settings) {
    const tx = this.db.transaction(['kv', 'cards'], 'readwrite')
    await Promise.all([
      tx.objectStore('kv').put(progress, 'progress'),
      tx.objectStore('kv').put(settings, 'settings'),
      tx.objectStore('cards').clear(),
    ])
    await Promise.all(cards.map((c) => tx.objectStore('cards').put(c, `${c.itemType}::${c.itemId}`)))
    await tx.done
  }
}
