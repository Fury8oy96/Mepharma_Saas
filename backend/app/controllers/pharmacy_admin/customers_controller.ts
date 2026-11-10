import { HttpContext } from '@adonisjs/core/http'
import Customer from '#models/tenant/customer'

export default class CustomersController {
  async index({ request, response }: HttpContext) {
    const { search } = request.qs()
    const query = Customer.query()

    if (search) {
      query.where((q) => {
        q.whereILike('name', `%${search}%`)
          .orWhereILike('phone', `%${search}%`)
      })
    }

    const customers = await query.orderBy('id', 'desc')
    return response.ok(customers)
  }

  async store({ request, response }: HttpContext) {
    const { name, phone, email, address, credit_limit = 0 } = request.all()
    const customer = await Customer.create({
      name,
      phone,
      email,
      address,
      creditLimit: Number(credit_limit) || 0,
      balance: 0,
      loyaltyPoints: 0,
      loyaltyTier: 'silver',
    })
    return response.status(201).json(customer)
  }

  async show({ params, response }: HttpContext) {
    const customer = await Customer.query().where('id', params.id).first()
    if (!customer) {
      return response.status(404).json({ error: 'Customer not found.' })
    }
    return response.ok(customer)
  }

  async update({ params, request, response }: HttpContext) {
    const customer = await Customer.query().where('id', params.id).first()
    if (!customer) {
      return response.status(404).json({ error: 'Customer not found.' })
    }

    const { name, phone, email, address, credit_limit } = request.all()
    if (name) customer.name = name
    if (phone !== undefined) customer.phone = phone
    if (email !== undefined) customer.email = email
    if (address !== undefined) customer.address = address
    if (credit_limit !== undefined) customer.creditLimit = Number(credit_limit)

    await customer.save()
    return response.ok(customer)
  }

  async destroy({ params, response }: HttpContext) {
    const customer = await Customer.query().where('id', params.id).first()
    if (!customer) {
      return response.status(404).json({ error: 'Customer not found.' })
    }
    await customer.delete()
    return response.ok({ success: true, message: 'Customer deleted.' })
  }

  // --- Customer Requests & Notifications Stubs ---
  async getRequests({ response }: HttpContext) {
    return response.ok([])
  }

  async notifyRequest({ params, response }: HttpContext) {
    return response.ok({ success: true, message: `Notification dispatched for request #${params.id}.` })
  }

  async fulfillRequest({ params, response }: HttpContext) {
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
