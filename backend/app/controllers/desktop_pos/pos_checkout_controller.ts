import { HttpContext } from '@adonisjs/core/http'
import db from '@adonisjs/lucid/services/db'
import Sale from '#models/tenant/sale'
import SaleItem from '#models/tenant/sale_item'
import Product from '#models/tenant/product'

export default class PosCheckoutController {
  async index({ response }: HttpContext) {
    const sales = await Sale.query().preload('items').orderBy('id', 'desc').limit(100)
    return response.ok(sales)
  }

  async show({ params, response }: HttpContext) {
    const sale = await Sale.query()
      .where('id', params.id)
      .preload('items')
      .first()

    if (!sale) {
      return response.status(404).json({ error: 'Sale record not found.' })
    }
    return response.ok(sale)
  }

  async store({ request, response, authUser }: HttpContext) {
    const {
      invoice_number,
      idempotency_key,
      customer_id,
      customer_name,
      items,
      discount = 0,
      discount_type,
      tax_amount = 0,
      paid_amount = 0,
      payment_method = 'cash',
    } = request.all()

    const idempotencyKey = idempotency_key || request.header('x-idempotency-key')

    // 1. Idempotency Check
    if (idempotencyKey) {
      const existing = await Sale.query().where('idempotency_key', idempotencyKey).preload('items').first()
      if (existing) {
        return response.ok(existing)
      }
    }

    if (!items || !Array.isArray(items) || items.length === 0) {
      return response.status(400).json({ error: 'At least one sale item is required.' })
    }

    // 2. Atomic ACID Checkout Transaction with Optimistic Locking
    return await db.transaction(async (trx) => {
      let subtotal = 0
      const saleItemsData: Array<{
        productId: number
        productName: string
        barcode: string | null
        quantity: number
        unitPrice: number
        costPrice: number
        subtotal: number
        discount: number
        total: number
      }> = []

      for (const item of items) {
        const qty = parseInt(item.quantity, 10)
        if (isNaN(qty) || qty <= 0) {
          throw new Error(`Invalid item quantity for product ID ${item.product_id}. Quantity must be a positive integer.`)
        }

        const product = await Product.query({ client: trx })
          .where('id', item.product_id)
          .forUpdate()
          .first()

        if (!product) {
          throw new Error(`Product ID ${item.product_id} was not found.`)
        }

        if (product.stockQuantity < qty) {
          throw new Error(`Insufficient stock for '${product.name}'. Remaining: ${product.stockQuantity}`)
        }

        // Deduct stock & increment concurrency version
        product.stockQuantity -= qty
        product.version += 1
        await product.useTransaction(trx).save()

        const unitPrice = Math.max(0, parseInt(item.unit_price, 10) || product.sellingPrice)
        const lineTotal = unitPrice * qty
        subtotal += lineTotal
        const itemDiscount = Math.max(0, parseInt(item.discount, 10) || 0)

        saleItemsData.push({
          productId: product.id,
          productName: product.name,
          barcode: product.barcode,
          quantity: qty,
          unitPrice,
          costPrice: product.costPrice,
          subtotal: lineTotal,
          discount: itemDiscount,
          total: Math.max(0, lineTotal - itemDiscount),
        })
      }

      const totalAmount = Math.max(0, subtotal - discount + tax_amount)
      const changeAmount = Math.max(0, paid_amount - totalAmount)

      const sale = await Sale.create({
        invoiceNumber: invoice_number || `INV-${Date.now()}`,
        idempotencyKey: idempotencyKey || null,
        userId: authUser?.id || null,
        customerId: customer_id || null,
        customerName: customer_name || null,
        subtotal,
        discount,
        discountType: discount_type || null,
        taxAmount: tax_amount,
        totalAmount,
        paidAmount: paid_amount,
        changeAmount,
        paymentMethod: payment_method,
        status: 'completed',
      }, { client: trx })

      await SaleItem.createMany(
        saleItemsData.map((d) => ({
          ...d,
          saleId: sale.id,
        })),
        { client: trx }
      )

      return response.status(201).json({
        success: true,
        sale: {
          id: sale.id,
          invoice_number: sale.invoiceNumber,
          total_amount: sale.totalAmount,
          paid_amount: sale.paidAmount,
          change_amount: sale.changeAmount,
          status: sale.status,
          created_at: sale.createdAt.toISO(),
        },
      })
    })
  }
}
