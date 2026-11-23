import type { ComponentChildren } from 'preact'
import { href, route } from './router'
import { Icon } from './ui'
import { Today } from './screens/Today'
import { Learn } from './screens/Learn'
import { LessonDetail } from './screens/LessonDetail'
import { ConversationDetail, Conversations } from './screens/Conversations'
import { Practice, PracticeMode } from './screens/Practice'
import { Reference } from './screens/Reference'
import { Selam } from './screens/Selam'
import { You } from './screens/You'

const tabs = [
  { id: '', label: 'Today', icon: 'sun' },
  { id: 'learn', label: 'Learn', icon: 'map' },
  { id: 'practice', label: 'Practice', icon: 'stack' },
  { id: 'selam', label: 'Selam', icon: 'chat' },
  { id: 'you', label: 'You', icon: 'person' },
]

const tabFor = (first = ''): string =>
  ({ lesson: 'learn', conversations: 'learn', conversation: 'learn', reference: '', trace: 'practice' })[first] ?? first

function Screen(): ComponentChildren {
  const [first = '', second, third] = route.value
  switch (first) {
    case '': return <Today />
    case 'learn': return <Learn />
    case 'lesson': return <LessonDetail id={Number(second)} />
    case 'conversations': return <Conversations />
    case 'conversation': return <ConversationDetail id={Number(second)} />
    case 'practice': return second ? <PracticeMode mode={second} arg={third} /> : <Practice />
    case 'reference': return <Reference tab={second} />
    case 'selam': return <Selam />
    case 'you': return <You />
    default: return <Today />
  }
}

export function App() {
  const active = tabFor(route.value[0])
  return (
    <div class="shell">
      <nav class="tabs" aria-label="Main">
        <span class="brand">Fidel <span lang="am" class="am">ፊደል</span></span>
        {tabs.map((t) => (
          <a key={t.id} href={href(t.id)} aria-current={active === t.id ? 'page' : undefined}>
            <Icon name={t.icon} />
            <span>{t.label}</span>
          </a>
        ))}
      </nav>
      <main class="screen" id="main">
        <Screen />
      </main>
    </div>
  )
}
