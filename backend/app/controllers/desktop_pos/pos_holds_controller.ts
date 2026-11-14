import { HttpContext } from '@adonisjs/core/http'
import SalesHold from '#models/tenant/sales_hold'

function serializeHold(h: SalesHold) {
  const itemsArr = Array.isArray(h.items) ? h.items : []
  return {
    id: h.id,
    reference: h.reference,
    hold_number: h.reference,
    user_id: h.userId || 0,
    customer_id: h.customerId || null,
    customer_name: h.customerName || null,
    items: itemsArr,
    items_json: JSON.stringify(itemsArr),
    subtotal: Number(h.subtotal) || 0,
    discount: Number(h.discount) || 0,
    discount_type: h.discountType || null,
    total_amount: Number(h.totalAmount) || 0,
    notes: h.notes || null,
    created_at: h.createdAt?.toISO?.() || new Date().toISOString(),
  }
}

export default class PosHoldsController {
  async index({ response }: HttpContext) {
    const holds = await SalesHold.query().orderBy('id', 'desc')
    return response.ok(holds.map(serializeHold))
  }

  async store({ request, response, authUser }: HttpContext & { authUser?: any }) {
    const body = request.all()
    const rawItems = body.items ?? body.items_json ?? []
    let parsedItems: any[] = []
    if (typeof rawItems === 'string') {
      try {
        const decoded = JSON.parse(rawItems)
        if (Array.isArray(decoded)) parsedItems = decoded
      } catch {
        parsedItems = []
      }
    } else if (Array.isArray(rawItems)) {
      parsedItems = rawItems
    }

    const reference =
      body.reference ||
      body.hold_number ||
      `HOLD-${Date.now().toString().slice(-6)}-${Math.floor(100 + Math.random() * 900)}`

    const hold = await SalesHold.create({
      reference,
      userId: Number(body.user_id || authUser?.id || 0) || null,
      customerId: body.customer_id ? Number(body.customer_id) : null,
      customerName: body.customer_name || null,
      items: parsedItems,
      subtotal: Math.max(0, Math.round(Number(body.subtotal) || 0)),
      discount: Math.max(0, Math.round(Number(body.discount) || 0)),
      discountType: body.discount_type || null,
      totalAmount: Math.max(0, Math.round(Number(body.total_amount) || 0)),
      notes: body.notes || null,
    })

    return response.status(201).json(serializeHold(hold))
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
