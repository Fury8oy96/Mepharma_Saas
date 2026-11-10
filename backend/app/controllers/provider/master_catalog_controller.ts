import { HttpContext } from '@adonisjs/core/http'
import MasterMedicine from '#models/core/master_medicine'
import Product from '#models/tenant/product'
import Category from '#models/tenant/category'

export default class MasterCatalogController {
  /**
   * Search and list items from the Global Master Drug Catalog.
   * Accessible by Provider Superadmins and Pharmacy Admins for formulary browsing.
   */
  async index({ request, response }: HttpContext) {
    const { search, category, page = 1, limit = 50 } = request.qs()

    const query = MasterMedicine.query()

    if (search) {
      query.where((q) => {
        q.whereILike('brand_name', `%${search}%`)
          .orWhereILike('generic_name', `%${search}%`)
          .orWhereILike('barcode', `%${search}%`)
          .orWhereILike('atc_code', `%${search}%`)
      })
    }

    if (category) {
      query.where('category_name', category)
    }

    const items = await query.orderBy('brand_name', 'asc').paginate(Number(page), Number(limit))
    return response.ok(items)
  }

  /**
   * Add a new drug entry to the Global Master Catalog (Provider Superadmin only).
   */
  async store({ request, response }: HttpContext) {
    const data = request.only([
      'brandName',
      'genericName',
      'dosageForm',
      'strength',
      'barcode',
      'categoryName',
      'atcCode',
      'prescriptionSchedule',
      'defaultCostPrice',
      'defaultSellingPrice',
      'description',
    ])

    const medicine = await MasterMedicine.create({
      brandName: data.brandName,
      genericName: data.genericName,
      dosageForm: data.dosageForm || 'Tablet',
      strength: data.strength || '',
      barcode: data.barcode || null,
      categoryName: data.categoryName || null,
      atcCode: data.atcCode || null,
      prescriptionSchedule: data.prescriptionSchedule || 'OTC',
      defaultCostPrice: Number(data.defaultCostPrice) || 0,
      defaultSellingPrice: Number(data.defaultSellingPrice) || 0,
      description: data.description || null,
    })

    return response.status(201).json(medicine)
  }

  /**
   * Update a master drug item (Provider Superadmin only).
   */
  async update({ params, request, response }: HttpContext) {
    const medicine = await MasterMedicine.find(params.id)
    if (!medicine) {
      return response.status(404).json({ error: 'Master medicine entry not found.' })
    }

    const data = request.all()
    medicine.merge(data)
    await medicine.save()

    return response.ok(medicine)
  }

  /**
   * Remove an item from the master catalog (Provider Superadmin only).
   */
  async destroy({ params, response }: HttpContext) {
    const medicine = await MasterMedicine.find(params.id)
    if (!medicine) {
      return response.status(404).json({ error: 'Master medicine entry not found.' })
    }

    await medicine.delete()
    return response.ok({ message: 'Master medicine entry removed.' })
  }

  /**
   * Import one or more medicines from the Global Master Catalog into the current tenant branch.
   * Executed under the tenant's isolated PostgreSQL search_path.
   */
  async importToTenant({ request, response }: HttpContext) {
    const { medicineIds, initialStock = 0 } = request.all()

    if (!Array.isArray(medicineIds) || medicineIds.length === 0) {
      return response.status(400).json({ error: 'medicineIds array is required.' })
    }

    const masters = await MasterMedicine.query().whereIn('id', medicineIds)
    const importedProducts: Product[] = []

    for (const master of masters) {
      // Check if product with this barcode or matching name already exists in this tenant
      let existing: Product | null = null
      if (master.barcode) {
        existing = await Product.findBy('barcode', master.barcode)
      }
      if (!existing) {
        const fullName = `${master.brandName} (${master.genericName}) ${master.strength}`.trim()
        existing = await Product.findBy('name', fullName)
      }

      if (existing) {
        // Skip duplicate or return existing
        importedProducts.push(existing)
        continue
      }

      // Resolve or create Category in tenant schema
      let categoryId: number | null = null
      if (master.categoryName) {
        const cat = await Category.firstOrCreate(
          { name: master.categoryName },
          { name: master.categoryName, description: 'Imported from Global Formulary' }
        )
        categoryId = cat.id
      }

      const cleanName = `${master.brandName} (${master.genericName}) ${master.strength}`.trim()
      const sku = `MED-${master.id}-${Math.floor(1000 + Math.random() * 9000)}`

      const product = await Product.create({
        name: cleanName,
        sku: sku,
        barcode: master.barcode || null,
        categoryId: categoryId,
        costPrice: master.defaultCostPrice,
        sellingPrice: master.defaultSellingPrice,
        stockQuantity: Number(initialStock) || 0,
        lowStockThreshold: 10,
        version: 1,
        description: master.description || `Formulary: ${master.dosageForm} - ${master.prescriptionSchedule}`,
      })

      importedProducts.push(product)
    }

    return response.status(201).json({
      message: `Successfully imported ${importedProducts.length} medicine(s) into pharmacy catalog.`,
      importedCount: importedProducts.length,
      products: importedProducts,
    })
  }
}
