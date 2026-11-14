import { HttpContext } from '@adonisjs/core/http'
import { DateTime } from 'luxon'
import jwt from 'jsonwebtoken'
import db from '@adonisjs/lucid/services/db'
import Product from '#models/tenant/product'
import Category from '#models/tenant/category'
import Supplier from '#models/tenant/supplier'
import Customer from '#models/tenant/customer'
import CustomerPayment from '#models/tenant/customer_payment'
import Sale from '#models/tenant/sale'
import SaleItem from '#models/tenant/sale_item'
import Return from '#models/tenant/return'
import ReturnItem from '#models/tenant/return_item'
import StockAdjustment from '#models/tenant/stock_adjustment'
import { TenantContext } from '#core/tenancy/tenant_context'
import { syncHub } from '#core/events/sync_hub'
import { getJwtSecret } from '#core/security/jwt_secret'

export default class PosSyncController {
  async status({ response, tenant }: HttpContext) {
    return response.ok({
      status: 'online',
      tenant: tenant ? tenant.code : 'unknown',
      timestamp: new Date().toISOString(),
    })
  }

  async events({ request, response, tenant }: HttpContext) {
    // Allow optional JWT authentication via Authorization header or ?token= query for EventSource
    const authHeader = request.header('authorization')
    const rawToken = authHeader?.replace(/^Bearer\s+/i, '').trim() || String(request.qs().token || '').trim()

    let resolvedTenantCode = tenant?.code || 'main'
    if (rawToken) {
      try {
        const decoded = jwt.verify(rawToken, getJwtSecret()) as any
        if (decoded?.pharmacyCode && typeof decoded.pharmacyCode === 'string') {
          resolvedTenantCode = decoded.pharmacyCode
        }
      } catch {
        return response.status(401).json({ error: 'Unauthorized SSE token.' })
      }
    }

    syncHub.subscribe(resolvedTenantCode, response)
    // Keep Adonis from calling response.finish() prematurely while stream stays open
    await new Promise<void>((resolve) => {
      response.response.on('close', () => resolve())
      response.response.on('error', () => resolve())
    })
  }

  async pullUpdates({ request, response }: HttpContext) {
    const sinceRaw = request.qs().since
    let sinceDt: string | null = null
    if (sinceRaw) {
      const parsed = DateTime.fromISO(String(sinceRaw))
      if (parsed.isValid) {
        sinceDt = parsed.toISO()
      }
    }

    const categories = await Category.query().orderBy('id', 'asc')
    const mappedCategories = categories.map((c) => ({
      id: c.id,
      name: c.name,
      description: c.description || null,
    }))

    const suppliers = await Supplier.query().orderBy('id', 'asc')
    const mappedSuppliers = suppliers.map((s) => ({
      id: s.id,
      name: s.name,
      contact_person: null,
      phone: s.phone || null,
      email: s.email || null,
      address: s.address || null,
    }))

    const prodQuery = Product.query().orderBy('id', 'asc')
    if (sinceDt) {
      prodQuery.where('updated_at', '>=', sinceDt)
    }
    const products = await prodQuery
    const mappedProducts = products.map((p) => ({
      id: p.id,
      sku: p.sku,
      barcode: p.barcode || null,
      name: p.name,
      category_id: p.categoryId || null,
      supplier_id: p.supplierId || null,
      cost_price: Number(p.costPrice) || 0,
      selling_price: Number(p.sellingPrice) || 0,
      stock_quantity: Number(p.stockQuantity) || 0,
      low_stock_threshold: Number(p.lowStockThreshold) || 10,
      expiry_date: p.expiryDate ? p.expiryDate.toISODate() : null,
      description: p.description || null,
      version: Number(p.version) || 1,
      updated_at: p.updatedAt ? p.updatedAt.toISO() : new Date().toISOString(),
    }))

    const custQuery = Customer.query().orderBy('id', 'asc')
    if (sinceDt) {
      custQuery.where('updated_at', '>=', sinceDt)
    }
    const customers = await custQuery
    const mappedCustomers = customers.map((c) => ({
      id: c.id,
      name: c.name,
      phone: c.phone || null,
      email: c.email || null,
      address: c.address || null,
      notes: null,
      credit_limit: Number(c.creditLimit) || 0,
      balance: Number(c.balance) || 0,
      loyalty_points: Number(c.loyaltyPoints) || 0,
      loyalty_tier: c.loyaltyTier || 'silver',
      created_at: c.createdAt ? c.createdAt.toISO() : new Date().toISOString(),
    }))

    const salesQuery = Sale.query().preload('items').orderBy('id', 'desc').limit(200)
    if (sinceDt) {
      salesQuery.where('updated_at', '>=', sinceDt)
    }
    const sales = await salesQuery
    const mappedSales: any[] = []
    const mappedSaleItems: any[] = []

    for (const s of sales) {
      mappedSales.push({
        id: s.id,
        invoice_number: s.invoiceNumber,
        user_id: s.userId || 1,
        customer_id: s.customerId || null,
        customer_name: s.customerName || null,
        subtotal: Number(s.subtotal) || 0,
        discount: Number(s.discount) || 0,
        discount_type: s.discountType || null,
        tax_amount: Number(s.taxAmount) || 0,
        total_amount: Number(s.totalAmount) || 0,
        paid_amount: Number(s.paidAmount) || 0,
        change_amount: Number(s.changeAmount) || 0,
        payment_method: s.paymentMethod || 'cash',
        status: s.status || 'completed',
        created_at: s.createdAt ? s.createdAt.toISO() : new Date().toISOString(),
      })

      if (s.items && Array.isArray(s.items)) {
        for (const item of s.items) {
          mappedSaleItems.push({
            id: item.id,
            sale_id: s.id,
            product_id: item.productId || null,
            product_name: item.productName,
            quantity: item.quantity,
            unit_price: Number(item.unitPrice) || 0,
            discount: Number(item.discount) || 0,
            total_price: Number(item.total) || 0,
          })
        }
      }
    }

    return response.ok({
      success: true,
      products: mappedProducts,
      categories: mappedCategories,
      suppliers: mappedSuppliers,
      customers: mappedCustomers,
      sales: mappedSales,
      sale_items: mappedSaleItems,
      server_time: new Date().toISOString(),
    })
  }

  async pull(ctx: HttpContext) {
    return this.pullUpdates(ctx)
  }

  async pushBatch({ request, response, authUser }: HttpContext & { authUser?: any }) {
    const { items = [] } = request.all()
    const results: Array<{ idempotency_key: string; status: string; error?: string | null }> = []

    if (!Array.isArray(items) || items.length === 0) {
      return response.ok({ success: true, items: [] })
    }

    const schema = TenantContext.get()?.schemaName || 'tenant_main'
    const tenantCode = TenantContext.get()?.code || 'main'

    for (const item of items) {
      const { idempotency_key, entity_type, action, payload } = item
      if (!idempotency_key) continue

      try {
        if (entity_type === 'sale' && action === 'create' && payload) {
          const existing = await Sale.query()
            .where('idempotency_key', idempotency_key)
            .orWhere('invoice_number', payload.invoice_number)
            .first()

          if (existing) {
            results.push({ idempotency_key, status: 'already_processed', error: null })
            continue
          }

          await db.transaction(async (trx) => {
            const saleItems = Array.isArray(payload.items) ? payload.items : []
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

            for (const line of saleItems) {
              const qty = Math.max(1, Number(line.quantity) || 1)
              const product = await Product.query({ client: trx }).where('id', line.product_id).forUpdate().first()
              if (product) {
                product.stockQuantity = Math.max(0, product.stockQuantity - qty)
                product.version += 1
                await product.useTransaction(trx).save()
              }

              const unitPrice = Number(line.unit_price) || (product ? product.sellingPrice : 0)
              const lineTotal = Number(line.total_price) || unitPrice * qty

              saleItemsData.push({
                productId: line.product_id,
                productName: line.product_name || product?.name || 'Product',
                barcode: line.barcode || product?.barcode || null,
                quantity: qty,
                unitPrice,
                costPrice: product ? product.costPrice : 0,
                subtotal: lineTotal,
                discount: Number(line.discount) || 0,
                total: lineTotal - (Number(line.discount) || 0),
              })
            }

            const sale = await Sale.create(
              {
                invoiceNumber: payload.invoice_number,
                idempotencyKey: idempotency_key,
                userId: payload.user_id || authUser?.id || null,
                customerId: payload.customer_id || null,
                customerName: payload.customer_name || null,
                subtotal: Number(payload.subtotal) || 0,
                discount: Number(payload.discount) || 0,
                discountType: payload.discount_type || null,
                taxAmount: Number(payload.tax_amount) || 0,
                totalAmount: Number(payload.total_amount) || 0,
                paidAmount: Number(payload.paid_amount) || 0,
                changeAmount: Number(payload.change_amount) || 0,
                paymentMethod: payload.payment_method || 'cash',
                status: 'completed',
              },
              { client: trx }
            )

            await SaleItem.createMany(
              saleItemsData.map((d) => ({ ...d, saleId: sale.id })),
              { client: trx }
            )

            if (sale.customerId && sale.paymentMethod === 'credit') {
              const cust = await Customer.query({ client: trx }).where('id', sale.customerId).forUpdate().first()
              if (cust) {
                const creditOwed = Math.max(0, sale.totalAmount - sale.paidAmount)
                cust.balance = Number(cust.balance || 0) + creditOwed
                await cust.useTransaction(trx).save()
              }
            }
          })

          syncHub.emit(tenantCode, 'sale_created', { invoice_number: payload.invoice_number })
          results.push({ idempotency_key, status: 'applied', error: null })
        } else if (entity_type === 'product' && action === 'update' && payload) {
          const product = await Product.query().where('id', payload.id).first()
          if (product) {
            if (payload.name) product.name = String(payload.name).trim()
            if (payload.barcode !== undefined) {
              const bc = typeof payload.barcode === 'string' ? payload.barcode.trim() : null
              product.barcode = bc && bc.length > 0 ? bc : null
            }
            if (payload.category_id !== undefined) {
              product.categoryId = payload.category_id && Number(payload.category_id) > 0 ? Number(payload.category_id) : null
            }
            if (payload.supplier_id !== undefined) {
              product.supplierId = payload.supplier_id && Number(payload.supplier_id) > 0 ? Number(payload.supplier_id) : null
            }
            if (payload.cost_price !== undefined) product.costPrice = Math.max(0, Math.round(Number(payload.cost_price)))
            if (payload.selling_price !== undefined) product.sellingPrice = Math.max(0, Math.round(Number(payload.selling_price)))
            if (payload.stock_quantity !== undefined) product.stockQuantity = Math.max(0, Math.round(Number(payload.stock_quantity)))
            if (payload.low_stock_threshold !== undefined) {
              product.lowStockThreshold = Math.max(0, Math.round(Number(payload.low_stock_threshold)))
            }
            if (payload.expiry_date !== undefined) {
              if (payload.expiry_date) {
                const dt = DateTime.fromISO(payload.expiry_date)
                product.expiryDate = dt.isValid ? dt : null
              } else {
                product.expiryDate = null
              }
            }
            if (payload.description !== undefined) {
              product.description = payload.description && typeof payload.description === 'string' ? payload.description.trim() : null
            }
            product.version = (product.version || 0) + 1
            await product.save()
          }
          syncHub.emit(tenantCode, 'product_updated', { id: payload.id })
          results.push({ idempotency_key, status: 'applied', error: null })
        } else if (entity_type === 'product' && action === 'create' && payload) {
          const sku = payload.sku?.trim() || `SKU-${Date.now()}`
          const existing = await Product.query().where('sku', sku).first()
          if (!existing) {
            let expiryDate: DateTime | null = null
            if (payload.expiry_date) {
              const dt = DateTime.fromISO(payload.expiry_date)
              if (dt.isValid) expiryDate = dt
            }
            const bc = typeof payload.barcode === 'string' ? payload.barcode.trim() : null
            await Product.create({
              name: payload.name?.trim() || 'New Medicine',
              sku,
              barcode: bc && bc.length > 0 ? bc : null,
              categoryId: payload.category_id && Number(payload.category_id) > 0 ? Number(payload.category_id) : null,
              supplierId: payload.supplier_id && Number(payload.supplier_id) > 0 ? Number(payload.supplier_id) : null,
              costPrice: payload.cost_price !== undefined ? Math.max(0, Math.round(Number(payload.cost_price))) : 0,
              sellingPrice: payload.selling_price !== undefined ? Math.max(0, Math.round(Number(payload.selling_price))) : 0,
              stockQuantity: payload.stock_quantity !== undefined ? Math.max(0, Math.round(Number(payload.stock_quantity))) : 0,
              lowStockThreshold: payload.low_stock_threshold !== undefined ? Math.max(0, Math.round(Number(payload.low_stock_threshold))) : 10,
              expiryDate,
              description: payload.description && typeof payload.description === 'string' ? payload.description.trim() : null,
              version: 1,
            })
          }
          syncHub.emit(tenantCode, 'product_created', { sku })
          results.push({ idempotency_key, status: 'applied', error: null })
        } else if (entity_type === 'product' && action === 'delete' && payload?.id) {
          const product = await Product.query().where('id', Number(payload.id)).first()
          if (product) await product.delete()
          syncHub.emit(tenantCode, 'product_deleted', { id: Number(payload.id) })
          results.push({ idempotency_key, status: 'applied', error: null })
        } else if (entity_type === 'customer' && (action === 'create' || action === 'update') && payload) {
          if (action === 'update' && payload.id) {
            const c = await Customer.query().where('id', Number(payload.id)).first()
            if (c) {
              if (payload.name) c.name = String(payload.name).trim()
              if (payload.phone !== undefined) c.phone = payload.phone || null
              if (payload.email !== undefined) c.email = payload.email || null
              if (payload.address !== undefined) c.address = payload.address || null
              if (payload.credit_limit !== undefined) c.creditLimit = Math.max(0, Math.round(Number(payload.credit_limit) || 0))
              await c.save()
            }
          } else if (payload.name) {
            await Customer.create({
              name: String(payload.name).trim(),
              phone: payload.phone || null,
              email: payload.email || null,
              address: payload.address || null,
              creditLimit: Math.max(0, Math.round(Number(payload.credit_limit) || 0)),
              balance: 0,
              loyaltyPoints: 0,
              loyaltyTier: 'silver',
            })
          }
          syncHub.emit(tenantCode, 'customer_updated', {})
          results.push({ idempotency_key, status: 'applied', error: null })
        } else if (entity_type === 'customer_payment' && action === 'create' && payload?.customer_id) {
          const amount = Math.round(Number(payload.amount) || 0)
          if (amount > 0) {
            await db.transaction(async (trx) => {
              const cust = await Customer.query({ client: trx }).where('id', Number(payload.customer_id)).forUpdate().first()
              if (cust) {
                cust.balance = Math.max(0, Number(cust.balance || 0) - amount)
                await cust.useTransaction(trx).save()
                await CustomerPayment.create(
                  {
                    customerId: cust.id,
                    amount,
                    paymentMethod: payload.payment_method || 'cash',
                    notes: payload.note || payload.notes || null,
                  },
                  { client: trx }
                )
              }
            })
          }
          results.push({ idempotency_key, status: 'applied', error: null })
        } else if (entity_type === 'stock_adjustment' && action === 'create' && payload?.product_id) {
          const rawDelta = Math.trunc(Number(payload.adjustment_quantity ?? payload.quantity ?? 0))
          if (rawDelta !== 0) {
            await db.transaction(async (trx) => {
              const product = await Product.query({ client: trx }).where('id', Number(payload.product_id)).forUpdate().first()
              if (product) {
                product.stockQuantity = Math.max(0, product.stockQuantity + rawDelta)
                product.version += 1
                await product.useTransaction(trx).save()
                const adj = await StockAdjustment.create(
                  {
                    productId: product.id,
                    userId: payload.user_id || authUser?.id || null,
                    type: rawDelta >= 0 ? 'add' : 'subtract',
                    quantity: Math.abs(rawDelta),
                    reason: payload.reason || 'Offline stock adjustment',
                    reference: payload.reference || null,
                  },
                  { client: trx }
                )
                await trx.rawQuery(
                  `INSERT INTO "${schema}".stock_ledger (product_id, change_quantity, balance_after, reference_type, reference_id)
                   VALUES (?, ?, ?, 'adjustment', ?);`,
                  [product.id, rawDelta, product.stockQuantity, adj.id]
                )
              }
            })
            syncHub.emit(tenantCode, 'product_updated', { id: Number(payload.product_id) })
          }
          results.push({ idempotency_key, status: 'applied', error: null })
        } else if (entity_type === 'return' && action === 'create' && payload) {
          const retItems = Array.isArray(payload.items) ? payload.items : []
          await db.transaction(async (trx) => {
            let computed = 0
            for (const it of retItems) {
              const q = Math.max(1, Number(it.quantity) || 1)
              const up = Math.max(0, Number(it.unit_price) || 0)
              computed += up * q
              if (it.product_id) {
                const p = await Product.query({ client: trx }).where('id', Number(it.product_id)).forUpdate().first()
                if (p) {
                  p.stockQuantity += q
                  p.version += 1
                  await p.useTransaction(trx).save()
                }
              }
            }
            const ret = await Return.create(
              {
                returnNumber: payload.return_number || `RET-${Date.now()}-${Math.floor(100 + Math.random() * 900)}`,
                saleId: payload.sale_id || null,
                userId: payload.user_id || authUser?.id || null,
                totalRefund: Number(payload.total_refund) || computed,
                reason: payload.reason || null,
              },
              { client: trx }
            )
            await ReturnItem.createMany(
              retItems.map((it: any) => ({
                returnId: ret.id,
                saleItemId: it.sale_item_id || null,
                productId: it.product_id || null,
                productName: it.product_name || null,
                unitPrice: Number(it.unit_price) || 0,
                quantity: Math.max(1, Number(it.quantity) || 1),
                refundAmount: (Number(it.unit_price) || 0) * Math.max(1, Number(it.quantity) || 1),
              })),
              { client: trx }
            )
          })
          results.push({ idempotency_key, status: 'applied', error: null })
        } else {
          results.push({
            idempotency_key,
            status: 'rejected',
            error: `Unsupported sync operation: ${entity_type}:${action}`,
          })
        }
      } catch (err: any) {
        results.push({ idempotency_key, status: 'failed', error: err.message })
      }
    }

    return response.ok({
      success: true,
      items: results,
    })
  }

  async push(ctx: HttpContext) {
    return this.pushBatch(ctx)
  }
}
