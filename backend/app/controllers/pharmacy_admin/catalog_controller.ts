import { HttpContext } from '@adonisjs/core/http'
import { DateTime } from 'luxon'
import Product from '#models/tenant/product'
import Category from '#models/tenant/category'
import Supplier from '#models/tenant/supplier'
import db from '@adonisjs/lucid/services/db'

export default class CatalogController {
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
    return response.ok(products)
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
    return response.ok(product)
  }

  async storeProduct({ request, response }: HttpContext) {
    const data = request.all()
    let expiryDate: DateTime | null = null
    if (data.expiry_date) {
      const dt = DateTime.fromISO(data.expiry_date)
      if (dt.isValid) expiryDate = dt
    }
    const product = await Product.create({
      name: data.name,
      sku: data.sku || `SKU-${Date.now()}`,
      barcode: data.barcode || null,
      categoryId: data.category_id || null,
      supplierId: data.supplier_id || null,
      costPrice: Number(data.cost_price) || 0,
      sellingPrice: Number(data.selling_price) || 0,
      stockQuantity: Number(data.stock_quantity) || 0,
      lowStockThreshold: Number(data.low_stock_threshold) || 10,
      expiryDate,
      version: 1,
      description: data.description || null,
    })

    return response.status(201).json(product)
  }

  async updateProduct({ params, request, response }: HttpContext) {
    const product = await Product.query().where('id', params.id).first()
    if (!product) {
      return response.status(404).json({ error: 'Product not found.' })
    }

    const data = request.all()
    if (data.name) product.name = data.name
    if (data.barcode !== undefined) product.barcode = data.barcode || null
    if (data.category_id !== undefined) product.categoryId = data.category_id || null
    if (data.supplier_id !== undefined) product.supplierId = data.supplier_id || null
    if (data.cost_price !== undefined) product.costPrice = Number(data.cost_price)
    if (data.selling_price !== undefined) product.sellingPrice = Number(data.selling_price)
    if (data.stock_quantity !== undefined) product.stockQuantity = Number(data.stock_quantity)
    if (data.low_stock_threshold !== undefined) product.lowStockThreshold = Number(data.low_stock_threshold)
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
    return response.ok(product)
  }

  async deleteProduct({ params, response }: HttpContext) {
    const product = await Product.query().where('id', params.id).first()
    if (!product) {
      return response.status(404).json({ error: 'Product not found.' })
    }
    await product.delete()
    return response.ok({ success: true, message: 'Product deleted.' })
  }

  async mergeProducts({ request, response }: HttpContext) {
    const { target_id, source_ids } = request.all()
    if (!target_id || !Array.isArray(source_ids) || source_ids.length === 0) {
      return response.status(400).json({ error: 'target_id and source_ids array are required.' })
    }

    return await db.transaction(async (trx) => {
      const target = await Product.query({ client: trx }).where('id', target_id).first()
      if (!target) {
        return response.status(404).json({ error: 'Target product not found.' })
      }

      let addedStock = 0
      for (const srcId of source_ids) {
        if (srcId === target_id) continue
        const src = await Product.query({ client: trx }).where('id', srcId).first()
        if (src) {
          addedStock += src.stockQuantity
          await src.useTransaction(trx).delete()
        }
      }

      target.stockQuantity += addedStock
      target.version += 1
      await target.useTransaction(trx).save()

      return response.ok({ success: true, target, addedStock })
    })
  }

  // --- Categories ---
  async getCategories({ response }: HttpContext) {
    const categories = await Category.query().orderBy('name', 'asc')
    return response.ok(categories)
  }

  async storeCategory({ request, response }: HttpContext) {
    const { name, description } = request.all()
    const category = await Category.create({ name, description })
    return response.status(201).json(category)
  }

  async updateCategory({ params, request, response }: HttpContext) {
    const category = await Category.query().where('id', params.id).first()
    if (!category) {
      return response.status(404).json({ error: 'Category not found.' })
    }
    const { name, description } = request.all()
    if (name) category.name = name
    if (description !== undefined) category.description = description
    await category.save()
    return response.ok(category)
  }

  async deleteCategory({ params, response }: HttpContext) {
    const category = await Category.query().where('id', params.id).first()
    if (!category) {
      return response.status(404).json({ error: 'Category not found.' })
    }
    await category.delete()
    return response.ok({ success: true, message: 'Category deleted.' })
  }

  // --- Suppliers ---
  async getSuppliers({ response }: HttpContext) {
    const suppliers = await Supplier.query().orderBy('name', 'asc')
    return response.ok(suppliers)
  }

  async storeSupplier({ request, response }: HttpContext) {
    const { name, phone, email, address } = request.all()
    const supplier = await Supplier.create({ name, phone, email, address })
    return response.status(201).json(supplier)
  }

  async updateSupplier({ params, request, response }: HttpContext) {
    const supplier = await Supplier.query().where('id', params.id).first()
    if (!supplier) {
      return response.status(404).json({ error: 'Supplier not found.' })
    }
    const { name, phone, email, address } = request.all()
    if (name) supplier.name = name
    if (phone !== undefined) supplier.phone = phone
    if (email !== undefined) supplier.email = email
    if (address !== undefined) supplier.address = address
    await supplier.save()
    return response.ok(supplier)
  }

  async deleteSupplier({ params, response }: HttpContext) {
    const supplier = await Supplier.query().where('id', params.id).first()
    if (!supplier) {
      return response.status(404).json({ error: 'Supplier not found.' })
    }
    await supplier.delete()
    return response.ok({ success: true, message: 'Supplier deleted.' })
  }
}
