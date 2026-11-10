import { HttpContext } from '@adonisjs/core/http'
import Sale from '#models/tenant/sale'
import Product from '#models/tenant/product'
import Purchase from '#models/tenant/purchase'
import db from '@adonisjs/lucid/services/db'
import { TenantContext } from '#core/tenancy/tenant_context'

export default class ReportsController {
  private getSchema(ctx: HttpContext): string {
    return (ctx as any).tenant?.schemaName || TenantContext.get()?.schemaName || 'tenant_main'
  }

  async summary(ctx: HttpContext) {
    const { request, response } = ctx
    const schema = this.getSchema(ctx)
    const { from, to } = request.qs()

    // Base query for completed sales
    let salesQuery = Sale.query().where('status', 'completed')
    if (from) {
      salesQuery = salesQuery.where('created_at', '>=', from)
    }
    if (to) {
      salesQuery = salesQuery.where('created_at', '<=', to)
    }

    const totalSalesRes = await salesQuery.clone().sum('total_amount as sum')
    const grossSalesRes = await salesQuery.clone().sum('subtotal as sum')
    const salesCountRes = await salesQuery.clone().count('* as count')
    const taxRes = await salesQuery.clone().sum('tax_amount as sum')
    const discountRes = await salesQuery.clone().sum('discount as sum')

    const revenue = Number(totalSalesRes[0]?.$extras?.sum) || 0
    const grossRevenue = Number(grossSalesRes[0]?.$extras?.sum) || revenue
    const salesCount = Number(salesCountRes[0]?.$extras?.count) || 0
    const totalTax = Number(taxRes[0]?.$extras?.sum) || 0
    const totalDiscount = Number(discountRes[0]?.$extras?.sum) || 0

    // Purchases in range
    let purchasesQuery = Purchase.query()
    if (from) purchasesQuery = purchasesQuery.where('created_at', '>=', from)
    if (to) purchasesQuery = purchasesQuery.where('created_at', '<=', to)
    const purchasesSumRes = await purchasesQuery.clone().sum('total_amount as sum')
    const purchasesCountRes = await purchasesQuery.clone().count('* as count')
    const purchasesCost = Number(purchasesSumRes[0]?.$extras?.sum) || 0
    const totalPurchases = Number(purchasesCountRes[0]?.$extras?.count) || 0

    // Low stock count
    const lowStockRes = await Product.query().whereRaw('stock_quantity <= low_stock_threshold').count('* as count')
    const lowStockCount = Number(lowStockRes[0]?.$extras?.count) || 0

    // Cost of goods sold (COGS) in range
    const cogsParams: any[] = []
    let cogsWhere = "s.status = 'completed'"
    if (from) {
      cogsWhere += " AND s.created_at >= ?"
      cogsParams.push(from)
    }
    if (to) {
      cogsWhere += " AND s.created_at <= ?"
      cogsParams.push(to)
    }

    const cogsRes = await db.rawQuery(`
      SELECT 
        COALESCE(SUM(si.quantity * COALESCE(si.cost_price, p.cost_price, 0)), 0) as cogs
      FROM "${schema}".sale_items si
      JOIN "${schema}".sales s ON si.sale_id = s.id
      LEFT JOIN "${schema}".products p ON si.product_id = p.id
      WHERE ${cogsWhere};
    `, cogsParams)
    const costOfGoods = Number(cogsRes.rows[0]?.cogs) || 0

    // Refunds from returns in range
    let refundWhere = "s.status = 'completed'"
    const refundParams: any[] = []
    if (from) {
      refundWhere += " AND s.created_at >= ?"
      refundParams.push(from)
    }
    if (to) {
      refundWhere += " AND s.created_at <= ?"
      refundParams.push(to)
    }
    const refundRes = await db.rawQuery(`
      SELECT COALESCE(SUM(r.total_refund), 0) as refunds
      FROM "${schema}".returns r
      JOIN "${schema}".sales s ON r.sale_id = s.id
      WHERE ${refundWhere};
    `, refundParams)
    const refunds = Number(refundRes.rows[0]?.refunds) || 0

    const netRevenue = Math.max(0, revenue - refunds)
    const grossProfit = Math.max(0, netRevenue - costOfGoods)
    const profitMarginPct = netRevenue > 0 ? Math.round((grossProfit / netRevenue) * 1000) / 10 : 0
    const aov = salesCount > 0 ? Math.round(revenue / salesCount) : 0

    // Payment breakdown in range
    const paymentParams = [...cogsParams]
    const paymentRes = await db.rawQuery(`
      SELECT 
        COALESCE(s.payment_method, 'cash') as method,
        COUNT(*)::int as count,
        COALESCE(SUM(s.total_amount), 0)::numeric as total
      FROM "${schema}".sales s
      WHERE ${cogsWhere.replace(/si\./g, '')}
      GROUP BY s.payment_method
      ORDER BY total DESC;
    `, paymentParams)

    const salesByPayment = (paymentRes.rows || []).map((row: any) => {
      const tot = Number(row.total) || 0
      const pct = revenue > 0 ? Math.round((tot / revenue) * 1000) / 10 : 0
      return {
        method: row.method,
        count: Number(row.count) || 0,
        total: tot,
        percentage: pct,
      }
    })

    // Top products in range
    const topProductsRes = await db.rawQuery(`
      SELECT 
        si.product_id as id,
        si.product_name as name,
        COALESCE(SUM(si.quantity), 0)::int as quantity,
        COALESCE(SUM(si.total), 0)::numeric as revenue,
        COALESCE(SUM(si.quantity * COALESCE(si.cost_price, p.cost_price, 0)), 0)::numeric as cost
      FROM "${schema}".sale_items si
      JOIN "${schema}".sales s ON si.sale_id = s.id
      LEFT JOIN "${schema}".products p ON si.product_id = p.id
      WHERE ${cogsWhere}
      GROUP BY si.product_id, si.product_name
      ORDER BY revenue DESC
      LIMIT 10;
    `, cogsParams)

    const topProducts = (topProductsRes.rows || []).map((row: any) => ({
      name: row.name,
      quantity: Number(row.quantity) || 0,
      revenue: Number(row.revenue) || 0,
      cost: Number(row.cost) || 0,
    }))

    // Daily trends in range
    const trendsRes = await db.rawQuery(`
      SELECT 
        TO_CHAR(s.created_at, 'YYYY-MM-DD') as date,
        COUNT(DISTINCT s.id)::int as count,
        COALESCE(SUM(si.total), 0)::numeric as revenue,
        COALESCE(SUM(si.quantity * COALESCE(si.cost_price, p.cost_price, 0)), 0)::numeric as cost
      FROM "${schema}".sales s
      JOIN "${schema}".sale_items si ON si.sale_id = s.id
      LEFT JOIN "${schema}".products p ON si.product_id = p.id
      WHERE ${cogsWhere}
      GROUP BY TO_CHAR(s.created_at, 'YYYY-MM-DD')
      ORDER BY date ASC;
    `, cogsParams)

    const trends = (trendsRes.rows || []).map((row: any) => {
      const rev = Number(row.revenue) || 0
      const c = Number(row.cost) || 0
      return {
        date: row.date,
        count: Number(row.count) || 0,
        revenue: rev,
        cost: c,
        profit: rev - c,
      }
    })

    return response.ok({
      sales_count: salesCount,
      total_sales: salesCount,
      totalSalesCount: salesCount,
      revenue,
      totalRevenue: revenue,
      net_revenue: netRevenue,
      gross_revenue: grossRevenue,
      refunds,
      purchases_cost: purchasesCost,
      total_purchases: totalPurchases,
      low_stock_count: lowStockCount,
      lowStockProducts: lowStockCount,
      cost_of_goods: costOfGoods,
      cogs: costOfGoods,
      gross_profit: grossProfit,
      total_profit: grossProfit,
      profit_margin_pct: profitMarginPct,
      aov,
      total_tax: totalTax,
      total_discount: totalDiscount,
      sales_by_payment: salesByPayment,
      top_products: topProducts,
      trends,
    })
  }

  async overview(ctx: HttpContext) {
    const { response } = ctx
    const schema = this.getSchema(ctx)
    const totalSalesRes = await Sale.query().where('status', 'completed').sum('total_amount as sum')
    const salesCountRes = await Sale.query().where('status', 'completed').count('* as count')
    const totalProductsRes = await Product.query().count('* as count')
    const totalUnitsRes = await db.rawQuery(`SELECT COALESCE(SUM(stock_quantity), 0) as sum FROM "${schema}".products;`)
    const lowStockRes = await Product.query().whereRaw('stock_quantity <= low_stock_threshold').count('* as count')
    const totalPurchasesRes = await Purchase.query().sum('total_amount as sum')
    const purchasesCountRes = await Purchase.query().count('* as count')

    const valuationRes = await db.rawQuery(
      `SELECT COALESCE(SUM(cost_price * stock_quantity), 0) as cost_val, COALESCE(SUM(selling_price * stock_quantity), 0) as retail_val FROM "${schema}".products;`
    )

    const costVal = Number(valuationRes.rows[0]?.cost_val) || 0
    const retailVal = Number(valuationRes.rows[0]?.retail_val) || 0
    const revenue = Number(totalSalesRes[0]?.$extras?.sum) || 0
    const totalSalesCount = Number(salesCountRes[0]?.$extras?.count) || 0
    const grossProfit = retailVal > costVal ? (retailVal - costVal) : 0
    const profitMarginPct = retailVal > 0 ? Math.round(((retailVal - costVal) / retailVal) * 100) : 0
    const aov = totalSalesCount > 0 ? Math.round(revenue / totalSalesCount) : 0

    // Recent 5 sales
    const recentSales = await Sale.query().orderBy('created_at', 'desc').limit(5)

    // Last 7 days trends
    const trendsRes = await db.rawQuery(`
      SELECT 
        TO_CHAR(created_at, 'YYYY-MM-DD') as date,
        COUNT(*)::int as count,
        COALESCE(SUM(total_amount), 0)::numeric as revenue
      FROM "${schema}".sales
      WHERE status = 'completed' AND created_at >= NOW() - INTERVAL '14 days'
      GROUP BY TO_CHAR(created_at, 'YYYY-MM-DD')
      ORDER BY date ASC;
    `)

    // Payment breakdown
    const paymentRes = await db.rawQuery(`
      SELECT 
        COALESCE(payment_method, 'cash') as method,
        COUNT(*)::int as count,
        COALESCE(SUM(total_amount), 0)::numeric as total
      FROM "${schema}".sales
      WHERE status = 'completed'
      GROUP BY payment_method
      ORDER BY total DESC;
    `)

    // Top products
    const topProductsRes = await db.rawQuery(`
      SELECT 
        si.product_id as id,
        p.name,
        COALESCE(SUM(si.quantity), 0)::int as units,
        COALESCE(SUM(si.total), 0)::numeric as revenue,
        COALESCE(SUM(si.total - (COALESCE(si.cost_price, p.cost_price, 0) * si.quantity)), 0)::numeric as profit,
        CASE WHEN SUM(si.total) > 0 
          THEN ROUND((SUM(si.total - (COALESCE(si.cost_price, p.cost_price, 0) * si.quantity))::numeric / SUM(si.total)::numeric) * 100)
          ELSE 0 END as margin
      FROM "${schema}".sale_items si
      JOIN "${schema}".products p ON si.product_id = p.id
      GROUP BY si.product_id, p.name
      ORDER BY revenue DESC
      LIMIT 5;
    `)

    return response.ok({
      sales: {
        total: totalSalesCount,
        revenue: revenue,
        grossRevenue: revenue,
        refunds: 0,
        grossProfit: grossProfit,
        profitMarginPct: profitMarginPct,
        aov: aov,
        costOfGoods: costVal
      },
      stock: {
        potentialMargin: grossProfit,
        retailValue: retailVal,
        costValue: costVal
      },
      products: {
        total: Number(totalProductsRes[0]?.$extras?.count) || 0,
        totalUnits: Number(totalUnitsRes.rows[0]?.sum || 0),
        lowStock: Number(lowStockRes[0]?.$extras?.count) || 0,
        expiring: 0,
        expired: 0
      },
      purchases: {
        totalCost: Number(totalPurchasesRes[0]?.$extras?.sum) || 0,
        total: Number(purchasesCountRes[0]?.$extras?.count) || 0
      },
      trends: trendsRes.rows || [],
      todayPaymentBreakdown: paymentRes.rows || [],
      topProducts: topProductsRes.rows || [],
      recentSales: recentSales
    })
  }

  async salesChart(ctx: HttpContext) {
    const { response } = ctx
    const schema = this.getSchema(ctx)
    const rows = await db.rawQuery(`
      SELECT 
        DATE(created_at) as date,
        COUNT(*) as total_orders,
        SUM(total_amount) as total_amount
      FROM "${schema}".sales
      WHERE status = 'completed' AND created_at >= NOW() - INTERVAL '30 days'
      GROUP BY DATE(created_at)
      ORDER BY DATE(created_at) ASC;
    `)
    return response.ok(rows.rows || [])
  }

  async monthly(ctx: HttpContext) {
    const { request, response } = ctx
    const schema = this.getSchema(ctx)
    const { months = 12 } = request.qs()
    const numMonths = Math.min(24, Math.max(1, Number(months) || 12))

    const rows = await db.rawQuery(`
      SELECT 
        EXTRACT(YEAR FROM s.created_at)::int as year,
        EXTRACT(MONTH FROM s.created_at)::int as month,
        COUNT(DISTINCT s.id)::int as sales_count,
        COALESCE(SUM(s.total_amount), 0)::numeric as revenue,
        COALESCE(SUM(si.quantity * COALESCE(si.cost_price, p.cost_price, 0)), 0)::numeric as cost
      FROM "${schema}".sales s
      LEFT JOIN "${schema}".sale_items si ON si.sale_id = s.id
      LEFT JOIN "${schema}".products p ON si.product_id = p.id
      WHERE s.status = 'completed' AND s.created_at >= NOW() - make_interval(months => ?)
      GROUP BY EXTRACT(YEAR FROM s.created_at), EXTRACT(MONTH FROM s.created_at)
      ORDER BY year ASC, month ASC;
    `, [numMonths])

    const mapped = (rows.rows || []).map((r: any) => {
      const revenue = Number(r.revenue) || 0
      const cost = Number(r.cost) || 0
      const profit = revenue - cost
      const marginPct = revenue > 0 ? Math.round((profit / revenue) * 1000) / 10 : 0
      const monthStr = `${r.year}-${String(r.month).padStart(2, '0')}`
      return {
        year: Number(r.year),
        month: Number(r.month),
        sales_count: Number(r.sales_count) || 0,
        salesCount: Number(r.sales_count) || 0,
        total_orders: Number(r.sales_count) || 0,
        revenue,
        total_amount: revenue,
        cost,
        refunds: 0,
        profit,
        margin_pct: marginPct,
        marginPct,
        month_label: monthStr,
      }
    })

    return response.ok(mapped)
  }

  async categories(ctx: HttpContext) {
    const { request, response } = ctx
    const schema = this.getSchema(ctx)
    const { from, to } = request.qs()
    const params: any[] = []
    let dateFilter = ""
    if (from) {
      dateFilter += " AND s.created_at >= ?"
      params.push(from)
    }
    if (to) {
      dateFilter += " AND s.created_at <= ?"
      params.push(to)
    }

    const rows = await db.rawQuery(`
      WITH sales_by_cat AS (
        SELECT 
          COALESCE(c.id, 0) as cat_id,
          COALESCE(c.name, 'General') as cat_name,
          COALESCE(SUM(si.quantity), 0)::int as items_sold,
          COALESCE(SUM(si.total), 0)::numeric as revenue,
          COALESCE(SUM(si.quantity * COALESCE(si.cost_price, p.cost_price, 0)), 0)::numeric as cost
        FROM "${schema}".sale_items si
        JOIN "${schema}".sales s ON si.sale_id = s.id AND s.status = 'completed' ${dateFilter}
        LEFT JOIN "${schema}".products p ON si.product_id = p.id
        LEFT JOIN "${schema}".categories c ON p.category_id = c.id
        GROUP BY c.id, c.name
      )
      SELECT 
        COALESCE(sbc.cat_name, c.name) as category_name,
        COALESCE(sbc.items_sold, 0)::int as items_sold,
        COALESCE(sbc.revenue, 0)::numeric as revenue,
        COALESCE(sbc.cost, 0)::numeric as cost
      FROM "${schema}".categories c
      FULL OUTER JOIN sales_by_cat sbc ON c.id = sbc.cat_id
      ORDER BY revenue DESC, category_name ASC;
    `, params)

    const mapped = (rows.rows || []).map((r: any) => {
      const revenue = Number(r.revenue) || 0
      const cost = Number(r.cost) || 0
      const profit = revenue - cost
      const marginPct = revenue > 0 ? Math.round(((revenue - cost) / revenue) * 1000) / 10 : 0
      return {
        category_name: r.category_name || 'General',
        categoryName: r.category_name || 'General',
        items_sold: Number(r.items_sold) || 0,
        sales_count: Number(r.items_sold) || 0,
        revenue,
        cost,
        profit,
        margin_pct: marginPct,
        marginPct,
      }
    })

    return response.ok(mapped)
  }

  async stockValuation(ctx: HttpContext) {
    const { response } = ctx
    const schema = this.getSchema(ctx)
    const valuationRes = await db.rawQuery(`
      SELECT 
        COUNT(*)::int as items,
        COALESCE(SUM(stock_quantity), 0)::int as total_stock_quantity,
        COALESCE(SUM(stock_quantity * cost_price), 0)::numeric as cost_value,
        COALESCE(SUM(stock_quantity * selling_price), 0)::numeric as retail_value
      FROM "${schema}".products;
    `)

    const row = valuationRes.rows[0] || {}
    const items = Number(row.items) || 0
    const totalQty = Number(row.total_stock_quantity) || 0
    const costValue = Number(row.cost_value) || 0
    const retailValue = Number(row.retail_value) || 0
    const potentialProfit = Math.max(0, retailValue - costValue)
    const marginPct = retailValue > 0 ? Math.round((potentialProfit / retailValue) * 1000) / 10 : 0

    return response.ok({
      items,
      item_count: items,
      total_items: items,
      cost_value: costValue,
      total_cost: costValue,
      total_cost_value: costValue,
      retail_value: retailValue,
      total_retail: retailValue,
      total_retail_value: retailValue,
      total_stock_quantity: totalQty,
      potential_profit: potentialProfit,
      potential_margin_pct: marginPct,
    })
  }
}
