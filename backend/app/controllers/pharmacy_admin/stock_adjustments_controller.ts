import { HttpContext } from '@adonisjs/core/http'
import db from '@adonisjs/lucid/services/db'
import Product from '#models/tenant/product'
import StockAdjustment from '#models/tenant/stock_adjustment'
import { TenantContext } from '#core/tenancy/tenant_context'
import { syncHub } from '#core/events/sync_hub'

function serializeAdjustment(a: StockAdjustment, extra?: { productName?: string; adjustmentQty?: number }) {
  const signedQty =
    extra?.adjustmentQty ??
    (['subtract', 'damaged', 'expired'].includes(a.type) ? -Math.abs(a.quantity) : a.quantity)

  return {
    id: a.id,
    product_id: a.productId,
    product_name: extra?.productName || null,
    user_id: a.userId,
    type: a.type,
    quantity: a.quantity,
    adjustment_quantity: signedQty,
    reason: a.reason || '',
    reference: a.reference || null,
    created_at: a.createdAt?.toISO?.() || new Date().toISOString(),
  }
}

export default class StockAdjustmentsController {
  async index({ response }: HttpContext) {
    const schema = TenantContext.get()?.schemaName || 'tenant_main'
    const res = await db.rawQuery(
      `SELECT sa.*, p.name as product_name
       FROM "${schema}".stock_adjustments sa
       LEFT JOIN "${schema}".products p ON sa.product_id = p.id
       ORDER BY sa.id DESC
       LIMIT 200;`
    )

    const mapped = (res.rows || []).map((r: any) => {
      const signed = ['subtract', 'damaged', 'expired'].includes(r.type)
        ? -Math.abs(Number(r.quantity) || 0)
        : Number(r.quantity) || 0
      return {
        id: r.id,
        product_id: r.product_id,
        product_name: r.product_name || null,
        user_id: r.user_id,
        type: r.type,
        quantity: Number(r.quantity) || 0,
        adjustment_quantity: signed,
        reason: r.reason || '',
        reference: r.reference || null,
        created_at: r.created_at,
      }
    })

    return response.ok(mapped)
  }

  async forProduct({ params, response }: HttpContext) {
    const productId = Number(params.productId)
    const adjustments = await StockAdjustment.query()
      .where('product_id', productId)
      .orderBy('id', 'desc')
      .limit(100)
    return response.ok(adjustments.map((a) => serializeAdjustment(a)))
  }

  async store({ request, response, authUser }: HttpContext & { authUser?: any }) {
    const role = String(authUser?.role || '').toLowerCase()
    if (role === 'cashier') {
      return response.status(403).json({
        error: 'Forbidden',
        message: 'Cashiers are not authorized to adjust inventory stock.',
      })
    }

    const body = request.all()
    const productId = Number(body.product_id ?? body.productId)
    const rawDelta =
      body.adjustment_quantity !== undefined
        ? Number(body.adjustment_quantity)
        : body.quantity !== undefined
          ? Number(body.quantity)
          : 0

    if (!productId || Number.isNaN(rawDelta) || rawDelta === 0) {
      return response.status(400).json({ error: 'product_id and a non-zero adjustment quantity are required.' })
    }

    const reason = String(body.reason || 'Manual stock adjustment').trim()
    const reference = body.reference ? String(body.reference).trim() : null
    const requestedType = String(body.type || '').toLowerCase()

    const outcome = await db.transaction(async (trx) => {
      const product = await Product.query({ client: trx }).where('id', productId).forUpdate().first()
      if (!product) {
        return { error: 'Product not found.', status: 404 as const }
      }

      let signedDelta = Math.trunc(rawDelta)
      let adjType: StockAdjustment['type'] = signedDelta >= 0 ? 'add' : 'subtract'
      if (['add', 'subtract', 'set', 'damaged', 'expired'].includes(requestedType)) {
        adjType = requestedType as StockAdjustment['type']
        if (['subtract', 'damaged', 'expired'].includes(adjType) && signedDelta > 0) {
          signedDelta = -signedDelta
        }
      }

      if (adjType === 'set') {
        const targetQty = Math.max(0, Math.trunc(rawDelta))
        signedDelta = targetQty - product.stockQuantity
        product.stockQuantity = targetQty
      } else {
        const nextQty = product.stockQuantity + signedDelta
        if (nextQty < 0) {
          return {
            error: `Insufficient stock for adjustment. Current stock: ${product.stockQuantity}.`,
            status: 400 as const,
          }
        }
        product.stockQuantity = nextQty
      }

      product.version += 1
      await product.useTransaction(trx).save()

      const adj = await StockAdjustment.create(
        {
          productId: product.id,
          userId: Number(body.user_id || authUser?.id || 0) || null,
          type: adjType,
          quantity: Math.abs(signedDelta),
          reason,
          reference,
        },
        { client: trx }
      )

      const schema = TenantContext.get()?.schemaName || 'tenant_main'
      await trx.rawQuery(
        `INSERT INTO "${schema}".stock_ledger (product_id, change_quantity, balance_after, reference_type, reference_id)
         VALUES (?, ?, ?, 'adjustment', ?);`,
        [product.id, signedDelta, product.stockQuantity, adj.id]
      )

      return {
        status: 201 as const,
        adjustment: serializeAdjustment(adj, { productName: product.name, adjustmentQty: signedDelta }),
        stock_quantity: product.stockQuantity,
      }
    })

    if ('error' in outcome) {
      return response.status(outcome.status).json({ error: outcome.error })
    }

    syncHub.emit(TenantContext.get()?.code || 'main', 'product_updated', {
      id: productId,
      source: 'stock_adjustment',
    })
    return response.status(201).json(outcome.adjustment)
  }
}

