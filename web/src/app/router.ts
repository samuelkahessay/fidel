// Hash routing, so deep links work on GitHub Pages without server rewrites.
import { signal } from '@preact/signals'

export const route = signal(parse())

function parse(): string[] {
  return location.hash.replace(/^#\/?/, '').split('/').filter(Boolean).map(decodeURIComponent)
}

addEventListener('hashchange', () => {
  route.value = parse()
  window.scrollTo(0, 0)
})

export const navigate = (...parts: (string | number)[]) => {
  location.hash = `#/${parts.map((p) => encodeURIComponent(String(p))).join('/')}`
}
export const href = (...parts: (string | number)[]) => `#/${parts.map((p) => encodeURIComponent(String(p))).join('/')}`
export const back = () => (history.length > 1 ? history.back() : navigate())
