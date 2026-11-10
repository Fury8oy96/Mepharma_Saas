import { HttpContext } from '@adonisjs/core/http'
import db from '@adonisjs/lucid/services/db'

export async function logAuditEvent(
  actor: string,
  action: string,
  entityType: string,
  entityId: string,
  details: any = {},
  ip: string = '127.0.0.1'
) {
  try {
    await db.rawQuery(
      `INSERT INTO public.audit_logs (actor_username, action, entity_type, entity_id, details, ip_address)
       VALUES (?, ?, ?, ?, ?::jsonb, ?)`,
      [actor, action, entityType, entityId, JSON.stringify(details), ip]
    )
  } catch (err) {
    console.error('Failed to write audit log:', err)
  }
}

export default class AuditLogsController {
  async index({ request, response }: HttpContext) {
    const { action, search, limit = 50 } = request.qs()

    let query = 'SELECT * FROM public.audit_logs WHERE 1=1'
    const bindings: any[] = []

    if (action) {
      query += ' AND action = ?'
      bindings.push(action)
    }

    if (search) {
      query += ' AND (actor_username ILIKE ? OR entity_id ILIKE ? OR action ILIKE ?)'
      const term = `%${search}%`
      bindings.push(term, term, term)
    }

    query += ' ORDER BY created_at DESC LIMIT ?'
    bindings.push(Number(limit) || 50)

    const res = await db.rawQuery(query, bindings)
    return response.ok(res.rows || [])
  }
}
