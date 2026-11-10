import { HttpContext } from '@adonisjs/core/http'
import Return from '#models/tenant/return'
import Product from '#models/tenant/product'
import db from '@adonisjs/lucid/services/db'

export default class PosReturnsController {
  async index({ response }: HttpContext) {
    const returns = await Return.query().orderBy('id', 'desc')
    return response.ok(returns)
  }

  async store({ request, response, authUser }: HttpContext) {
    const { sale_id, return_number, items, reason, total_refund } = request.all()

    return await db.transaction(async (trx) => {
      // Re-increment returned product stock
      for (const item of items) {
        const product = await Product.query({ client: trx }).where('id', item.product_id).first()
        if (product) {
          product.stockQuantity += item.quantity
          product.version += 1
          await product.useTransaction(trx).save()
        }
      }

      const returnRecord = await Return.create({
        returnNumber: return_number || `RET-${Date.now()}`,
        saleId: sale_id || null,
        userId: authUser?.id || null,
        totalRefund: total_refund || 0,
        reason: reason || null,
      }, { client: trx })

      return response.status(201).json(returnRecord)
    })
  }
}
