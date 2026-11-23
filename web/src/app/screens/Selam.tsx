import { appStoreUrl } from '../links'
import { href } from '../router'
import { Icon, ScreenHeader } from '../ui'

/** Selam runs on Apple's on-device model, so the web points to the iOS app (decided in web/PARITY.md). */
export function Selam() {
  return (
    <div class="stack">
      <ScreenHeader title="Selam" amharic="ሰላም" subtitle="Your conversational Amharic tutor." />
      <section class="card stack">
        <p style={{ margin: 0 }}>
          Selam is a tutor you can ask about Amharic words, grammar and letters. It runs entirely on Apple's on-device
          model, so your questions never leave your phone and there's no account or API key. That model only exists on
          Apple devices with Apple Intelligence, so Selam lives in the iOS app.
        </p>
        <p class="secondary" style={{ margin: 0 }}>
          Selam explains in English and quotes Amharic only from Fidel's own curriculum, so it never makes words up.
        </p>
        <a class="btn primary" href={appStoreUrl} rel="noopener">Get Fidel on the App Store</a>
      </section>
      <section class="card stack">
        <h2 style={{ margin: 0, fontSize: 18 }}>Meanwhile, on the web</h2>
        <a class="list-item" href={href('reference', 'vocabulary')}><span class="grow">Look up a word</span><Icon name="chevron" /></a>
        <a class="list-item" href={href('practice', 'grammar')}><span class="grow">Read the grammar notes</span><Icon name="chevron" /></a>
        <a class="list-item" href={href('conversations')}><span class="grow">Practice a conversation</span><Icon name="chevron" /></a>
      </section>
    </div>
  )
}
