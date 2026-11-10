import { defineConfig } from '@adonisjs/cors'

const corsConfig = defineConfig({
  enabled: true,
  origin: true,
  methods: ['GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  headers: true,
  exposeHeaders: [
    'X-Pharmacy-Code',
    'X-Terminal-Hardware-ID',
    'X-Terminal-Name',
    'X-Idempotency-Key',
  ],
  credentials: true,
  maxAge: 90,
})

export default corsConfig
