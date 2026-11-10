import env from '#start/env'
import { defineConfig, stores } from '@adonisjs/session'

export default defineConfig({
  enabled: true,
  cookieName: 'mepharma_session',
  clearWithBrowser: false,
  age: '2h',
  cookie: {
    path: '/',
    httpOnly: true,
    secure: env.get('NODE_ENV') === 'production',
    sameSite: 'lax',
  },
  store: 'cookie',
  stores: {
    cookie: stores.cookie(),
  },
})
