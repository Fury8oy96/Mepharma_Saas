import { defineConfig } from '@adonisjs/shield'

export default defineConfig({
  csp: {
    enabled: false,
  },
  csrf: {
    enabled: false, // REST APIs and SPAs authenticate via JWT/Tokens
    exceptRoutes: ['*'],
  },
  hsts: {
    enabled: true,
    maxAge: '180 days',
  },
  contentTypeSniffing: {
    enabled: true,
  },
  xFrame: {
    enabled: true,
    action: 'SAMEORIGIN',
  },
})
