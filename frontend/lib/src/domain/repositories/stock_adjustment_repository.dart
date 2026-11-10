import '../models/app_stock_adjustment.dart';

abstract interface class StockAdjustmentRepository {
  Stream<List<AppStockAdjustment>> watchForProduct(int productId);

  Future<List<AppStockAdjustment>> getAll();

  /// Adjusts a product's stock in a single transaction and records the
  /// adjustment. Positive [adjustmentQuantity] adds stock, negative removes.
  Future<void> adjustStock({
    required int productId,
    required int adjustmentQuantity,
    String? reason,
    String? reference,
    int? userId,
  });
}
