import { HttpContext } from '@adonisjs/core/http'
import Customer from '#models/tenant/customer'

export default class PosCustomersController {
  async index({ request, response }: HttpContext) {
    const { search } = request.qs()
    const query = Customer.query()

    if (search) {
      query.where((q) => {
        q.whereILike('name', `%${search}%`)
          .orWhereILike('phone', `%${search}%`)
      })
    }

    const customers = await query.orderBy('name', 'asc')
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
}
