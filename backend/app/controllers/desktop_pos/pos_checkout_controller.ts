import { HttpContext } from '@adonisjs/core/http'
import db from '@adonisjs/lucid/services/db'
import Sale from '#models/tenant/sale'
import SaleItem from '#models/tenant/sale_item'
import Product from '#models/tenant/product'
import Customer from '#models/tenant/customer'
import Return from '#models/tenant/return'
import { TenantContext } from '#core/tenancy/tenant_context'
import { syncHub } from '#core/events/sync_hub'

function serializeSaleItem(it: SaleItem) {
  const totalVal = Number(it.total) || 0
  return {
    id: it.id,
    sale_id: it.saleId,
    product_id: it.productId,
    product_name: it.productName,
    barcode: it.barcode || null,
    quantity: Number(it.quantity) || 0,
    unit_price: Number(it.unitPrice) || 0,
    cost_price: Number(it.costPrice) || 0,
    subtotal: Number(it.subtotal) || 0,
    discount: Number(it.discount) || 0,
    total: totalVal,
    total_price: totalVal,
    created_at: it.createdAt?.toISO?.() || null,
  }
}

function serializeSale(s: Sale) {
  const items = Array.isArray(s.items) ? s.items.map(serializeSaleItem) : []
  return {
    id: s.id,
    invoice_number: s.invoiceNumber,
    invoiceNumber: s.invoiceNumber,
    idempotency_key: s.idempotencyKey || null,
    user_id: s.userId || 0,
    customer_id: s.customerId || null,
    customer_name: s.customerName || null,
    subtotal: Number(s.subtotal) || 0,
    discount: Number(s.discount) || 0,
    discount_type: s.discountType || null,
    tax_amount: Number(s.taxAmount) || 0,
    total_amount: Number(s.totalAmount) || 0,
    totalAmount: Number(s.totalAmount) || 0,
    paid_amount: Number(s.paidAmount) || 0,
    change_amount: Number(s.changeAmount) || 0,
    payment_method: s.paymentMethod || 'cash',
    paymentMethod: s.paymentMethod || 'cash',
    transaction_reference: s.transactionReference || null,
    transactionReference: s.transactionReference || null,
    status: s.status || 'completed',
    created_at: s.createdAt?.toISO?.() || new Date().toISOString(),
    createdAt: s.createdAt?.toISO?.() || new Date().toISOString(),
    items,
  }
}

export default class PosCheckoutController {
  async nextNumber({ response }: HttpContext) {
    const today = new Date().toISOString().slice(0, 10).replace(/-/g, '')
    const prefix = `INV-${today}-`
    const schema = TenantContext.get()?.schemaName || 'tenant_main'
    const countRes = await db.rawQuery(
      `SELECT COUNT(*) as count FROM "${schema}".sales WHERE invoice_number LIKE ?`,
      [`${prefix}%`]
    )
    const count = parseInt(countRes.rows[0]?.count || '0', 10)
    const number = `${prefix}${String(count + 1).padStart(4, '0')}`
    return response.ok({ number, invoice_number: number })
  }

  async index({ response }: HttpContext) {
    const sales = await Sale.query().preload('items').orderBy('id', 'desc').limit(100)
    return response.ok(sales.map(serializeSale))
  }

  async show({ params, response }: HttpContext) {
    const sale = await Sale.query().where('id', params.id).preload('items').first()

    if (!sale) {
      return response.status(404).json({ error: 'Sale record not found.' })
    }

    const returns = await Return.query().where('sale_id', sale.id).orderBy('id', 'desc')
    const serialized = serializeSale(sale)
    const serializedReturns = returns.map((r) => ({
      id: r.id,
      return_number: r.returnNumber,
      sale_id: r.saleId || sale.id,
      invoice_number: sale.invoiceNumber,
      user_id: r.userId || 0,
      total_refund: Number(r.totalRefund) || 0,
      reason: r.reason || null,
      created_at: r.createdAt?.toISO?.() || new Date().toISOString(),
    }))

    return response.ok({
      ...serialized,
      sale: serialized,
      items: serialized.items,
      returns: serializedReturns,
    })
  }

  async store({ request, response, authUser }: HttpContext & { authUser?: any }) {
    const body = request.all()
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
      user_id,
      transaction_reference,
      transactionReference,
    } = body

    const idempotencyKey = idempotency_key || request.header('x-idempotency-key')

    if (idempotencyKey) {
      const existing = await Sale.query().where('idempotency_key', idempotencyKey).preload('items').first()
      if (existing) {
        const serializedExisting = serializeSale(existing)
        return response.ok({
          success: true,
          ...serializedExisting,
          sale: serializedExisting,
        })
      }
    }

    if (!items || !Array.isArray(items) || items.length === 0) {
      return response.status(400).json({ error: 'At least one sale item is required.' })
    }

    const schema = TenantContext.get()?.schemaName || 'tenant_main'

    const txResult = await db.transaction(async (trx) => {
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
        balanceAfter: number
      }> = []

      for (const item of items) {
        const qty = parseInt(item.quantity, 10)
        if (Number.isNaN(qty) || qty <= 0) {
          return {
            status: 400 as const,
            error: `Invalid item quantity for product ID ${item.product_id}. Quantity must be a positive integer.`,
          }
        }

        const product = await Product.query({ client: trx })
          .where('id', item.product_id)
          .forUpdate()
          .first()

        if (!product) {
          return {
            status: 404 as const,
            error: `Product ID ${item.product_id} was not found.`,
          }
        }

        if (product.stockQuantity < qty) {
          return {
            status: 400 as const,
            error: `Insufficient stock for '${product.name}'. Remaining: ${product.stockQuantity}`,
          }
        }

        product.stockQuantity -= qty
        product.version += 1
        await product.useTransaction(trx).save()

        const parsedUnitPrice = parseInt(item.unit_price, 10)
        const unitPrice = !Number.isNaN(parsedUnitPrice) && parsedUnitPrice >= 0 ? parsedUnitPrice : product.sellingPrice
        const lineSubtotal = unitPrice * qty
        const itemDiscount = Math.max(0, parseInt(item.discount, 10) || 0)
        const lineTotal = Math.max(0, lineSubtotal - itemDiscount)
        subtotal += lineSubtotal

        saleItemsData.push({
          productId: product.id,
          productName: item.product_name || product.name,
          barcode: product.barcode,
          quantity: qty,
          unitPrice,
          costPrice: product.costPrice,
          subtotal: lineSubtotal,
          discount: itemDiscount,
          total: lineTotal,
          balanceAfter: product.stockQuantity,
        })
      }

      const safeDiscount = Math.max(0, Math.round(Number(discount) || 0))
      const safeTax = Math.max(0, Math.round(Number(tax_amount) || 0))
      const safePaid = Math.max(0, Math.round(Number(paid_amount) || 0))
      const computedTotal = Math.max(0, subtotal - safeDiscount + safeTax)
      const totalAmount =
        body.total_amount !== undefined && !Number.isNaN(Number(body.total_amount))
          ? Math.max(0, Math.round(Number(body.total_amount)))
          : computedTotal
      const changeAmount = Math.max(0, safePaid - totalAmount)

      const sale = await Sale.create(
        {
          invoiceNumber: invoice_number || `INV-${Date.now()}-${Math.floor(100 + Math.random() * 900)}`,
          idempotencyKey: idempotencyKey || null,
          userId: Number(user_id || authUser?.id || 0) || null,
          customerId: customer_id ? Number(customer_id) : null,
          customerName: customer_name || null,
          subtotal,
          discount: safeDiscount,
          discountType: discount_type || null,
          taxAmount: safeTax,
          totalAmount,
          paidAmount: safePaid,
          changeAmount,
          paymentMethod: String(payment_method || 'cash').toLowerCase(),
          transactionReference: transaction_reference || transactionReference || null,
          status: 'completed',
        },
        { client: trx }
      )

      await SaleItem.createMany(
        saleItemsData.map(({ balanceAfter: _ba, ...d }) => ({
          ...d,
          saleId: sale.id,
        })),
        { client: trx }
      )

      for (const line of saleItemsData) {
        await trx.rawQuery(
          `INSERT INTO "${schema}".stock_ledger (product_id, change_quantity, balance_after, reference_type, reference_id)
           VALUES (?, ?, ?, 'sale', ?);`,
          [line.productId, -line.quantity, line.balanceAfter, sale.id]
        )
      }

      if (sale.customerId && sale.paymentMethod === 'credit') {
        const cust = await Customer.query({ client: trx }).where('id', sale.customerId).forUpdate().first()
        if (cust) {
          const creditOwed = Math.max(0, totalAmount - safePaid)
          cust.balance = Number(cust.balance || 0) + creditOwed
          await cust.useTransaction(trx).save()
        }
      }

      await sale.load('items')
      return { status: 201 as const, sale: serializeSale(sale) }
    })

    if ('error' in txResult) {
      return response.status(txResult.status).json({ error: txResult.error })
    }

    const tenantCode = TenantContext.get()?.code || 'main'
    syncHub.emit(tenantCode, 'sale_created', { id: txResult.sale.id, invoice_number: txResult.sale.invoice_number })
    syncHub.emit(tenantCode, 'product_updated', { source: 'sale', id: txResult.sale.id })

    return response.status(201).json({
      success: true,
      ...txResult.sale,
      sale: txResult.sale,
    })
  }
}
