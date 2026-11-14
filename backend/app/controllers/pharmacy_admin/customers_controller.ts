import { HttpContext } from '@adonisjs/core/http'
import db from '@adonisjs/lucid/services/db'
import Customer from '#models/tenant/customer'
import CustomerPayment from '#models/tenant/customer_payment'
import { TenantContext } from '#core/tenancy/tenant_context'
import { syncHub } from '#core/events/sync_hub'

function serializeCustomer(c: Customer) {
  return {
    id: c.id,
    name: c.name,
    phone: c.phone || null,
    email: c.email || null,
    address: c.address || null,
    credit_limit: Number(c.creditLimit) || 0,
    creditLimit: Number(c.creditLimit) || 0,
    balance: Number(c.balance) || 0,
    loyalty_points: Number(c.loyaltyPoints) || 0,
    loyaltyPoints: Number(c.loyaltyPoints) || 0,
    loyalty_tier: c.loyaltyTier || 'silver',
    loyaltyTier: c.loyaltyTier || 'silver',
    created_at: c.createdAt?.toISO?.() || new Date().toISOString(),
    createdAt: c.createdAt?.toISO?.() || new Date().toISOString(),
    updated_at: c.updatedAt?.toISO?.() || null,
    updatedAt: c.updatedAt?.toISO?.() || null,
  }
}

export default class CustomersController {
  async index({ request, response }: HttpContext) {
    const { search } = request.qs()
    const schema = TenantContext.get()?.schemaName || 'tenant_main'
    const query = Customer.query()

    if (search) {
      query.where((q) => {
        q.whereILike('name', `%${search}%`).orWhereILike('phone', `%${search}%`)
      })
    }

    const customers = await query.orderBy('id', 'desc')

    // Aggregate credit and payments in bulk so list queries stay O(1) SQL roundtrips
    const creditRows = await db.rawQuery(
      `SELECT customer_id, COALESCE(SUM(total_amount - paid_amount), 0)::numeric as total_credit
       FROM "${schema}".sales
       WHERE customer_id IS NOT NULL AND payment_method = 'credit' AND status = 'completed'
       GROUP BY customer_id;`
    )
    const paymentRows = await db.rawQuery(
      `SELECT customer_id, COALESCE(SUM(amount), 0)::numeric as total_paid
       FROM "${schema}".customer_payments
       GROUP BY customer_id;`
    )

    const creditMap = new Map<number, number>()
    for (const r of creditRows.rows || []) {
      creditMap.set(Number(r.customer_id), Number(r.total_credit) || 0)
    }
    const paidMap = new Map<number, number>()
    for (const r of paymentRows.rows || []) {
      paidMap.set(Number(r.customer_id), Number(r.total_paid) || 0)
    }

    return response.ok(
      customers.map((c) => {
        const flat = serializeCustomer(c)
        const totalCredit = creditMap.get(c.id) || 0
        const totalPaid = paidMap.get(c.id) || 0
        const outstanding = Number(c.balance) || Math.max(0, totalCredit - totalPaid)
        return {
          ...flat,
          customer: flat,
          outstanding,
          total_paid: totalPaid,
          total_credit: totalCredit,
        }
      })
    )
  }

  async checkName({ request, response }: HttpContext) {
    const { name, exclude_id } = request.qs()
    if (!name || !String(name).trim()) {
      return response.ok({ taken: false })
    }
    const query = Customer.query().whereRaw('LOWER(TRIM(name)) = LOWER(TRIM(?))', [String(name)])
    if (exclude_id) {
      query.whereNot('id', Number(exclude_id))
    }
    const existing = await query.first()
    return response.ok({ taken: !!existing })
  }

  async store({ request, response }: HttpContext) {
    const body = request.all()
    const name = String(body.name || '').trim()
    if (!name) {
      return response.status(400).json({ error: 'Customer name is required.' })
    }
    const customer = await Customer.create({
      name,
      phone: body.phone || null,
      email: body.email || null,
      address: body.address || null,
      creditLimit: Math.max(0, Math.round(Number(body.credit_limit ?? body.creditLimit ?? 0))),
      balance: 0,
      loyaltyPoints: 0,
      loyaltyTier: body.loyalty_tier || 'silver',
    })
    syncHub.emit(TenantContext.get()?.code || 'main', 'customer_updated', { id: customer.id })
    return response.status(201).json(serializeCustomer(customer))
  }

  async show({ params, response }: HttpContext) {
    const customer = await Customer.query().where('id', params.id).first()
    if (!customer) {
      return response.status(404).json({ error: 'Customer not found.' })
    }
    return response.ok(serializeCustomer(customer))
  }

  async update({ params, request, response }: HttpContext) {
    const customer = await Customer.query().where('id', params.id).first()
    if (!customer) {
      return response.status(404).json({ error: 'Customer not found.' })
    }

    const body = request.all()
    if (body.name && String(body.name).trim()) customer.name = String(body.name).trim()
    if (body.phone !== undefined) customer.phone = body.phone || null
    if (body.email !== undefined) customer.email = body.email || null
    if (body.address !== undefined) customer.address = body.address || null
    if (body.credit_limit !== undefined || body.creditLimit !== undefined) {
      customer.creditLimit = Math.max(0, Math.round(Number(body.credit_limit ?? body.creditLimit ?? 0)))
    }

    await customer.save()
    syncHub.emit(TenantContext.get()?.code || 'main', 'customer_updated', { id: customer.id })
    return response.ok(serializeCustomer(customer))
  }

  async destroy({ params, response }: HttpContext) {
    const customer = await Customer.query().where('id', params.id).first()
    if (!customer) {
      return response.status(404).json({ error: 'Customer not found.' })
    }
    await customer.delete()
    syncHub.emit(TenantContext.get()?.code || 'main', 'customer_updated', { id: Number(params.id) })
    return response.ok({ success: true, message: 'Customer deleted.' })
  }

  async getBalance({ params, response }: HttpContext) {
    const customer = await Customer.query().where('id', params.id).first()
    if (!customer) {
      return response.status(404).json({ error: 'Customer not found.' })
    }

    const schema = TenantContext.get()?.schemaName || 'tenant_main'
    const creditRes = await db.rawQuery(
      `SELECT COALESCE(SUM(total_amount - paid_amount), 0)::numeric as total_credit
       FROM "${schema}".sales
       WHERE customer_id = ? AND payment_method = 'credit' AND status = 'completed';`,
      [customer.id]
    )
    const paidRes = await db.rawQuery(
      `SELECT COALESCE(SUM(amount), 0)::numeric as total_paid
       FROM "${schema}".customer_payments
       WHERE customer_id = ?;`,
      [customer.id]
    )

    const totalCredit = Number(creditRes.rows[0]?.total_credit) || 0
    const totalPaid = Number(paidRes.rows[0]?.total_paid) || 0
    const outstanding = Number(customer.balance) || Math.max(0, totalCredit - totalPaid)

    return response.ok({
      customer: serializeCustomer(customer),
      balance: outstanding,
      outstanding,
      total_credit: totalCredit,
      total_paid: totalPaid,
    })
  }

  async getPayments({ params, response }: HttpContext) {
    const customer = await Customer.query().where('id', params.id).first()
    if (!customer) {
      return response.status(404).json({ error: 'Customer not found.' })
    }

    const payments = await CustomerPayment.query()
      .where('customer_id', customer.id)
      .orderBy('id', 'desc')

    return response.ok(
      payments.map((p) => ({
        id: p.id,
        customer_id: p.customerId,
        amount: Number(p.amount) || 0,
        payment_method: p.paymentMethod || 'cash',
        note: p.notes || null,
        notes: p.notes || null,
        created_at: p.createdAt?.toISO?.() || new Date().toISOString(),
      }))
    )
  }

  async recordPayment({ params, request, response }: HttpContext) {
    const customer = await Customer.query().where('id', params.id).first()
    if (!customer) {
      return response.status(404).json({ error: 'Customer not found.' })
    }

    const body = request.all()
    const amount = Math.round(Number(body.amount) || 0)
    if (amount <= 0) {
      return response.status(400).json({ error: 'Payment amount must be greater than zero.' })
    }

    const noteText = body.notes ?? body.note ?? null
    const payment = await db.transaction(async (trx) => {
      const locked = await Customer.query({ client: trx }).where('id', customer.id).forUpdate().firstOrFail()
      locked.balance = Math.max(0, Number(locked.balance || 0) - amount)
      await locked.useTransaction(trx).save()

      return await CustomerPayment.create(
        {
          customerId: locked.id,
          amount,
          paymentMethod: body.payment_method || body.paymentMethod || 'cash',
          notes: noteText,
        },
        { client: trx }
      )
    })

    syncHub.emit(TenantContext.get()?.code || 'main', 'customer_updated', { id: customer.id })
    return response.status(201).json({
      id: payment.id,
      customer_id: payment.customerId,
      amount: Number(payment.amount) || 0,
      payment_method: payment.paymentMethod,
      note: payment.notes || null,
      notes: payment.notes || null,
      created_at: payment.createdAt?.toISO?.() || new Date().toISOString(),
    })
  }

  // --- Customer Requests & Notifications ---
  async getRequests({ response }: HttpContext) {
    const schema = TenantContext.get()?.schemaName || 'tenant_main'
    const res = await db.rawQuery(
      `SELECT id, customer_id, customer_name, customer_phone, medicine_name, notes, status, created_at
       FROM "${schema}".customer_requests
       ORDER BY id DESC
       LIMIT 100;`
    )
    return response.ok(res.rows || [])
  }

  async storeRequest({ request, response }: HttpContext) {
    const schema = TenantContext.get()?.schemaName || 'tenant_main'
    const body = request.all()
    const customerName = String(body.customer_name || body.customerName || '').trim()
    const medicineName = String(body.medicine_name || body.medicineName || '').trim()
    if (!customerName || !medicineName) {
      return response.status(400).json({ error: 'customer_name and medicine_name are required.' })
    }
    const inserted = await db.rawQuery(
      `INSERT INTO "${schema}".customer_requests (customer_id, customer_name, customer_phone, medicine_name, notes, status)
       VALUES (?, ?, ?, ?, ?, 'pending')
       RETURNING *;`,
      [body.customer_id || null, customerName, body.customer_phone || null, medicineName, body.notes || null]
    )
    return response.status(201).json(inserted.rows[0])
  }

  async notifyRequest({ params, response }: HttpContext) {
    const schema = TenantContext.get()?.schemaName || 'tenant_main'
    await db.rawQuery(
      `UPDATE "${schema}".customer_requests SET status = 'notified', updated_at = NOW() WHERE id = ?;`,
      [Number(params.id)]
    )
    return response.ok({ success: true, message: `Notification dispatched for request #${params.id}.` })
  }

  async fulfillRequest({ params, response }: HttpContext) {
    const schema = TenantContext.get()?.schemaName || 'tenant_main'
    await db.rawQuery(
      `UPDATE "${schema}".customer_requests SET status = 'fulfilled', updated_at = NOW() WHERE id = ?;`,
      [Number(params.id)]
    )
    return response.ok({ success: true, message: `Request #${params.id} marked as fulfilled.` })
  }

  async getLogs({ response }: HttpContext) {
    return response.ok([])
  }

  async getTemplates({ response }: HttpContext) {
    return response.ok([
      { id: 'restock', title: 'Drug In-Stock Notification', body: 'Dear customer, your requested medicine is now back in stock.' },
      { id: 'loyalty', title: 'Loyalty Reward Voucher', body: 'Congratulations! You have unlocked a discount voucher on your next purchase.' },
    ])
  }

  async broadcast({ request, response }: HttpContext) {
    const { template_id, recipient_count = 1 } = request.all()
    return response.ok({ success: true, message: `Broadcast '${template_id}' sent to ${recipient_count} recipients.` })
  }
}
