import { HttpContext } from '@adonisjs/core/http'
import jwt from 'jsonwebtoken'
import { getJwtSecret } from '#core/security/jwt_secret'

export default class ProviderGateMiddleware {
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
      const role = String(decoded.role || '').toLowerCase()

      if (!decoded.isProviderAdmin || !['system_admin', 'super_admin'].includes(role)) {
        return ctx.response.status(403).json({
          error: 'Access Forbidden',
          message: 'Superadmin control plane access required.',
        })
      }

      ;(ctx as any).authUser = decoded
      return await next()
    } catch {
      return ctx.response.status(401).json({
        error: 'Unauthorized',
        message: 'Invalid or expired provider administrator token.',
      })
    }
  }
}

