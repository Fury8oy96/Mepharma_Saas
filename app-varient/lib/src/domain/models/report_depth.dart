/// One month of sales performance, for the monthly comparison report.
class MonthlyReport {
  const MonthlyReport({
    required this.year,
    required this.month,
    required this.salesCount,
    required this.revenue,
    required this.refunds,
    this.cost = 0,
    this.profit,
    this.marginPct,
  });

  final int year;
  final int month;

  /// Minor units (cents).
  final int salesCount;
  final int revenue;
  final int refunds;
  final int cost;
  final int? profit;
  final double? marginPct;

  /// Minor units (cents).
  int get netRevenue => revenue - refunds;
  int get calculatedProfit => profit ?? (netRevenue - cost);
  double get calculatedMarginPct => marginPct ?? (netRevenue > 0 ? (calculatedProfit / netRevenue) * 100 : 0.0);

  String get key => '$year-$month';
}

/// Sales revenue grouped by product category, for a date range.
class CategoryReport {
  const CategoryReport({
    required this.categoryName,
    required this.revenue,
    required this.cost,
    required this.salesCount,
    this.marginPct,
  });

  final String categoryName;

  /// Minor units (cents).
  final int revenue;

  /// Minor units (cents) of goods sold in this category.
  final int cost;
  final int salesCount;
  final double? marginPct;

  /// Minor units (cents).
  int get profit => revenue - cost;
  double get calculatedMarginPct => marginPct ?? (revenue > 0 ? (profit / revenue) * 100 : 0.0);
}

/// Value of the current stock, at cost and at retail price.
class StockValuation {
  const StockValuation({
    required this.items,
    required this.costValue,
    required this.retailValue,
    this.totalStockQuantity = 0,
  });

  final int items;
  final int costValue;
  final int retailValue;
  final int totalStockQuantity;

  int get potentialProfit => retailValue - costValue;
  double get potentialMarginPct => retailValue > 0 ? ((retailValue - costValue) / retailValue) * 100 : 0.0;
}
