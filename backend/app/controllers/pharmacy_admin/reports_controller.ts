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

    let salesQuery = Sale.query().where('status', 'completed')
    if (from) salesQuery = salesQuery.where('created_at', '>=', from)
    if (to) salesQuery = salesQuery.where('created_at', '<=', to)

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

    let purchasesQuery = Purchase.query()
    if (from) purchasesQuery = purchasesQuery.where('created_at', '>=', from)
    if (to) purchasesQuery = purchasesQuery.where('created_at', '<=', to)
    const purchasesSumRes = await purchasesQuery.clone().sum('total_amount as sum')
    const purchasesCountRes = await purchasesQuery.clone().count('* as count')
    const purchasesCost = Number(purchasesSumRes[0]?.$extras?.sum) || 0
    const totalPurchases = Number(purchasesCountRes[0]?.$extras?.count) || 0

    const lowStockRes = await Product.query().whereRaw('stock_quantity <= low_stock_threshold').count('* as count')
    const lowStockCount = Number(lowStockRes[0]?.$extras?.count) || 0

    const dateParams: any[] = []
    let dateWhere = "s.status = 'completed'"
    if (from) {
      dateWhere += ' AND s.created_at >= ?'
      dateParams.push(from)
    }
    if (to) {
      dateWhere += ' AND s.created_at <= ?'
      dateParams.push(to)
    }

    const cogsRes = await db.rawQuery(
      `
      SELECT
        COALESCE(SUM(si.quantity * COALESCE(si.cost_price, p.cost_price, 0)), 0) as cogs
      FROM "${schema}".sale_items si
      JOIN "${schema}".sales s ON si.sale_id = s.id
      LEFT JOIN "${schema}".products p ON si.product_id = p.id
      WHERE ${dateWhere};
      `,
      dateParams
    )
    const costOfGoods = Number(cogsRes.rows[0]?.cogs) || 0

    const refundParams: any[] = []
    let refundWhere = '1=1'
    if (from) {
      refundWhere += ' AND r.created_at >= ?'
      refundParams.push(from)
    }
    if (to) {
      refundWhere += ' AND r.created_at <= ?'
      refundParams.push(to)
    }
    const refundRes = await db.rawQuery(
      `
      SELECT COALESCE(SUM(r.total_refund), 0) as refunds
      FROM "${schema}".returns r
      WHERE ${refundWhere};
      `,
      refundParams
    )
    const refunds = Number(refundRes.rows[0]?.refunds) || 0

    const netRevenue = revenue - refunds
    const grossProfit = netRevenue - costOfGoods
    const profitMarginPct = netRevenue > 0 ? Math.round((grossProfit / netRevenue) * 1000) / 10 : 0
    const aov = salesCount > 0 ? Math.round(revenue / salesCount) : 0

    const paymentRes = await db.rawQuery(
      `
      SELECT
        COALESCE(s.payment_method, 'cash') as method,
        COUNT(*)::int as count,
        COALESCE(SUM(s.total_amount), 0)::numeric as total
      FROM "${schema}".sales s
      WHERE ${dateWhere}
      GROUP BY s.payment_method
      ORDER BY total DESC;
      `,
      dateParams
    )

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

    const topProductsRes = await db.rawQuery(
      `
      SELECT
        si.product_id as id,
        si.product_name as name,
        COALESCE(SUM(si.quantity), 0)::int as quantity,
        COALESCE(SUM(si.total), 0)::numeric as revenue,
        COALESCE(SUM(si.quantity * COALESCE(si.cost_price, p.cost_price, 0)), 0)::numeric as cost
      FROM "${schema}".sale_items si
      JOIN "${schema}".sales s ON si.sale_id = s.id
      LEFT JOIN "${schema}".products p ON si.product_id = p.id
      WHERE ${dateWhere}
      GROUP BY si.product_id, si.product_name
      ORDER BY revenue DESC
      LIMIT 10;
      `,
      dateParams
    )

    const topProducts = (topProductsRes.rows || []).map((row: any) => ({
      name: row.name,
      quantity: Number(row.quantity) || 0,
      revenue: Number(row.revenue) || 0,
      cost: Number(row.cost) || 0,
    }))

    // Separate sales revenue & COGS CTEs so daily sales revenue is never distorted by line items
    const trendsRes = await db.rawQuery(
      `
      WITH daily_sales AS (
        SELECT
          TO_CHAR(s.created_at, 'YYYY-MM-DD') as date,
          COUNT(*)::int as count,
          COALESCE(SUM(s.total_amount), 0)::numeric as revenue
        FROM "${schema}".sales s
        WHERE ${dateWhere}
        GROUP BY TO_CHAR(s.created_at, 'YYYY-MM-DD')
      ),
      daily_cogs AS (
        SELECT
          TO_CHAR(s.created_at, 'YYYY-MM-DD') as date,
          COALESCE(SUM(si.quantity * COALESCE(si.cost_price, p.cost_price, 0)), 0)::numeric as cost
        FROM "${schema}".sale_items si
        JOIN "${schema}".sales s ON si.sale_id = s.id
        LEFT JOIN "${schema}".products p ON si.product_id = p.id
        WHERE ${dateWhere}
        GROUP BY TO_CHAR(s.created_at, 'YYYY-MM-DD')
      )
      SELECT
        ds.date,
        ds.count,
        ds.revenue,
        COALESCE(dc.cost, 0)::numeric as cost
      FROM daily_sales ds
      LEFT JOIN daily_cogs dc ON ds.date = dc.date
      ORDER BY ds.date ASC;
      `,
      [...dateParams, ...dateParams]
    )

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
    const { request, response } = ctx
    const schema = this.getSchema(ctx)
    const { from, to } = request.qs()

    const saleParams: any[] = []
    let saleWhere = "s.status = 'completed'"
    if (from) {
      saleWhere += ' AND s.created_at >= ?'
      saleParams.push(from)
    }
    if (to) {
      saleWhere += ' AND s.created_at <= ?'
      saleParams.push(to)
    }

    const salesAgg = await db.rawQuery(
      `
      SELECT
        COUNT(*)::int as sales_count,
        COALESCE(SUM(s.total_amount), 0)::numeric as revenue,
        COALESCE(SUM(s.subtotal), 0)::numeric as gross_revenue
      FROM "${schema}".sales s
      WHERE ${saleWhere};
      `,
      saleParams
    )

    const cogsAgg = await db.rawQuery(
      `
      SELECT
        COALESCE(SUM(si.quantity * COALESCE(si.cost_price, p.cost_price, 0)), 0)::numeric as cogs
      FROM "${schema}".sale_items si
      JOIN "${schema}".sales s ON si.sale_id = s.id
      LEFT JOIN "${schema}".products p ON si.product_id = p.id
      WHERE ${saleWhere};
      `,
      saleParams
    )

    const refundParams: any[] = []
    let refundWhere = '1=1'
    if (from) {
      refundWhere += ' AND r.created_at >= ?'
      refundParams.push(from)
    }
    if (to) {
      refundWhere += ' AND r.created_at <= ?'
      refundParams.push(to)
    }
    const refundAgg = await db.rawQuery(
      `SELECT COALESCE(SUM(r.total_refund), 0)::numeric as refunds FROM "${schema}".returns r WHERE ${refundWhere};`,
      refundParams
    )

    const purchaseParams: any[] = []
    let purchaseWhere = '1=1'
    if (from) {
      purchaseWhere += ' AND created_at >= ?'
      purchaseParams.push(from)
    }
    if (to) {
      purchaseWhere += ' AND created_at <= ?'
      purchaseParams.push(to)
    }
    const purchasesAgg = await db.rawQuery(
      `SELECT COUNT(*)::int as total, COALESCE(SUM(total_amount), 0)::numeric as total_cost FROM "${schema}".purchases WHERE ${purchaseWhere};`,
      purchaseParams
    )

    const prodStatsRes = await db.rawQuery(
      `
      SELECT
        COUNT(*)::int as total_products,
        COALESCE(SUM(stock_quantity), 0)::int as total_units,
        COUNT(*) FILTER (WHERE stock_quantity <= low_stock_threshold)::int as low_stock,
        COUNT(*) FILTER (WHERE expiry_date IS NOT NULL AND expiry_date >= CURRENT_DATE AND expiry_date <= CURRENT_DATE + INTERVAL '30 days')::int as expiring,
        COUNT(*) FILTER (WHERE expiry_date IS NOT NULL AND expiry_date < CURRENT_DATE)::int as expired,
        COALESCE(SUM(cost_price * stock_quantity), 0)::numeric as cost_val,
        COALESCE(SUM(selling_price * stock_quantity), 0)::numeric as retail_val
      FROM "${schema}".products;
      `
    )

    const pStats = prodStatsRes.rows[0] || {}
    const costVal = Number(pStats.cost_val) || 0
    const retailVal = Number(pStats.retail_val) || 0
    const revenue = Number(salesAgg.rows[0]?.revenue) || 0
    const grossRevenue = Number(salesAgg.rows[0]?.gross_revenue) || revenue
    const totalSalesCount = Number(salesAgg.rows[0]?.sales_count) || 0
    const cogs = Number(cogsAgg.rows[0]?.cogs) || 0
    const refunds = Number(refundAgg.rows[0]?.refunds) || 0
    const netRevenue = revenue - refunds
    const grossProfit = netRevenue - cogs
    const profitMarginPct = netRevenue > 0 ? Math.round((grossProfit / netRevenue) * 1000) / 10 : 0
    const aov = totalSalesCount > 0 ? Math.round(revenue / totalSalesCount) : 0

    const recentSalesRaw = await Sale.query().orderBy('created_at', 'desc').limit(5)
    const recentSales = recentSalesRaw.map((s) => ({
      id: s.id,
      invoice_number: s.invoiceNumber,
      invoiceNumber: s.invoiceNumber,
      customer_name: s.customerName,
      customerName: s.customerName,
      total_amount: Number(s.totalAmount) || 0,
      totalAmount: Number(s.totalAmount) || 0,
      payment_method: s.paymentMethod || 'cash',
      paymentMethod: s.paymentMethod || 'cash',
      status: s.status,
      created_at: s.createdAt ? s.createdAt.toISO() : null,
      createdAt: s.createdAt ? s.createdAt.toISO() : null,
    }))

    const trendsRes = await db.rawQuery(
      `
      SELECT
        TO_CHAR(s.created_at, 'YYYY-MM-DD') as date,
        COUNT(*)::int as count,
        COALESCE(SUM(s.total_amount), 0)::numeric as revenue
      FROM "${schema}".sales s
      WHERE ${saleWhere} AND s.created_at >= NOW() - INTERVAL '14 days'
      GROUP BY TO_CHAR(s.created_at, 'YYYY-MM-DD')
      ORDER BY date ASC;
      `,
      saleParams
    )

    const paymentRes = await db.rawQuery(
      `
      SELECT
        COALESCE(s.payment_method, 'cash') as method,
        COUNT(*)::int as count,
        COALESCE(SUM(s.total_amount), 0)::numeric as total
      FROM "${schema}".sales s
      WHERE ${saleWhere}
      GROUP BY s.payment_method
      ORDER BY total DESC;
      `,
      saleParams
    )

    const topProductsRes = await db.rawQuery(
      `
      SELECT
        si.product_id as id,
        COALESCE(p.name, si.product_name) as name,
        COALESCE(SUM(si.quantity), 0)::int as units,
        COALESCE(SUM(si.total), 0)::numeric as revenue,
        COALESCE(SUM(si.total - (COALESCE(si.cost_price, p.cost_price, 0) * si.quantity)), 0)::numeric as profit,
        CASE WHEN SUM(si.total) > 0
          THEN ROUND((SUM(si.total - (COALESCE(si.cost_price, p.cost_price, 0) * si.quantity))::numeric / SUM(si.total)::numeric) * 100)
          ELSE 0 END as margin
      FROM "${schema}".sale_items si
      JOIN "${schema}".sales s ON si.sale_id = s.id
      LEFT JOIN "${schema}".products p ON si.product_id = p.id
      WHERE ${saleWhere}
      GROUP BY si.product_id, COALESCE(p.name, si.product_name)
      ORDER BY revenue DESC
      LIMIT 5;
      `,
      saleParams
    )

    return response.ok({
      sales: {
        total: totalSalesCount,
        revenue,
        grossRevenue,
        refunds,
        netRevenue,
        grossProfit,
        profitMarginPct,
        aov,
        costOfGoods: cogs,
      },
      stock: {
        potentialMargin: Math.max(0, retailVal - costVal),
        retailValue: retailVal,
        costValue: costVal,
      },
      products: {
        total: Number(pStats.total_products) || 0,
        totalUnits: Number(pStats.total_units) || 0,
        lowStock: Number(pStats.low_stock) || 0,
        expiring: Number(pStats.expiring) || 0,
        expired: Number(pStats.expired) || 0,
      },
      purchases: {
        totalCost: Number(purchasesAgg.rows[0]?.total_cost) || 0,
        total: Number(purchasesAgg.rows[0]?.total) || 0,
      },
      trends: trendsRes.rows || [],
      todayPaymentBreakdown: paymentRes.rows || [],
      topProducts: topProductsRes.rows || [],
      recentSales,
    })
  }

  async salesChart(ctx: HttpContext) {
    const { response } = ctx
    const schema = this.getSchema(ctx)
    const rows = await db.rawQuery(`
      SELECT
        DATE(created_at) as date,
        COUNT(*)::int as total_orders,
        COALESCE(SUM(total_amount), 0)::numeric as total_amount
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

    // Use separate CTEs so joining sale_items never multiplies s.total_amount
    const rows = await db.rawQuery(
      `
      WITH monthly_sales AS (
        SELECT
          EXTRACT(YEAR FROM created_at)::int as year,
          EXTRACT(MONTH FROM created_at)::int as month,
          COUNT(*)::int as sales_count,
          COALESCE(SUM(total_amount), 0)::numeric as revenue
        FROM "${schema}".sales
        WHERE status = 'completed' AND created_at >= NOW() - make_interval(months => ?)
        GROUP BY EXTRACT(YEAR FROM created_at), EXTRACT(MONTH FROM created_at)
      ),
      monthly_cogs AS (
        SELECT
          EXTRACT(YEAR FROM s.created_at)::int as year,
          EXTRACT(MONTH FROM s.created_at)::int as month,
          COALESCE(SUM(si.quantity * COALESCE(si.cost_price, p.cost_price, 0)), 0)::numeric as cost
        FROM "${schema}".sale_items si
        JOIN "${schema}".sales s ON si.sale_id = s.id
        LEFT JOIN "${schema}".products p ON si.product_id = p.id
        WHERE s.status = 'completed' AND s.created_at >= NOW() - make_interval(months => ?)
        GROUP BY EXTRACT(YEAR FROM s.created_at), EXTRACT(MONTH FROM s.created_at)
      ),
      monthly_refunds AS (
        SELECT
          EXTRACT(YEAR FROM r.created_at)::int as year,
          EXTRACT(MONTH FROM r.created_at)::int as month,
          COALESCE(SUM(r.total_refund), 0)::numeric as refunds
        FROM "${schema}".returns r
        WHERE r.created_at >= NOW() - make_interval(months => ?)
        GROUP BY EXTRACT(YEAR FROM r.created_at), EXTRACT(MONTH FROM r.created_at)
      )
      SELECT
        ms.year,
        ms.month,
        ms.sales_count,
        ms.revenue,
        COALESCE(mc.cost, 0)::numeric as cost,
        COALESCE(mr.refunds, 0)::numeric as refunds
      FROM monthly_sales ms
      LEFT JOIN monthly_cogs mc ON ms.year = mc.year AND ms.month = mc.month
      LEFT JOIN monthly_refunds mr ON ms.year = mr.year AND ms.month = mr.month
      ORDER BY ms.year ASC, ms.month ASC;
      `,
      [numMonths, numMonths, numMonths]
    )

    const mapped = (rows.rows || []).map((r: any) => {
      const revenue = Number(r.revenue) || 0
      const cost = Number(r.cost) || 0
      const refunds = Number(r.refunds) || 0
      const netRevenue = revenue - refunds
      const profit = netRevenue - cost
      const marginPct = netRevenue > 0 ? Math.round((profit / netRevenue) * 1000) / 10 : 0
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
        refunds,
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
    let dateFilter = ''
    if (from) {
      dateFilter += ' AND s.created_at >= ?'
      params.push(from)
    }
    if (to) {
      dateFilter += ' AND s.created_at <= ?'
      params.push(to)
    }

    const rows = await db.rawQuery(
      `
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
      `,
      params
    )

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
    const potentialProfit = retailValue - costValue
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
