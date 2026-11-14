import { HttpContext } from '@adonisjs/core/http'
import { DateTime } from 'luxon'
import Product from '#models/tenant/product'
import Category from '#models/tenant/category'
import Supplier from '#models/tenant/supplier'
import db from '@adonisjs/lucid/services/db'
import { TenantContext } from '#core/tenancy/tenant_context'
import { syncHub } from '#core/events/sync_hub'

function serializeProduct(p: Product) {
  const expiryIso = p.expiryDate
    ? typeof p.expiryDate === 'string'
      ? p.expiryDate
      : p.expiryDate.toISODate?.() || p.expiryDate.toISO?.() || null
    : null
  const createdAtIso = p.createdAt ? p.createdAt.toISO?.() || null : null
  const updatedAtIso = p.updatedAt ? p.updatedAt.toISO?.() || null : null

  return {
    id: p.id,
    name: p.name,
    sku: p.sku,
    barcode: p.barcode,
    category_id: p.categoryId,
    categoryId: p.categoryId,
    category: p.category ? { id: p.category.id, name: p.category.name, description: p.category.description } : undefined,
    supplier_id: p.supplierId,
    supplierId: p.supplierId,
    supplier: p.supplier
      ? {
          id: p.supplier.id,
          name: p.supplier.name,
          phone: p.supplier.phone,
          email: p.supplier.email,
          address: p.supplier.address,
        }
      : undefined,
    cost_price: Number(p.costPrice) || 0,
    costPrice: Number(p.costPrice) || 0,
    selling_price: Number(p.sellingPrice) || 0,
    sellingPrice: Number(p.sellingPrice) || 0,
    stock_quantity: Number(p.stockQuantity) || 0,
    stockQuantity: Number(p.stockQuantity) || 0,
    low_stock_threshold: Number(p.lowStockThreshold) || 10,
    lowStockThreshold: Number(p.lowStockThreshold) || 10,
    expiry_date: expiryIso,
    expiryDate: expiryIso,
    version: Number(p.version) || 1,
    description: p.description,
    created_at: createdAtIso,
    createdAt: createdAtIso,
    updated_at: updatedAtIso,
    updatedAt: updatedAtIso,
  }
}

export default class CatalogController {
  private ensureCatalogWriteAccess(authUser: any, response: HttpContext['response']) {
    const role = String(authUser?.role || '').toLowerCase()
    if (role === 'cashier') {
      response.status(403).json({
        error: 'Forbidden',
        message: 'Cashiers do not have permission to modify catalog records.',
      })
      return false
    }
    return true
  }

  // --- Products ---
  async getProducts({ request, response }: HttpContext) {
    const { category_id, search, low_stock, limit = 500 } = request.qs()
    const query = Product.query().preload('category').preload('supplier')

    if (category_id) {
      query.where('category_id', category_id)
    }
    if (search) {
      query.where((q) => {
        q.whereILike('name', `%${search}%`)
          .orWhereILike('sku', `%${search}%`)
          .orWhereILike('barcode', `%${search}%`)
      })
    }
    if (low_stock === 'true') {
      query.whereRaw('stock_quantity <= low_stock_threshold')
    }

    const products = await query.orderBy('id', 'desc').limit(Number(limit) || 500)
    return response.ok(products.map(serializeProduct))
  }

  async getProduct({ params, response }: HttpContext) {
    const product = await Product.query()
      .where('id', params.id)
      .preload('category')
      .preload('supplier')
      .first()

    if (!product) {
      return response.status(404).json({ error: 'Product not found.' })
    }
    return response.ok(serializeProduct(product))
  }

  async storeProduct({ request, response, authUser }: HttpContext & { authUser?: any }) {
    if (!this.ensureCatalogWriteAccess(authUser, response)) return

    const data = request.all()
    if (!data.name || !String(data.name).trim()) {
      return response.status(400).json({ error: 'Product name is required.' })
    }

    let expiryDate: DateTime | null = null
    if (data.expiry_date) {
      const dt = DateTime.fromISO(data.expiry_date)
      if (dt.isValid) expiryDate = dt
    }

    const sku = String(data.sku || '').trim() || `SKU-${Date.now()}`
    const existingSku = await Product.query().where('sku', sku).first()
    if (existingSku) {
      return response.status(409).json({ error: `SKU '${sku}' is already in use.` })
    }

    const barcode = data.barcode && String(data.barcode).trim().length > 0 ? String(data.barcode).trim() : null
    if (barcode) {
      const existingBc = await Product.query().where('barcode', barcode).first()
      if (existingBc) {
        return response.status(409).json({ error: `Barcode '${barcode}' is already in use.` })
      }
    }

    const product = await Product.create({
      name: String(data.name).trim(),
      sku,
      barcode,
      categoryId: data.category_id && Number(data.category_id) > 0 ? Number(data.category_id) : null,
      supplierId: data.supplier_id && Number(data.supplier_id) > 0 ? Number(data.supplier_id) : null,
      costPrice: Math.max(0, Math.round(Number(data.cost_price) || 0)),
      sellingPrice: Math.max(0, Math.round(Number(data.selling_price) || 0)),
      stockQuantity: Math.max(0, Math.round(Number(data.stock_quantity) || 0)),
      lowStockThreshold: Math.max(0, Math.round(Number(data.low_stock_threshold) || 10)),
      expiryDate,
      version: 1,
      description: data.description || null,
    })

    await product.load('category')
    await product.load('supplier')
    const serialized = serializeProduct(product)
    syncHub.emit(TenantContext.get()?.code || 'main', 'product_created', { id: serialized.id })
    return response.status(201).json(serialized)
  }

  async updateProduct({ params, request, response, authUser }: HttpContext & { authUser?: any }) {
    if (!this.ensureCatalogWriteAccess(authUser, response)) return

    const product = await Product.query().where('id', params.id).first()
    if (!product) {
      return response.status(404).json({ error: 'Product not found.' })
    }

    const data = request.all()
    if (data.name !== undefined && String(data.name).trim()) product.name = String(data.name).trim()
    if (data.barcode !== undefined) {
      const bc = data.barcode && String(data.barcode).trim().length > 0 ? String(data.barcode).trim() : null
      if (bc) {
        const dup = await Product.query().where('barcode', bc).whereNot('id', product.id).first()
        if (dup) {
          return response.status(409).json({ error: `Barcode '${bc}' is already used by another product.` })
        }
      }
      product.barcode = bc
    }
    if (data.category_id !== undefined) {
      product.categoryId = data.category_id && Number(data.category_id) > 0 ? Number(data.category_id) : null
    }
    if (data.supplier_id !== undefined) {
      product.supplierId = data.supplier_id && Number(data.supplier_id) > 0 ? Number(data.supplier_id) : null
    }
    if (data.cost_price !== undefined) product.costPrice = Math.max(0, Math.round(Number(data.cost_price) || 0))
    if (data.selling_price !== undefined) product.sellingPrice = Math.max(0, Math.round(Number(data.selling_price) || 0))
    if (data.stock_quantity !== undefined) product.stockQuantity = Math.max(0, Math.round(Number(data.stock_quantity) || 0))
    if (data.low_stock_threshold !== undefined) {
      product.lowStockThreshold = Math.max(0, Math.round(Number(data.low_stock_threshold) || 0))
    }
    if (data.expiry_date !== undefined) {
      if (data.expiry_date) {
        const dt = DateTime.fromISO(data.expiry_date)
        product.expiryDate = dt.isValid ? dt : null
      } else {
        product.expiryDate = null
      }
    }
    if (data.description !== undefined) product.description = data.description

    product.version += 1
    await product.save()
    await product.load('category')
    await product.load('supplier')
    const serialized = serializeProduct(product)
    syncHub.emit(TenantContext.get()?.code || 'main', 'product_updated', { id: serialized.id })
    return response.ok(serialized)
  }

  async deleteProduct({ params, response, authUser }: HttpContext & { authUser?: any }) {
    if (!this.ensureCatalogWriteAccess(authUser, response)) return

    const product = await Product.query().where('id', params.id).first()
    if (!product) {
      return response.status(404).json({ error: 'Product not found.' })
    }
    await product.delete()
    syncHub.emit(TenantContext.get()?.code || 'main', 'product_deleted', { id: Number(params.id) })
    return response.ok({ success: true, message: 'Product deleted.' })
  }

  async mergeProducts({ request, response, authUser }: HttpContext & { authUser?: any }) {
    if (!this.ensureCatalogWriteAccess(authUser, response)) return

    const body = request.all()
    const targetId = Number(body.target_id ?? body.targetId ?? body.target_product_id)
    let sourceIds: number[] = []
    if (Array.isArray(body.source_ids)) {
      sourceIds = body.source_ids.map((id: any) => Number(id)).filter((id: number) => Number.isFinite(id) && id > 0)
    } else if (body.source_product_id || body.source_id) {
      const single = Number(body.source_product_id ?? body.source_id)
      if (Number.isFinite(single) && single > 0) sourceIds = [single]
    }

    if (!targetId || sourceIds.length === 0) {
      return response.status(400).json({ error: 'target_id and source_ids (or source_product_id) are required.' })
    }

    const schema = TenantContext.get()?.schemaName || 'tenant_main'
    const outcome = await db.transaction(async (trx) => {
      const target = await Product.query({ client: trx }).where('id', targetId).forUpdate().first()
      if (!target) {
        return null
      }

      let addedStock = 0
      for (const srcId of sourceIds) {
        if (srcId === targetId) continue
        const src = await Product.query({ client: trx }).where('id', srcId).forUpdate().first()
        if (src) {
          addedStock += Number(src.stockQuantity) || 0

          await trx.rawQuery(`UPDATE "${schema}".sale_items SET product_id = ? WHERE product_id = ?`, [target.id, src.id])
          await trx.rawQuery(`UPDATE "${schema}".purchase_items SET product_id = ? WHERE product_id = ?`, [target.id, src.id])
          await trx.rawQuery(`UPDATE "${schema}".stock_adjustments SET product_id = ? WHERE product_id = ?`, [target.id, src.id])
          await trx.rawQuery(`UPDATE "${schema}".stock_ledger SET product_id = ? WHERE product_id = ?`, [target.id, src.id])

          await src.useTransaction(trx).delete()
        }
      }

      target.stockQuantity += addedStock
      target.version += 1
      await target.useTransaction(trx).save()
      return { target: serializeProduct(target), addedStock }
    })

    if (!outcome) {
      return response.status(404).json({ error: 'Target product not found.' })
    }

    syncHub.emit(TenantContext.get()?.code || 'main', 'product_updated', { id: targetId, source: 'merge' })
    return response.ok({ success: true, ...outcome })
  }

  // --- Categories ---
  async getCategories({ response }: HttpContext) {
    const categories = await Category.query().orderBy('name', 'asc')
    return response.ok(
      categories.map((c) => ({
        id: c.id,
        name: c.name,
        description: c.description,
        created_at: c.createdAt?.toISO?.() || null,
        updated_at: c.updatedAt?.toISO?.() || null,
      }))
    )
  }

  async storeCategory({ request, response, authUser }: HttpContext & { authUser?: any }) {
    if (!this.ensureCatalogWriteAccess(authUser, response)) return
    const { name, description } = request.all()
    if (!name || !String(name).trim()) {
      return response.status(400).json({ error: 'Category name is required.' })
    }
    const category = await Category.create({ name: String(name).trim(), description: description || null })
    syncHub.emit(TenantContext.get()?.code || 'main', 'category_created', { id: category.id })
    return response.status(201).json({
      id: category.id,
      name: category.name,
      description: category.description,
      created_at: category.createdAt?.toISO?.() || null,
    })
  }

  async updateCategory({ params, request, response, authUser }: HttpContext & { authUser?: any }) {
    if (!this.ensureCatalogWriteAccess(authUser, response)) return
    const category = await Category.query().where('id', params.id).first()
    if (!category) {
      return response.status(404).json({ error: 'Category not found.' })
    }
    const { name, description } = request.all()
    if (name && String(name).trim()) category.name = String(name).trim()
    if (description !== undefined) category.description = description
    await category.save()
    syncHub.emit(TenantContext.get()?.code || 'main', 'category_created', { id: category.id })
    return response.ok({
      id: category.id,
      name: category.name,
      description: category.description,
      created_at: category.createdAt?.toISO?.() || null,
    })
  }

  async deleteCategory({ params, response, authUser }: HttpContext & { authUser?: any }) {
    if (!this.ensureCatalogWriteAccess(authUser, response)) return
    const category = await Category.query().where('id', params.id).first()
    if (!category) {
      return response.status(404).json({ error: 'Category not found.' })
    }
    await category.delete()
    syncHub.emit(TenantContext.get()?.code || 'main', 'category_created', { id: Number(params.id) })
    return response.ok({ success: true, message: 'Category deleted.' })
  }

  // --- Suppliers ---
  async getSuppliers({ response }: HttpContext) {
    const suppliers = await Supplier.query().orderBy('name', 'asc')
    return response.ok(
      suppliers.map((s) => ({
        id: s.id,
        name: s.name,
        contact_person: null,
        phone: s.phone,
        email: s.email,
        address: s.address,
        created_at: s.createdAt?.toISO?.() || null,
        updated_at: s.updatedAt?.toISO?.() || null,
      }))
    )
  }

  async storeSupplier({ request, response, authUser }: HttpContext & { authUser?: any }) {
    if (!this.ensureCatalogWriteAccess(authUser, response)) return
    const { name, phone, email, address } = request.all()
    if (!name || !String(name).trim()) {
      return response.status(400).json({ error: 'Supplier name is required.' })
    }
    const supplier = await Supplier.create({
      name: String(name).trim(),
      phone: phone || null,
      email: email || null,
      address: address || null,
    })
    syncHub.emit(TenantContext.get()?.code || 'main', 'supplier_created', { id: supplier.id })
    return response.status(201).json({
      id: supplier.id,
      name: supplier.name,
      contact_person: null,
      phone: supplier.phone,
      email: supplier.email,
      address: supplier.address,
      created_at: supplier.createdAt?.toISO?.() || null,
    })
  }

  async updateSupplier({ params, request, response, authUser }: HttpContext & { authUser?: any }) {
    if (!this.ensureCatalogWriteAccess(authUser, response)) return
    const supplier = await Supplier.query().where('id', params.id).first()
    if (!supplier) {
      return response.status(404).json({ error: 'Supplier not found.' })
    }
    const { name, phone, email, address } = request.all()
    if (name && String(name).trim()) supplier.name = String(name).trim()
    if (phone !== undefined) supplier.phone = phone
    if (email !== undefined) supplier.email = email
    if (address !== undefined) supplier.address = address
    await supplier.save()
    syncHub.emit(TenantContext.get()?.code || 'main', 'supplier_created', { id: supplier.id })
    return response.ok({
      id: supplier.id,
      name: supplier.name,
      contact_person: null,
      phone: supplier.phone,
      email: supplier.email,
      address: supplier.address,
      created_at: supplier.createdAt?.toISO?.() || null,
    })
  }

  async deleteSupplier({ params, response, authUser }: HttpContext & { authUser?: any }) {
    if (!this.ensureCatalogWriteAccess(authUser, response)) return
    const supplier = await Supplier.query().where('id', params.id).first()
    if (!supplier) {
      return response.status(404).json({ error: 'Supplier not found.' })
    }
    await supplier.delete()
    syncHub.emit(TenantContext.get()?.code || 'main', 'supplier_created', { id: Number(params.id) })
    return response.ok({ success: true, message: 'Supplier deleted.' })
  }
}
