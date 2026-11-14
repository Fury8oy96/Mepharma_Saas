import { HttpContext } from '@adonisjs/core/http'

interface RateBucket {
  count: number
  resetAt: number
}

const DEFAULT_WINDOW_MS = 60_000
const DEFAULT_API_LIMIT = Math.max(20, Number(process.env.API_RATE_LIMIT_MAX || 120))
const DEFAULT_AUTH_LIMIT = Math.max(5, Number(process.env.AUTH_RATE_LIMIT_MAX || 25))
const MAX_BUCKETS = 10_000

export class InMemoryRateLimiter {
  private buckets = new Map<string, RateBucket>()
  private readonly windowMs: number

  constructor(windowMs = DEFAULT_WINDOW_MS) {
    this.windowMs = windowMs
  }

  consume(key: string, limit: number, now = Date.now()): {
    allowed: boolean
    limit: number
    remaining: number
    resetAt: number
    retryAfterSeconds: number
  } {
    if (this.buckets.size >= MAX_BUCKETS) {
      for (const [k, v] of this.buckets) {
        if (now >= v.resetAt) {
          this.buckets.delete(k)
        }
      }
      if (this.buckets.size >= MAX_BUCKETS) {
        const oldestKey = this.buckets.keys().next().value
        if (oldestKey !== undefined) {
          this.buckets.delete(oldestKey)
        }
      }
    }

    let bucket = this.buckets.get(key)
    if (!bucket || now >= bucket.resetAt) {
      bucket = { count: 0, resetAt: now + this.windowMs }
      this.buckets.set(key, bucket)
    }

    bucket.count += 1
    const remaining = Math.max(0, limit - bucket.count)
    const allowed = bucket.count <= limit
    const retryAfterSeconds = Math.max(1, Math.ceil((bucket.resetAt - now) / 1000))

    return {
      allowed,
      limit,
      remaining,
      resetAt: bucket.resetAt,
      retryAfterSeconds,
    }
  }

  clear() {
    this.buckets.clear()
  }
}

export const globalRateLimiter = new InMemoryRateLimiter(DEFAULT_WINDOW_MS)

export default class RateLimitMiddleware {
  async handle(ctx: HttpContext, next: () => Promise<void>) {
    const url = ctx.request.url()

    // Skip rate limit for health checks and long-lived SSE stream
    if (
      url === '/health' ||
      url === '/api/health' ||
      url === '/status' ||
      url === '/api/status' ||
      url.startsWith('/sync/events') ||
      url.startsWith('/api/sync/events')
    ) {
      return await next()
    }

    const isAuthRoute =
      url.endsWith('/auth/login') ||
      url.endsWith('/pos/activate-license') ||
      url.endsWith('/activate-license')

    const limit = isAuthRoute ? DEFAULT_AUTH_LIMIT : DEFAULT_API_LIMIT
    const ip = ctx.request.ip() || 'unknown'
    const tenantCode = String(ctx.request.header('x-pharmacy-code') || 'default').toLowerCase()
    const bucketKey = isAuthRoute ? `auth:${ip}:${url}` : `api:${ip}:${tenantCode}`

    const result = globalRateLimiter.consume(bucketKey, limit)

    ctx.response.header('X-RateLimit-Limit', String(result.limit))
    ctx.response.header('X-RateLimit-Remaining', String(result.remaining))
    ctx.response.header('X-RateLimit-Reset', String(Math.ceil(result.resetAt / 1000)))

    if (!result.allowed) {
      ctx.response.header('Retry-After', String(result.retryAfterSeconds))
      return ctx.response.status(429).json({
        error: 'Too Many Requests',
        code: 'RATE_LIMIT_EXCEEDED',
        message: 'Too many requests in a short window. Please wait a moment and try again.',
        retryAfterSeconds: result.retryAfterSeconds,
      })
    }

    return await next()
  }
}

