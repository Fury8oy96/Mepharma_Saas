import { HttpContext } from '@adonisjs/core/http'
import Terminal from '#models/core/terminal'
import { DateTime } from 'luxon'

export default class TerminalSeatMiddleware {
  async handle(ctx: HttpContext, next: () => Promise<void>) {
    const hardwareUuid = ctx.request.header('x-terminal-hardware-id')
    const terminalName = ctx.request.header('x-terminal-name') || 'Counter Terminal'
    const tenant = (ctx as any).tenant

    // Terminal seat enforcement applies to tenant counter endpoints
    if (!tenant) {
      return await next()
    }

    if (!hardwareUuid) {
      return ctx.response.status(400).json({
        error: 'Terminal Hardware Identifier Required',
        code: 'MISSING_TERMINAL_HARDWARE_ID',
        message:
          'A unique hardware terminal identifier (x-terminal-hardware-id header) is required to authenticate desktop POS counter terminals.',
      })
    }

    let terminal = await Terminal.query()
      .where('tenant_id', tenant.id)
      .where('hardware_uuid', hardwareUuid)
      .first()

    if (!terminal) {
      const activeCount = await Terminal.query()
        .where('tenant_id', tenant.id)
        .where('is_active', true)
        .count('* as total')

      const currentTotal = Number(activeCount[0].$extras.total)
      const allowedMax = tenant.maxTerminals || 1

      if (currentTotal >= allowedMax) {
        return ctx.response.status(402).json({
          error: 'Terminal License Limit Exceeded',
          code: 'TERMINAL_QUOTA_REACHED',
          message: `This pharmacy has reached its licensed limit of ${allowedMax} active desktop terminals. Please contact provider administration to upgrade terminal seats.`,
        })
      }

      terminal = await Terminal.create({
        tenantId: tenant.id,
        hardwareUuid,
        name: terminalName,
        isActive: true,
        lastSeenAt: DateTime.now(),
      })
    } else {
      terminal.lastSeenAt = DateTime.now()
      await terminal.save()
    }

    ;(ctx as any).terminal = terminal
    return await next()
  }
}
