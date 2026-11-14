import { HttpContext } from '@adonisjs/core/http'
import jwt from 'jsonwebtoken'
import { getJwtSecret } from '#core/security/jwt_secret'

export default class AuthJwtMiddleware {
  async handle(ctx: HttpContext, next: () => Promise<void>) {
    const authHeader = ctx.request.header('authorization')
    const token = authHeader?.replace(/^Bearer\s+/i, '').trim()

    if (!token) {
      return ctx.response.status(401).json({
        error: 'Unauthorized',
        message: 'Missing Bearer token.',
      })
    }

    try {
      const decoded = jwt.verify(token, getJwtSecret()) as any
      const url = ctx.request.url()
      const tenant = (ctx as any).tenant

      if (url.startsWith('/provider')) {
        if (!decoded.isProviderAdmin) {
          return ctx.response.status(403).json({
            error: 'Access Forbidden',
            message: 'Provider control plane requires provider administrator credentials.',
          })
        }
      } else {
        if (decoded.isProviderAdmin) {
          return ctx.response.status(403).json({
            error: 'Access Forbidden',
            message: 'Provider control plane tokens cannot authenticate tenant endpoints.',
          })
        }
        if (tenant && decoded.pharmacyCode && decoded.pharmacyCode !== tenant.code) {
          return ctx.response.status(403).json({
            error: 'Tenant Mismatch',
            code: 'TENANT_MISMATCH',
            message: 'Authentication token belongs to a different pharmacy tenant.',
          })
        }
      }

      ;(ctx as any).authUser = decoded
      return await next()
    } catch {
      return ctx.response.status(401).json({
        error: 'Unauthorized',
        message: 'Invalid or expired authentication token.',
      })
    }
  }
}
