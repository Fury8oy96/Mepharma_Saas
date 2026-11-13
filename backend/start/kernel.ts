import router from '@adonisjs/core/services/router'
import server from '@adonisjs/core/services/server'

/**
 * Global server middleware stack (runs on every request)
 */
server.use([
  () => import('@adonisjs/static/static_middleware'),
  () => import('@adonisjs/cors/cors_middleware'),
])

/**
 * Router middleware stack (runs on routes matched by the router)
 */
router.use([
  () => import('@adonisjs/core/bodyparser_middleware'),
  () => import('@adonisjs/session/session_middleware'),
  () => import('@adonisjs/shield/shield_middleware'),
  () => import('#middleware/tenant_identification_middleware'),
])

/**
 * Named middlewares
 */
export const middleware = router.named({
  webGate: () => import('#middleware/web_dashboard_gate_middleware'),
  providerGate: () => import('#middleware/provider_gate_middleware'),
  terminalSeat: () => import('#middleware/terminal_seat_middleware'),
  authJwt: () => import('#middleware/auth_jwt_middleware'),
})
