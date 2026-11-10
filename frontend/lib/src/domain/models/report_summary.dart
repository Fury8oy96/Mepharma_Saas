/// Aggregated report data for a date range.
class ReportSummary {
  const ReportSummary({
    required this.from,
    required this.to,
    required this.salesCount,
    required this.revenue,
    required this.refunds,
    required this.purchasesCost,
    required this.lowStockCount,
    required this.salesByPayment,
    required this.topProducts,
    required this.costOfGoods,
    this.trends = const [],
    this.grossRevenue,
    this.totalTax = 0,
    this.totalDiscount = 0,
    this.totalPurchases = 0,
  });

  final DateTime from;
  final DateTime to;

  /// Completed sales count in the range.
  final int salesCount;

  /// Sum of completed-sale totals, minor units (cents).
  final int revenue;

  /// Sum of subtotal before discounts/taxes, minor units (cents).
  final int? grossRevenue;

  /// Sum of return refunds recorded in the range, minor units (cents).
  final int refunds;

  /// Sum of purchase totals (by purchase date) in the range, minor units.
  final int purchasesCost;
  final int totalPurchases;

  final int totalTax;
  final int totalDiscount;
  final int lowStockCount;

  /// Completed-sale totals grouped by payment method.
  final List<PaymentBreakdown> salesByPayment;

  /// Best sellers by quantity and revenue in the range.
  final List<ProductSales> topProducts;

  /// Daily sales/revenue trends across the period.
  final List<DailyTrend> trends;

  /// Cost of sold goods: current costPrice * quantity, for completed sales.
  final int costOfGoods;

  /// What customers actually paid, minus refunds.
  int get netRevenue => (revenue - refunds) < 0 ? 0 : (revenue - refunds);

  /// Margin using the cost price of each sold product (revenue - costOfGoods).
  int get estimatedProfit => revenue - costOfGoods;

  /// Net profit after subtracting refunds (netRevenue - costOfGoods).
  int get netProfit => netRevenue - costOfGoods;

  /// Profit margin as a percentage (0.0% to 100.0%).
  double get profitMarginPct =>
      netRevenue > 0 ? (netProfit / netRevenue) * 100 : (revenue > 0 ? (estimatedProfit / revenue) * 100 : 0.0);

  /// Average Order Value (AOV) in minor units.
  int get averageOrderValue => salesCount > 0 ? (revenue ~/ salesCount) : 0;
}

class DailyTrend {
  const DailyTrend({
    required this.date,
    required this.count,
    required this.revenue,
    this.cost = 0,
    this.profit = 0,
  });

  final String date;
  final int count;
  final int revenue;
  final int cost;
  final int profit;
}

class PaymentBreakdown {
  const PaymentBreakdown({
    required this.method,
    required this.count,
    required this.total,
    this.percentage = 0.0,
  });

  /// 'cash', 'card', 'mobileMoney', 'credit'.
  final String? method;
  final int count;

  /// Minor units (cents).
  final int total;

  final double percentage;
}

class ProductSales {
  const ProductSales({
    required this.name,
    required this.quantity,
    required this.revenue,
    this.cost = 0,
  });

  final String name;
  final int quantity;

  /// Minor units (cents).
  final int revenue;
  final int cost;

  int get profit => revenue - cost;
  double get marginPct => revenue > 0 ? (profit / revenue) * 100 : 0.0;
}
