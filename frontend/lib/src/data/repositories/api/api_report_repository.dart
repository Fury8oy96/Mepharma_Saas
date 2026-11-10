import 'dart:convert';

import '../../../domain/models/report_depth.dart';
import '../../../domain/models/report_summary.dart';
import '../../../domain/repositories/report_repository.dart';
import '../../../core/services/api_client.dart';

class ApiReportRepository implements ReportRepository {
  ApiReportRepository(this._client);

  final ApiClient _client;

  @override
  Future<ReportSummary> getSummary({
    required DateTime from,
    required DateTime to,
  }) async {
    final response = await _client.get('/reports/summary'
        '?from=${Uri.encodeQueryComponent(from.toUtc().toIso8601String())}'
        '&to=${Uri.encodeQueryComponent(to.toUtc().toIso8601String())}');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    
    final paymentsList = data['sales_by_payment'] as List? ?? data['salesByPayment'] as List? ?? [];
    final salesByPayment = paymentsList.map((pb) => PaymentBreakdown(
      method: pb['method'] as String?,
      count: pb['count'] as int? ?? 0,
      total: (pb['total'] as num?)?.toInt() ?? 0,
      percentage: (pb['percentage'] as num?)?.toDouble() ?? 0.0,
    )).toList();

    final productsList = data['top_products'] as List? ?? data['topProducts'] as List? ?? [];
    final topProducts = productsList.map((ps) => ProductSales(
      name: ps['name'] as String? ?? '',
      quantity: ps['quantity'] as int? ?? 0,
      revenue: (ps['revenue'] as num?)?.toInt() ?? 0,
      cost: (ps['cost'] as num?)?.toInt() ?? 0,
    )).toList();

    final trendsList = data['trends'] as List? ?? [];
    final trends = trendsList.map((t) => DailyTrend(
      date: t['date'] as String? ?? '',
      count: (t['count'] as num?)?.toInt() ?? 0,
      revenue: (t['revenue'] as num?)?.toInt() ?? 0,
      cost: (t['cost'] as num?)?.toInt() ?? 0,
      profit: (t['profit'] as num?)?.toInt() ?? 0,
    )).toList();

    return ReportSummary(
      from: from,
      to: to,
      salesCount: data['sales_count'] as int? ?? data['salesCount'] as int? ?? 0,
      revenue: (data['revenue'] as num?)?.toInt() ?? 0,
      grossRevenue: (data['gross_revenue'] as num?)?.toInt(),
      refunds: (data['refunds'] as num?)?.toInt() ?? 0,
      purchasesCost: (data['purchases_cost'] as num?)?.toInt() ?? (data['purchasesCost'] as num?)?.toInt() ?? 0,
      totalPurchases: (data['total_purchases'] as num?)?.toInt() ?? (data['totalPurchases'] as num?)?.toInt() ?? 0,
      lowStockCount: data['low_stock_count'] as int? ?? data['lowStockCount'] as int? ?? 0,
      costOfGoods: (data['cost_of_goods'] as num?)?.toInt() ?? (data['costOfGoods'] as num?)?.toInt() ?? 0,
      totalTax: (data['total_tax'] as num?)?.toInt() ?? (data['totalTax'] as num?)?.toInt() ?? 0,
      totalDiscount: (data['total_discount'] as num?)?.toInt() ?? (data['totalDiscount'] as num?)?.toInt() ?? 0,
      salesByPayment: salesByPayment,
      topProducts: topProducts,
      trends: trends,
    );
  }

  @override
  Future<List<MonthlyReport>> getMonthlySummary({required int months}) async {
    final response = await _client.get('/reports/monthly?months=$months');
    final data = jsonDecode(response.body) as List;
    return data.map((item) {
      final json = item as Map<String, dynamic>;
      return MonthlyReport(
        year: json['year'] as int? ?? 0,
        month: json['month'] as int? ?? 0,
        salesCount: json['sales_count'] as int? ?? json['salesCount'] as int? ?? 0,
        revenue: (json['revenue'] as num?)?.toInt() ?? 0,
        refunds: (json['refunds'] as num?)?.toInt() ?? 0,
        cost: (json['cost'] as num?)?.toInt() ?? 0,
        profit: (json['profit'] as num?)?.toInt(),
        marginPct: (json['margin_pct'] as num?)?.toDouble() ?? (json['marginPct'] as num?)?.toDouble(),
      );
    }).toList();
  }

  @override
  Future<List<CategoryReport>> getCategorySummary({
    required DateTime from,
    required DateTime to,
  }) async {
    final response = await _client.get('/reports/categories'
        '?from=${Uri.encodeQueryComponent(from.toUtc().toIso8601String())}'
        '&to=${Uri.encodeQueryComponent(to.toUtc().toIso8601String())}');
    final data = jsonDecode(response.body) as List;
    return data.map((item) {
      final json = item as Map<String, dynamic>;
      return CategoryReport(
        categoryName: json['category_name'] as String? ?? json['categoryName'] as String? ?? 'Uncategorized',
        revenue: (json['revenue'] as num?)?.toInt() ?? 0,
        cost: (json['cost'] as num?)?.toInt() ?? 0,
        salesCount: json['items_sold'] as int? ?? json['sales_count'] as int? ?? json['salesCount'] as int? ?? 0,
        marginPct: (json['margin_pct'] as num?)?.toDouble() ?? (json['marginPct'] as num?)?.toDouble(),
      );
    }).toList();
  }

  @override
  Future<StockValuation> getStockValuation() async {
    final response = await _client.get('/reports/stock-valuation');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return StockValuation(
      items: data['items'] as int? ?? data['item_count'] as int? ?? data['itemCount'] as int? ?? 0,
      costValue: data['cost_value'] as int? ?? data['total_cost'] as int? ?? data['totalCost'] as int? ?? 0,
      retailValue: data['retail_value'] as int? ?? data['total_retail'] as int? ?? data['totalRetail'] as int? ?? 0,
      totalStockQuantity: data['total_stock_quantity'] as int? ?? data['totalStockQuantity'] as int? ?? 0,
    );
  }
}
