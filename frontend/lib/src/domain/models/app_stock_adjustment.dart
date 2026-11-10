/// Domain representation of a stock adjustment record.
class AppStockAdjustment {
  const AppStockAdjustment({
    required this.id,
    required this.productId,
    required this.adjustmentQuantity,
    this.reason,
    this.reference,
    this.userId,
    required this.createdAt,
  });

  final int id;
  final int productId;

  /// Positive adds stock, negative removes stock.
  final int adjustmentQuantity;
  final String? reason;

  /// e.g. 'manual', 'sale:12', 'purchase:34', 'return:5'.
  final String? reference;
  final int? userId;
  final DateTime createdAt;
}
