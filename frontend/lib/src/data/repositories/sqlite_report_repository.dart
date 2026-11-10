import 'package:drift/drift.dart';
import 'package:intl/intl.dart';

import '../../domain/models/report_depth.dart';
import '../../domain/models/report_summary.dart';
import '../../domain/repositories/report_repository.dart';
import '../db/app_database.dart';
import '../db/enums.dart';

class SqliteReportRepository implements ReportRepository {
  SqliteReportRepository(this._db);

  final AppDatabase _db;

  @override
  Future<ReportSummary> getSummary({
    required DateTime from,
    required DateTime to,
  }) async {
    final salesRange = _db.sales.createdAt.isBiggerOrEqualValue(from) &
        _db.sales.createdAt.isSmallerOrEqualValue(to);
    final completed = _db.sales.status.equals(SaleStatus.completed.name);

    final revenueRow = await (_db.selectOnly(_db.sales)
          ..addColumns([
            _db.sales.totalAmount.sum(),
            _db.sales.subtotal.sum(),
            _db.sales.taxAmount.sum(),
            _db.sales.discount.sum(),
            _db.sales.id.count(),
          ])
          ..where(completed & salesRange))
        .getSingle();
    final revenue = revenueRow.read(_db.sales.totalAmount.sum()) ?? 0;
    final grossRevenue = revenueRow.read(_db.sales.subtotal.sum()) ?? revenue;
    final totalTax = revenueRow.read(_db.sales.taxAmount.sum()) ?? 0;
    final totalDiscount = revenueRow.read(_db.sales.discount.sum()) ?? 0;
    final salesCount = revenueRow.read(_db.sales.id.count()) ?? 0;

    // Refunds are attributed to the original sale's date and only count while
    // the sale is still marked completed.
    final refundRow = await (_db.selectOnly(_db.returns)
          ..addColumns([_db.returns.totalRefund.sum()])
          ..join([
            innerJoin(
              _db.sales,
              _db.sales.id.equalsExp(_db.returns.saleId),
            ),
          ])
          ..where(
            completed &
                _db.sales.createdAt.isBiggerOrEqualValue(from) &
                _db.sales.createdAt.isSmallerOrEqualValue(to),
          ))
          .getSingle();
    final refunds = refundRow.read(_db.returns.totalRefund.sum()) ?? 0;

    final purchaseRow = await (_db.selectOnly(_db.purchases)
          ..addColumns([
            _db.purchases.totalAmount.sum(),
            _db.purchases.id.count(),
          ])
          ..where(
            _db.purchases.purchaseDate.isBiggerOrEqualValue(from) &
                _db.purchases.purchaseDate.isSmallerOrEqualValue(to),
          ))
          .getSingle();
    final purchasesCost = purchaseRow.read(_db.purchases.totalAmount.sum()) ?? 0;
    final totalPurchases = purchaseRow.read(_db.purchases.id.count()) ?? 0;

    final cogs = await _costOfGoods(completed, salesRange);

    final lowRow = await (_db.selectOnly(_db.products)
          ..addColumns([countAll()])
          ..where(
            _db.products.stockQuantity
                .isSmallerOrEqual(_db.products.lowStockThreshold),
          ))
          .getSingle();
    final lowStockCount = lowRow.read(countAll()) ?? 0;

    final paymentRows = await (_db.selectOnly(_db.sales)
          ..addColumns([
            _db.sales.paymentMethod,
            _db.sales.id.count(),
            _db.sales.totalAmount.sum(),
          ])
          ..where(completed & salesRange)
          ..groupBy([_db.sales.paymentMethod])
          ..orderBy([OrderingTerm.desc(_db.sales.totalAmount.sum())]))
        .get();
    final salesByPayment = [
      for (final row in paymentRows)
        () {
          final tot = row.read(_db.sales.totalAmount.sum()) ?? 0;
          final pct = revenue > 0 ? (tot / revenue) * 100 : 0.0;
          return PaymentBreakdown(
            method: row.read(_db.sales.paymentMethod),
            count: row.read(_db.sales.id.count()) ?? 0,
            total: tot,
            percentage: double.parse(pct.toStringAsFixed(1)),
          );
        }(),
    ];

    // Top Products
    final topRows = await (_db.selectOnly(_db.saleItems)
          ..addColumns([
            _db.saleItems.productName,
            _db.saleItems.productId,
            _db.saleItems.quantity.sum(),
            _db.saleItems.totalPrice.sum(),
          ])
          ..join([
            innerJoin(
              _db.sales,
              _db.sales.id.equalsExp(_db.saleItems.saleId),
            ),
          ])
          ..where(completed & salesRange)
          ..groupBy([_db.saleItems.productName, _db.saleItems.productId])
          ..orderBy([OrderingTerm.desc(_db.saleItems.totalPrice.sum())])
          ..limit(10))
        .get();

    final topProductIds = topRows
        .map((r) => r.read(_db.saleItems.productId))
        .whereType<int>()
        .toSet();
    final topCostMap = <int, int>{
      for (final p in await (_db.select(_db.products)
            ..where((p) => p.id.isIn(topProductIds)))
          .get())
        p.id: p.costPrice,
    };

    final topProducts = [
      for (final row in topRows)
        () {
          final pid = row.read(_db.saleItems.productId);
          final qty = row.read(_db.saleItems.quantity.sum()) ?? 0;
          final rev = row.read(_db.saleItems.totalPrice.sum()) ?? 0;
          final unitCost = pid != null ? (topCostMap[pid] ?? 0) : 0;
          return ProductSales(
            name: row.read(_db.saleItems.productName) ?? '',
            quantity: qty,
            revenue: rev,
            cost: unitCost * qty,
          );
        }(),
    ];

    // Daily trends calculation
    final salesItemsInPeriod = await (_db.select(_db.sales)
          ..where((s) => completed & salesRange)
          ..orderBy([(s) => OrderingTerm.asc(s.createdAt)]))
        .get();

    final dayMap = <String, _DayAgg>{};
    final dateFormat = DateFormat('yyyy-MM-dd');
    for (final sale in salesItemsInPeriod) {
      final key = dateFormat.format(sale.createdAt);
      final agg = dayMap.putIfAbsent(key, () => _DayAgg(date: key));
      agg.count += 1;
      agg.revenue += sale.totalAmount;
    }

    // Cost per day
    final saleIds = salesItemsInPeriod.map((s) => s.id).toList();
    if (saleIds.isNotEmpty) {
      final items = await (_db.select(_db.saleItems)
            ..where((i) => i.saleId.isIn(saleIds)))
          .get();
      final pIds = items.map((i) => i.productId).whereType<int>().toSet();
      final pCostMap = <int, int>{
        for (final p in await (_db.select(_db.products)
              ..where((p) => p.id.isIn(pIds)))
            .get())
          p.id: p.costPrice,
      };
      final saleDateMap = {for (final s in salesItemsInPeriod) s.id: dateFormat.format(s.createdAt)};
      for (final item in items) {
        final dateKey = saleDateMap[item.saleId];
        if (dateKey != null && dayMap.containsKey(dateKey)) {
          final unitCost = item.productId != null ? (pCostMap[item.productId] ?? 0) : 0;
          dayMap[dateKey]!.cost += unitCost * item.quantity;
        }
      }
    }

    final trends = dayMap.values.map((d) => DailyTrend(
      date: d.date,
      count: d.count,
      revenue: d.revenue,
      cost: d.cost,
      profit: d.revenue - d.cost,
    )).toList();

    return ReportSummary(
      from: from,
      to: to,
      salesCount: salesCount,
      revenue: revenue,
      grossRevenue: grossRevenue,
      refunds: refunds,
      purchasesCost: purchasesCost,
      totalPurchases: totalPurchases,
      totalTax: totalTax,
      totalDiscount: totalDiscount,
      lowStockCount: lowStockCount,
      costOfGoods: cogs,
      salesByPayment: salesByPayment,
      topProducts: topProducts,
      trends: trends,
    );
  }

  /// Approximate cost of goods sold: the *current* product cost price times
  /// the sold quantity, for completed sales in range.
  Future<int> _costOfGoods(
    Expression<bool> completed,
    Expression<bool> salesRange,
  ) async {
    final saleIds = await (_db.selectOnly(_db.sales)
          ..addColumns([_db.sales.id])
          ..where(completed & salesRange))
        .map((row) => row.read(_db.sales.id)!)
        .get();
    if (saleIds.isEmpty) {
      return 0;
    }
    final items = await (_db.select(_db.saleItems)
          ..where((i) => i.saleId.isIn(saleIds)))
        .get();
    if (items.isEmpty) {
      return 0;
    }
    final productIds = items
        .map((i) => i.productId)
        .whereType<int>()
        .toSet();
    final costById = <int, int>{
      for (final product in await (_db.select(_db.products)
            ..where((p) => p.id.isIn(productIds)))
          .get())
        product.id: product.costPrice,
    };
    var total = 0;
    for (final item in items) {
      final cost = item.productId == null ? null : costById[item.productId];
      total += (cost ?? 0) * item.quantity;
    }
    return total;
  }

  @override
  Future<List<MonthlyReport>> getMonthlySummary({required int months}) async {
    final now = DateTime.now();
    final result = <MonthlyReport>[];
    final completed = _db.sales.status.equals(SaleStatus.completed.name);

    for (var offset = months - 1; offset >= 0; offset--) {
      final month = DateTime(now.year, now.month - offset, 1);
      final from = DateTime(month.year, month.month, 1);
      final to = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

      final salesRange = _db.sales.createdAt.isBiggerOrEqualValue(from) &
          _db.sales.createdAt.isSmallerOrEqualValue(to);

      final revenueRow = await (_db.selectOnly(_db.sales)
            ..addColumns([_db.sales.totalAmount.sum(), _db.sales.id.count()])
            ..where(completed & salesRange))
          .getSingle();
      final refundRow = await (_db.selectOnly(_db.returns)
            ..addColumns([_db.returns.totalRefund.sum()])
            ..join([
              innerJoin(
                _db.sales,
                _db.sales.id.equalsExp(_db.returns.saleId),
              ),
            ])
            ..where(completed & salesRange))
          .getSingle();

      final cogs = await _costOfGoods(completed, salesRange);
      final rev = revenueRow.read(_db.sales.totalAmount.sum()) ?? 0;
      final ref = refundRow.read(_db.returns.totalRefund.sum()) ?? 0;
      final netRev = rev - ref;
      final profit = netRev - cogs;
      final marginPct = netRev > 0 ? (profit / netRev) * 100 : 0.0;

      result.add(
        MonthlyReport(
          year: month.year,
          month: month.month,
          salesCount: revenueRow.read(_db.sales.id.count()) ?? 0,
          revenue: rev,
          refunds: ref,
          cost: cogs,
          profit: profit,
          marginPct: double.parse(marginPct.toStringAsFixed(1)),
        ),
      );
    }
    return result;
  }

  @override
  Future<List<CategoryReport>> getCategorySummary({
    required DateTime from,
    required DateTime to,
  }) async {
    final statement = _db
        .select(_db.saleItems)
        .join([
          innerJoin(
            _db.sales,
            _db.sales.id.equalsExp(_db.saleItems.saleId),
          ),
          leftOuterJoin(
            _db.products,
            _db.products.id.equalsExp(_db.saleItems.productId),
          ),
          leftOuterJoin(
            _db.categories,
            _db.categories.id.equalsExp(_db.products.categoryId),
          ),
        ]);
    statement.where(
      _db.sales.status.equals(SaleStatus.completed.name) &
          _db.sales.createdAt.isBiggerOrEqualValue(from) &
          _db.sales.createdAt.isSmallerOrEqualValue(to),
    );
    final rows = await statement.get();

    final totals = <String, _CategoryTotals>{};
    final distinctSales = <String, Set<int>>{};
    for (final row in rows) {
      final name = row.read(_db.categories.name) ?? '-';
      final entry = totals.putIfAbsent(name, _CategoryTotals.new);
      final quantity = row.read(_db.saleItems.quantity) ?? 0;
      final cost = row.read(_db.products.costPrice) ?? 0;
      final totalPrice = row.read(_db.saleItems.totalPrice) ?? 0;
      entry.revenue += totalPrice;
      entry.cost += cost * quantity;
      entry.itemsSold += quantity;
      final saleId = row.read(_db.sales.id);
      if (saleId != null) {
        distinctSales.putIfAbsent(name, () => <int>{}).add(saleId);
      }
    }

    final result = [
      for (final MapEntry(key: name, value: totals) in totals.entries)
        () {
          final prof = totals.revenue - totals.cost;
          final margin = totals.revenue > 0 ? (prof / totals.revenue) * 100 : 0.0;
          return CategoryReport(
            categoryName: name,
            revenue: totals.revenue,
            cost: totals.cost,
            salesCount: distinctSales[name]?.length ?? 0,
            marginPct: double.parse(margin.toStringAsFixed(1)),
          );
        }(),
    ];
    result.sort((a, b) => b.revenue.compareTo(a.revenue));
    return result;
  }

  @override
  Future<StockValuation> getStockValuation() async {
    final products = await (_db.select(_db.products)).get();
    var costValue = 0;
    var retailValue = 0;
    var totalQty = 0;
    for (final product in products) {
      costValue += product.costPrice * product.stockQuantity;
      retailValue += product.sellingPrice * product.stockQuantity;
      totalQty += product.stockQuantity;
    }
    return StockValuation(
      items: products.length,
      costValue: costValue,
      retailValue: retailValue,
      totalStockQuantity: totalQty,
    );
  }
}

class _DayAgg {
  _DayAgg({required this.date});
  final String date;
  int count = 0;
  int revenue = 0;
  int cost = 0;
}

class _CategoryTotals {
  int revenue = 0;
  int cost = 0;
  int itemsSold = 0;
}
