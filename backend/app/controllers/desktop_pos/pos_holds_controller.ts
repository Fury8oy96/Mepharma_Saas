import { HttpContext } from '@adonisjs/core/http'
import SalesHold from '#models/tenant/sales_hold'

export default class PosHoldsController {
  async index({ response }: HttpContext) {
    const holds = await SalesHold.query().orderBy('id', 'desc')
    return response.ok(holds)
  }

  async store({ request, response }: HttpContext) {
    const { reference, customer_id, customer_name, items, notes } = request.all()
    const hold = await SalesHold.create({
      reference: reference || `HOLD-${Date.now()}`,
      customerId: customer_id || null,
      customerName: customer_name || null,
      items: items || [],
      notes: notes || null,
    })
    return response.status(201).json(hold)
  }

  async destroy({ params, response }: HttpContext) {
    const hold = await SalesHold.query().where('id', params.id).first()
    if (!hold) {
      return response.status(404).json({ error: 'Hold not found.' })
    }
    await hold.delete()
    return response.ok({ success: true })
  }
}
