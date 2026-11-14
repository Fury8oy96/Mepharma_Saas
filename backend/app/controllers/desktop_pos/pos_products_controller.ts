import { HttpContext } from '@adonisjs/core/http'
import { DateTime } from 'luxon'
import Product from '#models/tenant/product'
import { TenantContext } from '#core/tenancy/tenant_context'
import { syncHub } from '#core/events/sync_hub'

export default class PosProductsController {
  private mapProduct(p: Product) {
    return {
      id: p.id,
      name: p.name,
      sku: p.sku,
      barcode: p.barcode,
      category_id: p.categoryId,
      supplier_id: p.supplierId,
      cost_price: p.costPrice,
      selling_price: p.sellingPrice,
      stock_quantity: p.stockQuantity,
      low_stock_threshold: p.lowStockThreshold,
      expiry_date: p.expiryDate
        ? typeof p.expiryDate === 'string'
          ? p.expiryDate
          : p.expiryDate.toISODate?.() || p.expiryDate.toISO?.()
        : null,
      description: p.description,
      version: p.version,
      created_at: p.createdAt
        ? typeof p.createdAt === 'string'
          ? p.createdAt
          : p.createdAt.toISO?.() || null
        : null,
      updated_at: p.updatedAt
        ? typeof p.updatedAt === 'string'
          ? p.updatedAt
          : p.updatedAt.toISO?.() || null
        : null,
    }
  }

  async index({ request, response }: HttpContext) {
    const { search, barcode, sku } = request.qs()
    const query = Product.query().preload('category')

    if (barcode) {
      query.where('barcode', barcode)
    } else if (sku) {
      query.where('sku', sku)
    } else if (search) {
      query.where((q) => {
        q.whereILike('name', `%${search}%`)
          .orWhereILike('sku', `%${search}%`)
          .orWhere('barcode', search)
      })
    }

    const products = await query.orderBy('name', 'asc').limit(150)
    return response.ok(products.map((p) => this.mapProduct(p)))
  }

  async show({ params, response }: HttpContext) {
    const product = await Product.query().where('id', params.id).first()
    if (!product) {
      return response.status(404).json({ error: 'Product not found.' })
    }
    return response.ok(this.mapProduct(product))
  }

  async findBySku({ params, response }: HttpContext) {
    const sku = decodeURIComponent(String(params.sku || '')).trim()
    const product = await Product.query().where('sku', sku).first()
    if (!product) {
      return response.status(404).json({ error: 'Product not found.' })
    }
    return response.ok(this.mapProduct(product))
  }

  async findByBarcode({ params, response }: HttpContext) {
    const barcode = decodeURIComponent(String(params.barcode || '')).trim()
    const product = await Product.query().where('barcode', barcode).first()
    if (!product) {
      return response.status(404).json({ error: 'Product not found.' })
    }
    return response.ok(this.mapProduct(product))
  }

  async lowStock({ response }: HttpContext) {
    const products = await Product.query()
      .whereRaw('stock_quantity <= low_stock_threshold')
      .orderBy('name', 'asc')
      .limit(100)

    return response.ok(products.map((p) => this.mapProduct(p)))
  }

  async expiring({ request, response }: HttpContext) {
    const { within_days = 30 } = request.qs()
    const targetDate = DateTime.now().plus({ days: Number(within_days) || 30 }).toISODate()
    const products = await Product.query()
      .whereNotNull('expiry_date')
      .where('expiry_date', '<=', targetDate!)
      .orderBy('expiry_date', 'asc')
      .limit(100)

    return response.ok(products.map((p) => this.mapProduct(p)))
  }

  async countLowStock({ response }: HttpContext) {
    const res = await Product.query().whereRaw('stock_quantity <= low_stock_threshold').count('* as count')
    const count = Number(res[0]?.$extras?.count) || 0
    return response.ok({ count })
  }

  async checkSku({ request, response }: HttpContext) {
    const { sku, exclude_id } = request.qs()
    if (!sku) return response.ok({ taken: false })
    const query = Product.query().where('sku', sku)
    if (exclude_id) query.whereNot('id', exclude_id)
    const exists = await query.first()
    return response.ok({ taken: !!exists })
  }

  async checkBarcode({ request, response }: HttpContext) {
    const { barcode, exclude_id } = request.qs()
    if (!barcode) return response.ok({ taken: false })
    const query = Product.query().where('barcode', barcode)
    if (exclude_id) query.whereNot('id', exclude_id)
    const exists = await query.first()
    return response.ok({ taken: !!exists })
  }

  async store({ request, response, authUser }: HttpContext & { authUser?: any }) {
    const role = (authUser?.role || '').toLowerCase()
    if (role === 'cashier') {
      return response.status(403).json({
        error: 'Forbidden',
        message: 'Cashiers cannot create new products.',
      })
    }

    const data = request.all()
    if (!data.name || !data.name.trim()) {
      return response.status(400).json({ error: 'Product name is required.' })
    }

    // Check SKU uniqueness
    const sku = data.sku?.trim() || `SKU-${Date.now()}`
    const existingSku = await Product.query().where('sku', sku).first()
    if (existingSku) {
      return response.status(400).json({ error: 'SKU is already in use.' })
    }

    // Check Barcode uniqueness if provided
    const barcode = data.barcode && typeof data.barcode === 'string' && data.barcode.trim().length > 0
      ? data.barcode.trim()
      : null

    if (barcode) {
      const existingBarcode = await Product.query().where('barcode', barcode).first()
      if (existingBarcode) {
        return response.status(400).json({ error: 'Barcode is already in use.' })
      }
    }

    let expiryDate: DateTime | null = null
    if (data.expiry_date) {
      const dt = DateTime.fromISO(data.expiry_date)
      if (dt.isValid) expiryDate = dt
    }

    const product = await Product.create({
      name: data.name.trim(),
      sku,
      barcode,
      categoryId: data.category_id && Number(data.category_id) > 0 ? Number(data.category_id) : null,
      supplierId: data.supplier_id && Number(data.supplier_id) > 0 ? Number(data.supplier_id) : null,
      costPrice: data.cost_price !== undefined ? Math.max(0, Math.round(Number(data.cost_price))) : 0,
      sellingPrice: data.selling_price !== undefined ? Math.max(0, Math.round(Number(data.selling_price))) : 0,
      stockQuantity: data.stock_quantity !== undefined ? Math.max(0, Math.round(Number(data.stock_quantity))) : 0,
      lowStockThreshold: data.low_stock_threshold !== undefined ? Math.max(0, Math.round(Number(data.low_stock_threshold))) : 10,
      expiryDate,
      description: data.description && typeof data.description === 'string' ? data.description.trim() : null,
      version: 1,
    })

    syncHub.emit(TenantContext.get()?.code || 'main', 'product_created', { id: product.id })
    return response.status(201).json(this.mapProduct(product))
  }

  async update({ params, request, response, authUser }: HttpContext & { authUser?: any }) {
    const role = (authUser?.role || '').toLowerCase()
    if (role === 'cashier') {
      return response.status(403).json({
        error: 'Forbidden',
        message: 'Cashiers cannot modify products.',
      })
    }

    const product = await Product.query().where('id', params.id).first()
    if (!product) {
      return response.status(404).json({ error: 'Product not found.' })
    }

    const data = request.all()

    if (data.name !== undefined) {
      const name = typeof data.name === 'string' ? data.name.trim() : ''
      if (!name) {
        return response.status(400).json({ error: 'Product name cannot be empty.' })
      }
      product.name = name
    }

    if (data.barcode !== undefined) {
      const barcode = data.barcode && typeof data.barcode === 'string' && data.barcode.trim().length > 0
        ? data.barcode.trim()
        : null

      if (barcode) {
        const existingBarcode = await Product.query()
          .where('barcode', barcode)
          .whereNot('id', product.id)
          .first()
        if (existingBarcode) {
          return response.status(400).json({ error: 'Barcode is already in use by another product.' })
        }
      }
      product.barcode = barcode
    }

    if (data.category_id !== undefined) {
      product.categoryId = data.category_id && Number(data.category_id) > 0 ? Number(data.category_id) : null
    }

    if (data.supplier_id !== undefined) {
      product.supplierId = data.supplier_id && Number(data.supplier_id) > 0 ? Number(data.supplier_id) : null
    }

    if (data.cost_price !== undefined) {
      product.costPrice = Math.max(0, Math.round(Number(data.cost_price)))
    }

    if (data.selling_price !== undefined) {
      product.sellingPrice = Math.max(0, Math.round(Number(data.selling_price)))
    }

    if (data.stock_quantity !== undefined) {
      product.stockQuantity = Math.max(0, Math.round(Number(data.stock_quantity)))
    }

    if (data.low_stock_threshold !== undefined) {
      product.lowStockThreshold = Math.max(0, Math.round(Number(data.low_stock_threshold)))
    }

    if (data.expiry_date !== undefined) {
      if (data.expiry_date) {
        const dt = DateTime.fromISO(data.expiry_date)
        product.expiryDate = dt.isValid ? dt : null
      } else {
        product.expiryDate = null
      }
    }

    if (data.description !== undefined) {
      product.description = data.description && typeof data.description === 'string' ? data.description.trim() : null
    }

    product.version = (product.version || 0) + 1
    await product.save()

    syncHub.emit(TenantContext.get()?.code || 'main', 'product_updated', { id: product.id })
    return response.ok(this.mapProduct(product))
  }

  async destroy({ params, response, authUser }: HttpContext & { authUser?: any }) {
    const role = (authUser?.role || '').toLowerCase()
    if (role !== 'admin' && role !== 'pharmacy_admin' && role !== 'branch_admin' && role !== 'super_admin') {
      return response.status(403).json({
        error: 'Forbidden',
        message: 'Only Administrators can delete products.',
      })
    }

    const product = await Product.query().where('id', params.id).first()
    if (!product) {
      return response.status(404).json({ error: 'Product not found.' })
    }

    await product.delete()
    syncHub.emit(TenantContext.get()?.code || 'main', 'product_deleted', { id: Number(params.id) })
    return response.ok({ success: true, message: 'Product deleted.' })
  }
}
