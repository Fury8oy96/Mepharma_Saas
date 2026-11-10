import { HttpContext } from '@adonisjs/core/http'
import jwt from 'jsonwebtoken'
import env from '#start/env'

export default class AuthJwtMiddleware {
  async handle(ctx: HttpContext, next: () => Promise<void>) {
    const authHeader = ctx.request.header('authorization')
    const token = authHeader?.replace(/^Bearer\s+/i, '')

    if (!token) {
      return ctx.response.status(401).json({
        error: 'Unauthorized',
        message: 'Missing Bearer token.',
      })
    }

    try {
      const secret = env.get('JWT_SECRET') || env.get('APP_KEY')
      const decoded = jwt.verify(token, secret) as any
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
