import '../models/report_depth.dart';
import '../models/report_summary.dart';

abstract interface class ReportRepository {
  /// Aggregated figures for completed sales and returns whose timestamps fall
  /// within [from] (inclusive) and [to] (inclusive).
  Future<ReportSummary> getSummary({
    required DateTime from,
    required DateTime to,
  });

  /// One entry per calendar month, newest first, covering the last [months]
  /// full months.
  Future<List<MonthlyReport>> getMonthlySummary({required int months});

  /// Revenue and sale count grouped by product category within a date range.
  Future<List<CategoryReport>> getCategorySummary({
    required DateTime from,
    required DateTime to,
  });

  /// Value of current stock at cost and retail prices.
  Future<StockValuation> getStockValuation();
}
