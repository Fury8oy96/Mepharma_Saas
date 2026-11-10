import { HttpContext } from '@adonisjs/core/http'
import Setting from '#models/tenant/setting'
import Terminal from '#models/core/terminal'
import db from '@adonisjs/lucid/services/db'

export default class SettingsController {
  async index({ response }: HttpContext) {
    const list = await Setting.query()
    const map: Record<string, string> = {}
    for (const item of list) {
      map[item.key] = item.value
    }
    return response.ok(map)
  }

  async getStore({ request, response, tenant }: HttpContext) {
    const list = await Setting.query()
    const rawMap: Record<string, string> = {}
    for (const item of list) {
      rawMap[item.key] = item.value
    }

    // Dynamic Seat & Branch Number Calculation
    let branchNumber = 1
    const hwId = request.header('x-terminal-hardware-id')
    if (hwId && tenant) {
      try {
        const activeTerminals = await Terminal.query()
          .where('tenant_id', tenant.id)
          .where('is_active', true)
          .orderBy('id', 'asc')
        const idx = activeTerminals.findIndex(t => t.hardwareUuid === hwId)
        if (idx >= 0) {
          branchNumber = idx + 1
        }
      } catch (_) {}
    }

    const storeName = rawMap['store_name'] || rawMap['name'] || rawMap['pharmacy_name'] || tenant?.name || 'MePharma Central Pharmacy'
    const storeAddress = rawMap['store_address'] || rawMap['address'] || ''
    const storePhone = rawMap['store_phone'] || rawMap['phone'] || ''
    const storeTaxId = rawMap['store_tax_id'] || rawMap['tax_number'] || rawMap['taxNumber'] || ''
    const taxRate = rawMap['tax_rate'] || rawMap['taxRate'] || rawMap['default_tax_rate'] || '0'
    const currency = rawMap['currency'] || rawMap['currency_symbol'] || rawMap['currencySymbol'] || 'SDG'
    const currencySymbol = rawMap['currency_symbol'] || rawMap['currency'] || rawMap['currencySymbol'] || 'SDG'
    const lowStockThreshold = rawMap['low_stock_threshold'] || rawMap['lowStockThreshold'] || '10'
    const profitMargin = rawMap['profit_margin'] || rawMap['profitMargin'] || '0.3'
    const receiptFooter = rawMap['receipt_footer'] || rawMap['receiptFooter'] || 'Thank you for choosing MePharma!'
    const receiptHeader = rawMap['receipt_header'] || rawMap['receiptHeader'] || storeName
    const receiptStyle = rawMap['receipt_style'] || rawMap['receiptStyle'] || 'modern'
    const receiptFormat = rawMap['receipt_format'] || rawMap['receiptFormat'] || '80mm'
    const receiptFont = rawMap['receipt_font'] || rawMap['receiptFont'] || 'Tajawal'

    const unified = {
      ...rawMap,
      // Dot keys for desktop POS ApiSettingsRepository
      'store.name': storeName,
      'store.address': storeAddress,
      'store.phone': storePhone,
      'store.tax_id': storeTaxId,
      'store.tax_rate': taxRate,
      'store.currency_symbol': currencySymbol,
      'store.currency': currency,
      'store.low_stock_threshold': lowStockThreshold,
      'store.profit_margin': profitMargin,
      'store.receipt_footer': receiptFooter,
      'store.receipt_header': receiptHeader,
      'store.receipt_style': receiptStyle,
      'store.receipt_format': receiptFormat,
      'store.receipt_font': receiptFont,
      'store.branch_number': String(branchNumber),
      'store.seat_number': String(branchNumber),

      // Snake keys
      store_name: storeName,
      store_address: storeAddress,
      store_phone: storePhone,
      store_tax_id: storeTaxId,
      tax_rate: taxRate,
      currency_symbol: currencySymbol,
      currency: currency,
      low_stock_threshold: lowStockThreshold,
      profit_margin: profitMargin,
      receipt_footer: receiptFooter,
      receipt_header: receiptHeader,
      receipt_style: receiptStyle,
      receipt_format: receiptFormat,
      receipt_font: receiptFont,
      branch_number: branchNumber,
      seat_number: branchNumber,

      // Camel keys for web dashboard SettingsTab
      name: storeName,
      address: storeAddress,
      phone: storePhone,
      taxNumber: storeTaxId,
      taxRate: taxRate,
      lowStockThreshold: lowStockThreshold,
      profitMargin: profitMargin,
      receiptFooter: receiptFooter,
      receiptHeader: receiptHeader,
      receiptStyle: receiptStyle,
      receiptFormat: receiptFormat,
      receiptFont: receiptFont,
      branchNumber: branchNumber,
      seatNumber: branchNumber,
    }

    return response.ok(unified)
  }

  async update({ request, response }: HttpContext) {
    const data = request.all()
    const aliasMap: Record<string, string[]> = {
      name: ['store_name', 'store.name'],
      store_name: ['name', 'store.name'],
      'store.name': ['name', 'store_name'],
      phone: ['store_phone', 'store.phone'],
      store_phone: ['phone', 'store.phone'],
      'store.phone': ['phone', 'store_phone'],
      address: ['store_address', 'store.address'],
      store_address: ['address', 'store.address'],
      'store.address': ['address', 'store_address'],
      taxNumber: ['store_tax_id', 'store.tax_id', 'tax_number'],
      store_tax_id: ['taxNumber', 'store.tax_id', 'tax_number'],
      'store.tax_id': ['taxNumber', 'store_tax_id'],
      taxRate: ['tax_rate', 'store.tax_rate'],
      tax_rate: ['taxRate', 'store.tax_rate'],
      'store.tax_rate': ['taxRate', 'tax_rate'],
      currency: ['currency_symbol', 'store.currency_symbol', 'store.currency'],
      currencySymbol: ['currency', 'currency_symbol', 'store.currency_symbol'],
      currency_symbol: ['currency', 'store.currency_symbol'],
      'store.currency_symbol': ['currency', 'currency_symbol'],
      profitMargin: ['profit_margin', 'store.profit_margin'],
      profit_margin: ['profitMargin', 'store.profit_margin'],
      'store.profit_margin': ['profitMargin', 'profit_margin'],
      receiptFooter: ['receipt_footer', 'store.receipt_footer'],
      receipt_footer: ['receiptFooter', 'store.receipt_footer'],
      'store.receipt_footer': ['receiptFooter', 'receipt_footer'],
      receiptHeader: ['receipt_header', 'store.receipt_header'],
      receipt_header: ['receiptHeader', 'store.receipt_header'],
      'store.receipt_header': ['receiptHeader', 'receipt_header'],
      receiptStyle: ['receipt_style', 'store.receipt_style'],
      receipt_style: ['receiptStyle', 'store.receipt_style'],
      'store.receipt_style': ['receiptStyle', 'receipt_style'],
      receiptFormat: ['receipt_format', 'store.receipt_format'],
      receipt_format: ['receiptFormat', 'store.receipt_format'],
      'store.receipt_format': ['receiptFormat', 'receipt_format'],
      receiptFont: ['receipt_font', 'store.receipt_font'],
      receipt_font: ['receiptFont', 'store.receipt_font'],
      'store.receipt_font': ['receiptFont', 'receipt_font'],
    }

    for (const [key, value] of Object.entries(data)) {
      if (typeof value === 'string' || typeof value === 'number') {
        const strVal = String(value)
        const item = await Setting.firstOrNew({ key }, { key, value: strVal })
        item.value = strVal
        await item.save()

        if (aliasMap[key]) {
          for (const alias of aliasMap[key]) {
            const aliasItem = await Setting.firstOrNew({ key: alias }, { key: alias, value: strVal })
            aliasItem.value = strVal
            await aliasItem.save()
          }
        }
      }
    }
    return response.ok({ success: true, settings: data })
  }

  async applyMargin(ctx: HttpContext) {
    const { request, response } = ctx
    const tenant = (ctx as any).tenant
    const schema = tenant?.schemaName || 'tenant_main'
    const { margin_percent, category_id } = request.all()
    const margin = Number(margin_percent) || 20

    let query = `UPDATE "${schema}".products SET selling_price = ROUND(cost_price * (1 + ? / 100.0), 2) WHERE cost_price > 0`
    const bindings: any[] = [margin]

    if (category_id) {
      query += ' AND category_id = ?'
      bindings.push(category_id)
    }

    await db.rawQuery(query, bindings)
    return response.ok({ success: true, message: `Applied ${margin}% margin successfully.` })
  }
}
