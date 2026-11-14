import { HttpContext } from '@adonisjs/core/http'
import db from '@adonisjs/lucid/services/db'
import Return from '#models/tenant/return'
import ReturnItem from '#models/tenant/return_item'
import Sale from '#models/tenant/sale'
import Product from '#models/tenant/product'
import Customer from '#models/tenant/customer'
import { TenantContext } from '#core/tenancy/tenant_context'
import { syncHub } from '#core/events/sync_hub'

function serializeReturn(r: Return, invoiceNumber = '') {
  return {
    id: r.id,
    return_number: r.returnNumber,
    sale_id: r.saleId || 0,
    invoice_number: invoiceNumber || r.returnNumber,
    user_id: r.userId || 0,
    total_refund: Number(r.totalRefund) || 0,
    reason: r.reason || null,
    created_at: r.createdAt?.toISO?.() || new Date().toISOString(),
  }
}

function serializeReturnItem(ri: ReturnItem) {
  return {
    id: ri.id,
    return_id: ri.returnId,
    sale_item_id: ri.saleItemId || null,
    product_id: ri.productId || null,
    product_name: ri.productName || '',
    quantity: Number(ri.quantity) || 0,
    unit_price: Number(ri.unitPrice) || 0,
    total_refund: Number(ri.refundAmount) || 0,
  }
}

export default class PosReturnsController {
  async index({ response }: HttpContext) {
    const returns = await Return.query().orderBy('id', 'desc').limit(200)
    return response.ok(returns.map((r) => serializeReturn(r)))
  }

  async forSale({ params, response }: HttpContext) {
    const saleId = Number(params.saleId)
    const sale = await Sale.query().where('id', saleId).first()
    const returns = await Return.query().where('sale_id', saleId).orderBy('id', 'desc')
    return response.ok(returns.map((r) => serializeReturn(r, sale?.invoiceNumber || '')))
  }

  async returnItemsForSale({ params, response }: HttpContext) {
    const saleId = Number(params.saleId)
    const schema = TenantContext.get()?.schemaName || 'tenant_main'
    const res = await db.rawQuery(
      `SELECT ri.*
       FROM "${schema}".return_items ri
       JOIN "${schema}".returns r ON ri.return_id = r.id
       WHERE r.sale_id = ?
       ORDER BY ri.id ASC;`,
      [saleId]
    )
    const items = (res.rows || []).map((row: any) => ({
      id: Number(row.id),
      return_id: Number(row.return_id),
      sale_item_id: row.sale_item_id ? Number(row.sale_item_id) : null,
      product_id: row.product_id ? Number(row.product_id) : null,
      product_name: row.product_name || '',
      quantity: Number(row.quantity) || 0,
      unit_price: Number(row.unit_price) || 0,
      total_refund: Number(row.refund_amount) || 0,
    }))
    return response.ok(items)
  }

  async store({ request, response, authUser }: HttpContext & { authUser?: any }) {
    const body = request.all()
    const saleId = body.sale_id ? Number(body.sale_id) : null
    const rawItems: any[] = Array.isArray(body.items) ? body.items : []

    if (rawItems.length === 0) {
      return response.status(400).json({ error: 'At least one return item is required.' })
    }

    const schema = TenantContext.get()?.schemaName || 'tenant_main'

    const outcome = await db.transaction(async (trx) => {
      let computedRefund = 0
      const itemRecords: Array<{
        saleItemId: number | null
        productId: number | null
        productName: string | null
        unitPrice: number
        quantity: number
        refundAmount: number
        balanceAfter?: number
      }> = []

      for (const item of rawItems) {
        const qty = parseInt(item.quantity, 10)
        if (Number.isNaN(qty) || qty <= 0) {
          return { status: 400 as const, error: 'Return item quantity must be a positive integer.' }
        }

        const unitPrice = Math.max(0, Math.round(Number(item.unit_price) || 0))
        const refundAmt =
          item.refund_amount !== undefined
            ? Math.max(0, Math.round(Number(item.refund_amount)))
            : item.total_refund !== undefined
              ? Math.max(0, Math.round(Number(item.total_refund)))
              : unitPrice * qty

        computedRefund += refundAmt

        let balanceAfter: number | undefined
        if (item.product_id) {
          const product = await Product.query({ client: trx })
            .where('id', Number(item.product_id))
            .forUpdate()
            .first()
          if (product) {
            product.stockQuantity += qty
            product.version += 1
            await product.useTransaction(trx).save()
            balanceAfter = product.stockQuantity
          }
        }

        itemRecords.push({
          saleItemId: item.sale_item_id ? Number(item.sale_item_id) : null,
          productId: item.product_id ? Number(item.product_id) : null,
          productName: item.product_name || null,
          unitPrice,
          quantity: qty,
          refundAmount: refundAmt,
          balanceAfter,
        })
      }

      const finalRefund =
        body.total_refund !== undefined && Number(body.total_refund) > 0
          ? Math.round(Number(body.total_refund))
          : computedRefund

      let invoiceNumber = ''
      let sale: Sale | null = null
      if (saleId) {
        sale = await Sale.query({ client: trx }).where('id', saleId).preload('items').first()
        if (sale) {
          invoiceNumber = sale.invoiceNumber
        }
      }

      const returnRecord = await Return.create(
        {
          returnNumber: body.return_number || `RET-${Date.now()}-${Math.floor(100 + Math.random() * 900)}`,
          saleId,
          userId: Number(body.user_id || authUser?.id || 0) || null,
          totalRefund: finalRefund,
          reason: body.reason || null,
        },
        { client: trx }
      )

      const createdItems = await ReturnItem.createMany(
        itemRecords.map(({ balanceAfter: _ba, ...d }) => ({
          ...d,
          returnId: returnRecord.id,
        })),
        { client: trx }
      )

      for (const rec of itemRecords) {
        if (rec.productId && rec.balanceAfter !== undefined) {
          await trx.rawQuery(
            `INSERT INTO "${schema}".stock_ledger (product_id, change_quantity, balance_after, reference_type, reference_id)
             VALUES (?, ?, ?, 'return', ?);`,
            [rec.productId, rec.quantity, rec.balanceAfter, returnRecord.id]
          )
        }
      }

      // If sale was on credit, reduce customer balance
      if (sale && sale.customerId && sale.paymentMethod === 'credit') {
        const cust = await Customer.query({ client: trx }).where('id', sale.customerId).forUpdate().first()
        if (cust) {
          cust.balance = Math.max(0, Number(cust.balance || 0) - finalRefund)
          await cust.useTransaction(trx).save()
        }
      }

      // Mark sale as 'returned' if total refunded quantity covers full sold quantity
      if (sale) {
        const totalSoldQty = sale.items.reduce((sum, si) => sum + Number(si.quantity || 0), 0)
        const totalReturnedRes = await trx.rawQuery(
          `SELECT COALESCE(SUM(ri.quantity), 0)::int as qty
           FROM "${schema}".return_items ri
           JOIN "${schema}".returns r ON ri.return_id = r.id
           WHERE r.sale_id = ?;`,
          [sale.id]
        )
        const totalReturnedQty = Number(totalReturnedRes.rows[0]?.qty) || 0
        if (totalSoldQty > 0 && totalReturnedQty >= totalSoldQty) {
          sale.status = 'returned'
          await sale.useTransaction(trx).save()
        }
      }

      return {
        status: 201 as const,
        data: {
          ...serializeReturn(returnRecord, invoiceNumber),
          items: createdItems.map(serializeReturnItem),
        },
      }
    })

    if ('error' in outcome) {
      return response.status(outcome.status).json({ error: outcome.error })
    }

    const tenantCode = TenantContext.get()?.code || 'main'
    syncHub.emit(tenantCode, 'product_updated', { source: 'return', sale_id: saleId })

    return response.status(201).json(outcome.data)
  }
}
