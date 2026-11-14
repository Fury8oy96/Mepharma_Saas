import { Response } from '@adonisjs/core/http'

interface SseClient {
  id: string
  tenantCode: string
  response: Response
  heartbeat: NodeJS.Timeout
}

class SyncHubService {
  private clients = new Map<string, SseClient>()

  subscribe(tenantCode: string, response: Response, onClose?: () => void) {
    const id = `${tenantCode}_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`
    const res = response.response

    res.setHeader('Content-Type', 'text/event-stream; charset=utf-8')
    res.setHeader('Cache-Control', 'no-cache, no-transform')
    res.setHeader('Connection', 'keep-alive')
    res.setHeader('X-Accel-Buffering', 'no')
    res.flushHeaders?.()

    res.write(`event: connected\ndata: ${JSON.stringify({ tenant: tenantCode, timestamp: new Date().toISOString() })}\n\n`)

    const heartbeat = setInterval(() => {
      try {
        res.write(`: heartbeat ${Date.now()}\n\n`)
      } catch {
        this.unsubscribe(id)
      }
    }, 25000)

    const client: SseClient = { id, tenantCode, response, heartbeat }
    this.clients.set(id, client)

    const cleanup = () => {
      this.unsubscribe(id)
      onClose?.()
    }

    res.on('close', cleanup)
    res.on('error', cleanup)

    return () => this.unsubscribe(id)
  }

  unsubscribe(id: string) {
    const client = this.clients.get(id)
    if (!client) return
    clearInterval(client.heartbeat)
    this.clients.delete(id)
  }

  emit(tenantCode: string, event: string, data: Record<string, any> = {}) {
    const payload = JSON.stringify({
      ...data,
      tenant: tenantCode,
      timestamp: new Date().toISOString(),
    })

    for (const [id, client] of this.clients.entries()) {
      if (client.tenantCode !== tenantCode) continue
      try {
        client.response.response.write(`event: ${event}\ndata: ${payload}\n\n`)
      } catch {
        this.unsubscribe(id)
      }
    }
  }
}

export const syncHub = new SyncHubService()

