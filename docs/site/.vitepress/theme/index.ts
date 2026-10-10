import DefaultTheme from 'vitepress/theme'
import { inject } from '@vercel/analytics'
import './style.css'

export default {
  extends: DefaultTheme,
  enhanceApp() {
    if (typeof window === 'undefined' || window.location.hostname !== 'doclin.dev') return
    inject({
      mode: 'production',
      beforeSend(event) {
        // Website routes only; do not send query strings or fragment contents.
        const url = new URL(event.url)
        url.search = ''
        url.hash = ''
        return { ...event, url: url.toString() }
      }
    })
  }
}
