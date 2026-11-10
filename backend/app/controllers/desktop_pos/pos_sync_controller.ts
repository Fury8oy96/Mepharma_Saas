import { HttpContext } from '@adonisjs/core/http'
import { DateTime } from 'luxon'
import db from '@adonisjs/lucid/services/db'
import Product from '#models/tenant/product'
import Category from '#models/tenant/category'
import Supplier from '#models/tenant/supplier'
import Customer from '#models/tenant/customer'
import Sale from '#models/tenant/sale'
import SaleItem from '#models/tenant/sale_item'

export default class PosSyncController {
  async status({ response, tenant }: HttpContext) {
    return response.ok({
      status: 'online',
      tenant: tenant ? tenant.code : 'unknown',
      timestamp: new Date().toISOString(),
    })
  }

  async pullUpdates({ response }: HttpContext) {
    // 1. Categories
    const categories = await Category.query().orderBy('id', 'asc')
    const mappedCategories = categories.map((c) => ({
      id: c.id,
      name: c.name,
      description: c.description || null,
    }))

    // 2. Suppliers
    const suppliers = await Supplier.query().orderBy('id', 'asc')
    const mappedSuppliers = suppliers.map((s) => ({
      id: s.id,
      name: s.name,
      contact_person: null,
      phone: s.phone || null,
      email: s.email || null,
      address: s.address || null,
    }))

    // 3. Products
    const products = await Product.query().orderBy('id', 'asc')
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
      updated_at: p.updatedAt ? p.updatedAt.toISO() : new Date().toISOString(),
    }))

    // 4. Customers
    const customers = await Customer.query().orderBy('id', 'asc')
    const mappedCustomers = customers.map((c) => ({
      id: c.id,
      name: c.name,
      phone: c.phone || null,
      email: c.email || null,
      address: c.address || null,
      notes: null,
      credit_limit: Number(c.creditLimit) || 0,
      created_at: c.createdAt ? c.createdAt.toISO() : new Date().toISOString(),
    }))

    // 5. Sales & Sale Items
    const sales = await Sale.query().preload('items').orderBy('id', 'desc').limit(200)
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
        status: 'completed',
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

  async pushBatch({ request, response, authUser }: HttpContext) {
    const { items = [] } = request.all()
    const results: Array<{ idempotency_key: string; status: string; error?: string | null }> = []

    if (!Array.isArray(items) || items.length === 0) {
      return response.ok({ success: true, items: [] })
    }

    for (const item of items) {
      const { idempotency_key, entity_type, action, payload } = item

      if (!idempotency_key) {
        continue
      }

      if (entity_type === 'sale' && action === 'create' && payload) {
        try {
          // Check if sale was already processed by idempotency_key or invoice_number
          const existing = await Sale.query()
            .where('idempotency_key', idempotency_key)
            .orWhere('invoice_number', payload.invoice_number)
            .first()

          if (existing) {
            results.push({ idempotency_key, status: 'already_processed', error: null })
            continue
          }

          // Process sale in atomic transaction
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
              const product = await Product.query({ client: trx })
                .where('id', line.product_id)
                .first()

              if (product) {
                // Deduct stock if available
                product.stockQuantity = Math.max(0, product.stockQuantity - (line.quantity || 1))
                await product.useTransaction(trx).save()
              }

              const unitPrice = Number(line.unit_price) || (product ? product.sellingPrice : 0)
              const lineTotal = Number(line.total_price) || (unitPrice * (line.quantity || 1))

              saleItemsData.push({
                productId: line.product_id,
                productName: line.product_name || product?.name || 'Product',
                barcode: line.barcode || product?.barcode || null,
                quantity: line.quantity || 1,
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
              },
              { client: trx }
            )

            for (const itemData of saleItemsData) {
              await SaleItem.create(
                {
                  saleId: sale.id,
                  productId: itemData.productId,
                  productName: itemData.productName,
                  barcode: itemData.barcode,
                  quantity: itemData.quantity,
                  unitPrice: itemData.unitPrice,
                  costPrice: itemData.costPrice,
                  subtotal: itemData.subtotal,
                  discount: itemData.discount,
                  total: itemData.total,
                },
                { client: trx }
              )
            }
          })

          results.push({ idempotency_key, status: 'applied', error: null })
        } catch (err: any) {
          results.push({ idempotency_key, status: 'failed', error: err.message })
        }
      } else if (entity_type === 'product' && action === 'update' && payload) {
        try {
          const product = await Product.query().where('id', payload.id).first()
          if (product) {
            if (payload.name) product.name = payload.name.trim()
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
            if (payload.cost_price !== undefined) {
              product.costPrice = Math.max(0, Math.round(Number(payload.cost_price)))
            }
            if (payload.selling_price !== undefined) {
              product.sellingPrice = Math.max(0, Math.round(Number(payload.selling_price)))
            }
            if (payload.stock_quantity !== undefined) {
              product.stockQuantity = Math.max(0, Math.round(Number(payload.stock_quantity)))
            }
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
          results.push({ idempotency_key, status: 'applied', error: null })
        } catch (err: any) {
          results.push({ idempotency_key, status: 'failed', error: err.message })
        }
      } else if (entity_type === 'product' && action === 'create' && payload) {
        try {
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
          results.push({ idempotency_key, status: 'applied', error: null })
        } catch (err: any) {
          results.push({ idempotency_key, status: 'failed', error: err.message })
        }
      } else {
        // Other entity types
        results.push({ idempotency_key, status: 'applied', error: null })
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
