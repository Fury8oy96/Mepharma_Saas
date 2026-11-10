import { HttpContext } from '@adonisjs/core/http'
import Purchase from '#models/tenant/purchase'
import PurchaseItem from '#models/tenant/purchase_item'
import Product from '#models/tenant/product'
import Supplier from '#models/tenant/supplier'
import StockAdjustment from '#models/tenant/stock_adjustment'
import db from '@adonisjs/lucid/services/db'
import { TenantContext } from '#core/tenancy/tenant_context'

function mapPurchase(p: Purchase) {
  const items = p.items ? p.items.map((it) => ({
    id: it.id,
    purchase_id: it.purchaseId,
    purchaseId: it.purchaseId,
    product_id: it.productId,
    productId: it.productId,
    product_name: it.productName,
    productName: it.productName,
    quantity: it.quantity,
    unit_cost: it.unitCost,
    unitCost: it.unitCost,
    cost_price: it.unitCost,
    costPrice: it.unitCost,
    subtotal: it.subtotal,
    total_cost: it.subtotal,
    totalCost: it.subtotal,
    expiry_date: it.expiryDate ? it.expiryDate.toISODate() : null,
    expiryDate: it.expiryDate ? it.expiryDate.toISODate() : null,
  })) : []

  return {
    id: p.id,
    invoice_number: p.invoiceNumber,
    invoiceNumber: p.invoiceNumber,
    purchase_number: p.invoiceNumber,
    purchaseNumber: p.invoiceNumber,
    supplier_id: p.supplierId,
    supplierId: p.supplierId,
    supplier_name: p.supplier?.name || null,
    supplierName: p.supplier?.name || null,
    user_id: p.userId,
    userId: p.userId,
    subtotal: Number(p.subtotal || 0),
    tax_amount: Number(p.taxAmount || 0),
    taxAmount: Number(p.taxAmount || 0),
    total_amount: Number(p.totalAmount || 0),
    totalAmount: Number(p.totalAmount || 0),
    paid_amount: Number(p.paidAmount || 0),
    paidAmount: Number(p.paidAmount || 0),
    status: p.status, // 'pending' | 'approved' | 'received'
    notes: p.notes,
    purchase_date: p.createdAt ? p.createdAt.toISODate() : new Date().toISOString().slice(0, 10),
    purchaseDate: p.createdAt ? p.createdAt.toISODate() : new Date().toISOString().slice(0, 10),
    created_at: p.createdAt ? p.createdAt.toISO() : new Date().toISOString(),
    createdAt: p.createdAt ? p.createdAt.toISO() : new Date().toISOString(),
    items,
  }
}

export default class ProcurementController {
  async nextNumber({ response }: HttpContext) {
    const today = new Date().toISOString().slice(0, 10).replace(/-/g, '')
    const prefix = `PO-${today}-`
    const tenant = TenantContext.get()
    const schema = tenant?.schemaName || 'tenant_main'
    const countRes = await db.rawQuery(`SELECT COUNT(*) as count FROM "${schema}".purchases WHERE invoice_number LIKE ?`, [`${prefix}%`])
    const count = parseInt(countRes.rows[0]?.count || '0', 10)
    const number = `${prefix}${String(count + 1).padStart(4, '0')}`
    return response.ok({ number, nextNumber: number })
  }

  async index({ response }: HttpContext) {
    const purchases = await Purchase.query()
      .preload('supplier')
      .preload('items')
      .orderBy('id', 'desc')
      .limit(200)

    return response.ok(purchases.map(mapPurchase))
  }

  async store({ request, response, authUser }: HttpContext) {
    const body = request.all()
    const supplier_id = body.supplier_id ?? body.supplierId ?? null
    const user_id = body.user_id ?? body.userId ?? authUser?.id ?? null
    const requestedStatus = body.status ? String(body.status).toLowerCase() : 'pending'
    const notes = body.notes || null
    const rawItems: any[] = Array.isArray(body.items) ? body.items : []

    if (rawItems.length === 0) {
      return response.status(422).json({ error: 'Purchase order must have at least one line item.' })
    }

    return await db.transaction(async (trx) => {
      const tenant = TenantContext.get()
      const schema = tenant?.schemaName || 'tenant_main'
      await trx.rawQuery(`SET search_path TO "${schema}", public;`)

      // 1. Calculate totals and sanitize line items
      let subtotal = 0
      const preparedItems: Array<{
        productId: number | null
        productName: string
        quantity: number
        unitCost: number
        subtotal: number
      }> = []

      for (const item of rawItems) {
        const pId = item.product_id ?? item.productId ?? null
        let pName = (item.product_name ?? item.productName ?? '').trim()
        const qty = Math.max(1, parseInt(item.quantity, 10) || 1)
        let cost = Math.max(0, parseInt(item.cost_price ?? item.costPrice ?? item.unit_cost ?? item.unitCost ?? '0', 10) || 0)

        // Lookup product info if productId provided but name or cost omitted
        if (pId && pId !== 0) {
          const existingProd = await Product.query({ client: trx }).where('id', pId).first()
          if (existingProd) {
            if (!pName) pName = existingProd.name
            if (cost === 0 && existingProd.costPrice > 0) cost = existingProd.costPrice
          }
        }

        if (!pName) {
          pName = `Medicine (Item #${preparedItems.length + 1})`
        }

        const lineTotal = cost * qty
        subtotal += lineTotal

        preparedItems.push({
          productId: (pId && pId !== 0) ? pId : null,
          productName: pName,
          quantity: qty,
          unitCost: cost,
          subtotal: lineTotal,
        })

        // If explicitly created as 'received' or 'approved', immediately stock inventory
        if (requestedStatus === 'received' || requestedStatus === 'approved') {
          if (pId && pId !== 0) {
            const prod = await Product.query({ client: trx }).where('id', pId).first()
            if (prod) {
              prod.stockQuantity += qty
              if (cost > 0) prod.costPrice = cost
              prod.version += 1
              await prod.useTransaction(trx).save()

              await StockAdjustment.create({
                productId: prod.id,
                userId: user_id,
                type: 'add',
                quantity: qty,
                reason: `Stock replenished from PO`,
              }, { client: trx })
            }
          }
        }
      }

      // 2. Generate invoice number if not passed
      let invoiceNumber = body.invoice_number ?? body.invoiceNumber
      if (!invoiceNumber) {
        const today = new Date().toISOString().slice(0, 10).replace(/-/g, '')
        const prefix = `PO-${today}-`
        const cRes = await trx.rawQuery(`SELECT COUNT(*) as count FROM "${schema}".purchases WHERE invoice_number LIKE ?`, [`${prefix}%`])
        const count = parseInt(cRes.rows[0]?.count || '0', 10)
        invoiceNumber = `${prefix}${String(count + 1).padStart(4, '0')}`
      }

      // 3. Create Purchase header
      let finalSupplierId = supplier_id
      if (finalSupplierId) {
        const supExists = await Supplier.query({ client: trx }).where('id', finalSupplierId).first()
        if (!supExists) finalSupplierId = null
      }

      const purchase = await Purchase.create({
        invoiceNumber,
        supplierId: finalSupplierId,
        userId: user_id,
        subtotal,
        totalAmount: subtotal,
        paidAmount: (requestedStatus === 'received' || requestedStatus === 'approved') ? subtotal : 0,
        status: requestedStatus, // default 'pending'
        notes,
      }, { client: trx })

      // 4. Create Purchase Items
      await PurchaseItem.createMany(
        preparedItems.map((d) => ({
          ...d,
          purchaseId: purchase.id,
        })),
        { client: trx }
      )

      await purchase.load('supplier')
      await purchase.load('items')

      return response.status(201).json(mapPurchase(purchase))
    })
  }

  async show({ params, response }: HttpContext) {
    const purchase = await Purchase.query()
      .where('id', params.id)
      .preload('supplier')
      .preload('items')
      .first()

    if (!purchase) {
      return response.status(404).json({ error: 'Purchase order not found.' })
    }

    const mapped = mapPurchase(purchase)
    return response.ok({
      ...mapped,
      purchase: mapped,
      items: mapped.items,
    })
  }

  async update({ params, request, response, authUser }: HttpContext) {
    const userRole = (authUser?.role || '').toLowerCase()
    if (userRole && !['pharmacy_admin', 'admin', 'super_admin', 'branch_admin'].includes(userRole)) {
      return response.status(403).json({
        error: 'Access Forbidden',
        message: 'Only Pharmacy Admins and Branch Administrators are authorized to edit purchase orders.',
      })
    }

    const purchase = await Purchase.query()
      .where('id', params.id)
      .preload('supplier')
      .preload('items')
      .first()

    if (!purchase) {
      return response.status(404).json({ error: 'Purchase order not found.' })
    }

    if (purchase.status !== 'pending') {
      return response.status(400).json({
        error: `Cannot edit purchase order #${purchase.invoiceNumber} because its status is already '${purchase.status}'.`,
      })
    }

    const body = request.all()
    const supplier_id = body.supplier_id ?? body.supplierId ?? purchase.supplierId
    const notes = body.notes !== undefined ? body.notes : purchase.notes
    const rawItems: any[] = Array.isArray(body.items) ? body.items : []

    if (rawItems.length === 0) {
      return response.status(422).json({ error: 'Purchase order must have at least one line item.' })
    }

    return await db.transaction(async (trx) => {
      const tenant = TenantContext.get()
      const schema = tenant?.schemaName || 'tenant_main'
      await trx.rawQuery(`SET search_path TO "${schema}", public;`)

      let finalSupplierId = supplier_id
      if (finalSupplierId) {
        const supExists = await Supplier.query({ client: trx }).where('id', finalSupplierId).first()
        if (!supExists) finalSupplierId = null
      }

      purchase.supplierId = finalSupplierId
      purchase.notes = notes

      // Delete existing line items and recreate with updated sanitized values
      await PurchaseItem.query({ client: trx }).where('purchaseId', purchase.id).delete()

      let subtotal = 0
      const newItems: any[] = []

      for (const item of rawItems) {
        const pId = item.product_id ?? item.productId ?? null
        let pName = (item.product_name ?? item.productName ?? '').trim()
        const qty = Math.max(1, parseInt(item.quantity, 10) || 1)
        let cost = Math.max(
          0,
          parseInt(item.cost_price ?? item.costPrice ?? item.unit_cost ?? item.unitCost ?? '0', 10) || 0
        )

        if (pId && pId !== 0) {
          const prod = await Product.query({ client: trx }).where('id', pId).first()
          if (prod) {
            if (!pName) pName = prod.name
            if (cost === 0 && prod.costPrice > 0) cost = prod.costPrice
          }
        }

        if (!pName) {
          pName = `Medicine (Item #${newItems.length + 1})`
        }

        const lineTotal = cost * qty
        subtotal += lineTotal

        newItems.push({
          purchaseId: purchase.id,
          productId: pId && pId !== 0 ? pId : null,
          productName: pName,
          quantity: qty,
          unitCost: cost,
          subtotal: lineTotal,
        })
      }

      await PurchaseItem.createMany(newItems, { client: trx })

      purchase.subtotal = subtotal
      purchase.totalAmount = subtotal
      await purchase.useTransaction(trx).save()

      await purchase.load('supplier')
      await purchase.load('items')

      const mapped = mapPurchase(purchase)
      return response.ok({
        ...mapped,
        purchase: mapped,
        items: mapped.items,
      })
    })
  }

  async approve({ params, request, response, authUser }: HttpContext) {
    const userRole = (authUser?.role || '').toLowerCase()
    if (userRole && !['branch_admin', 'pharmacy_admin', 'admin', 'supervisor', 'super_admin'].includes(userRole)) {
      return response.status(403).json({
        error: 'Access Forbidden',
        message: 'Only Branch Administrators, Pharmacy Admins, or Supervisors can approve purchase orders.',
      })
    }

    const purchase = await Purchase.query()
      .where('id', params.id)
      .preload('supplier')
      .preload('items')
      .first()

    if (!purchase) {
      return response.status(404).json({ error: 'Purchase order not found.' })
    }

    if (purchase.status === 'approved') {
      return response.status(400).json({
        error: `Purchase order #${purchase.invoiceNumber} is already approved and stocked.`,
      })
    }

    const body = request.all()
    const supplier_id = body.supplier_id ?? body.supplierId ?? null
    const resolveItems: any[] = Array.isArray(body.resolve_items)
      ? body.resolve_items
      : (Array.isArray(body.items) ? body.items : [])

    return await db.transaction(async (trx) => {
      const tenant = TenantContext.get()
      const schema = tenant?.schemaName || 'tenant_main'
      await trx.rawQuery(`SET search_path TO "${schema}", public;`)

      if (supplier_id) {
        const supExists = await Supplier.query({ client: trx }).where('id', supplier_id).first()
        purchase.supplierId = supExists ? supExists.id : null
      }

      let grandTotal = 0

      // Map existing line items by ID
      const existingItems = await PurchaseItem.query({ client: trx }).where('purchaseId', purchase.id)
      const existingItemsMap = new Map<number, PurchaseItem>()
      for (const it of existingItems) {
        existingItemsMap.set(it.id, it)
      }

      const itemsToProcess: Array<{
        pItem?: PurchaseItem
        pName: string
        qty: number
        cost: number
        selling: number
        catId: number | null
        barcode: string | null
        sku: string | null
        productId: number | null
      }> = []

      if (resolveItems.length > 0) {
        for (const resItem of resolveItems) {
          const rawItemId = resItem.item_id ?? resItem.itemId ?? resItem.id
          const itemId = rawItemId ? parseInt(rawItemId, 10) : null
          const pItem = itemId ? existingItemsMap.get(itemId) : undefined

          const qty = Math.max(1, parseInt(resItem.quantity ?? pItem?.quantity ?? 1, 10) || 1)
          const cost = Math.max(
            0,
            parseInt(resItem.cost_price ?? resItem.costPrice ?? resItem.unit_cost ?? resItem.unitCost ?? (pItem?.unitCost || 0), 10) || 0
          )
          let selling = parseInt(resItem.selling_price ?? resItem.sellingPrice ?? 0, 10) || 0
          const margin = parseFloat(resItem.margin_percent ?? resItem.marginPercent ?? 0) || 0

          if (selling === 0 && cost > 0 && margin > 0) {
            selling = Math.round(cost * (1 + margin / 100))
          } else if (selling === 0 && cost > 0) {
            selling = Math.round(cost * 1.30)
          }

          const rawProdId = resItem.product_id ?? resItem.productId ?? pItem?.productId
          const productId = rawProdId ? parseInt(rawProdId, 10) : null
          const pName = (resItem.product_name ?? resItem.productName ?? pItem?.productName ?? '').trim()

          itemsToProcess.push({
            pItem,
            pName,
            qty,
            cost,
            selling,
            catId: resItem.category_id ?? resItem.categoryId ?? null,
            barcode: resItem.barcode || null,
            sku: resItem.sku || null,
            productId,
          })
        }
      } else {
        // Fallback: Stock all items currently attached to the purchase
        for (const it of existingItems) {
          const qty = Math.max(1, it.quantity || 1)
          const cost = Math.max(0, it.unitCost || 0)
          const selling = Math.round(cost * 1.30)
          const pName = (it.productName || '').trim()

          itemsToProcess.push({
            pItem: it,
            pName,
            qty,
            cost,
            selling,
            catId: null,
            barcode: null,
            sku: null,
            productId: it.productId || null,
          })
        }
      }

      for (const line of itemsToProcess) {
        let product: Product | null = null

        // 1. Look up by provided productId
        if (line.productId && line.productId !== 0) {
          product = await Product.query({ client: trx }).where('id', line.productId).first()
        }

        // 2. If not found by ID or no ID provided, look up by exact name (case-insensitive)
        if (!product && line.pName) {
          product = await Product.query({ client: trx })
            .whereRaw('LOWER(TRIM(name)) = LOWER(TRIM(?))', [line.pName])
            .first()
        }

        // 3. If still not found, auto-create the product in catalog
        if (!product) {
          const prodName = line.pName || `Medicine (PO #${purchase.invoiceNumber})`
          const sku = line.sku || `SKU-${Date.now().toString().slice(-6)}-${Math.floor(100 + Math.random() * 900)}`

          product = await Product.create({
            name: prodName,
            sku,
            barcode: line.barcode,
            categoryId: line.catId,
            supplierId: purchase.supplierId,
            costPrice: line.cost,
            sellingPrice: line.selling,
            stockQuantity: 0, // will be incremented below
            lowStockThreshold: 10,
            version: 1,
          }, { client: trx })
        }

        // 4. Replenish stock & update pricing
        product.stockQuantity += line.qty
        if (line.cost > 0) product.costPrice = line.cost
        if (line.selling > 0) product.sellingPrice = line.selling
        if (line.catId) product.categoryId = line.catId
        if (line.barcode) product.barcode = line.barcode
        product.version += 1
        await product.useTransaction(trx).save()

        // 5. Create StockAdjustment entry for audit trail
        await StockAdjustment.create({
          productId: product.id,
          userId: authUser?.id || purchase.userId,
          type: 'add',
          quantity: line.qty,
          reason: `Stock replenished from approved PO #${purchase.invoiceNumber}`,
        }, { client: trx })

        // 6. Update line item with product ID and financials
        const lineTotal = line.cost * line.qty
        grandTotal += lineTotal

        if (line.pItem) {
          line.pItem.productId = product.id
          line.pItem.unitCost = line.cost
          line.pItem.subtotal = lineTotal
          await line.pItem.useTransaction(trx).save()
        }
      }

      purchase.status = 'approved'
      if (grandTotal > 0) {
        purchase.totalAmount = grandTotal
        purchase.subtotal = grandTotal
        purchase.paidAmount = grandTotal
      }
      await purchase.useTransaction(trx).save()

      await purchase.load('supplier')
      await purchase.load('items')

      return response.ok({
        message: 'Purchase approved successfully and products stocked.',
        status: 'approved',
        purchase: mapPurchase(purchase),
      })
    })
  }
}
