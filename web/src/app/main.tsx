import { render } from 'preact'
import { registerSW } from 'virtual:pwa-register'
import '../styles/app.css'
import { loadContent } from '../content/content'
import { registerFonts } from '../fonts'
import { App } from './App'
import { Database } from './db'
import { content, hydrate } from './store'

async function start() {
  registerFonts()
  const root = document.getElementById('root')!
  try {
    const [loaded, db] = await Promise.all([loadContent(), Database.open()])
    hydrate(db, await db.load())
    content.value = loaded
    root.innerHTML = ''
    render(<App />, root)
  } catch (error) {
    root.innerHTML = ''
    const p = document.createElement('p')
    p.className = 'loading'
    p.setAttribute('role', 'alert')
    p.textContent = `Fidel couldn't load: ${error instanceof Error ? error.message : String(error)}`
    root.append(p)
  }
}

void start()
if ('serviceWorker' in navigator && import.meta.env.PROD) registerSW({ immediate: true })
