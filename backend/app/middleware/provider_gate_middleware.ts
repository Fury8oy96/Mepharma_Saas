import { HttpContext } from '@adonisjs/core/http'
import jwt from 'jsonwebtoken'
import env from '#start/env'

export default class ProviderGateMiddleware {
  async handle(ctx: HttpContext, next: () => Promise<void>) {
    const authHeader = ctx.request.header('authorization')
    const token = authHeader?.replace(/^Bearer\s+/i, '') || ctx.session?.get('provider_token')

    if (!token) {
      return ctx.response.status(401).json({
        error: 'Unauthorized',
        message: 'Authentication token required to access Provider Superadmin Control Plane.',
      })
    }

    try {
      const secret = env.get('JWT_SECRET') || env.get('APP_KEY')
      const decoded = jwt.verify(token, secret) as any
      ;(ctx as any).authUser = decoded

      const role = (decoded.role || '').toLowerCase()
      if (role !== 'super_admin') {
        return ctx.response.status(403).json({
          error: 'Access Forbidden',
          message: 'Provider Superadmin privileges required.',
        })
      }

      return await next()
    } catch {
      return ctx.response.status(401).json({
        error: 'Unauthorized',
        message: 'Invalid or expired session token.',
      })
    }
  }
}
