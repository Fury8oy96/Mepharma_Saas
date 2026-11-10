/// A return (refund) processed against a completed sale.
class AppReturn {
  const AppReturn({
    required this.id,
    required this.saleId,
    required this.invoiceNumber,
    required this.userId,
    required this.totalRefund,
    this.reason,
    required this.createdAt,
  });

  final int id;
  final int saleId;

  /// Snapshot of the original invoice.
  final String invoiceNumber;
  final int userId;

  /// Minor units (cents).
  final int totalRefund;
  final String? reason;
  final DateTime createdAt;
}

/// One returned line, with snapshots.
class AppReturnItem {
  const AppReturnItem({
    required this.id,
    required this.returnId,
    this.saleItemId,
    this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalRefund,
  });

  final int id;
  final int returnId;
  final int? saleItemId;
  final int? productId;
  final String productName;
  final int quantity;

  /// Minor units (cents), refunded unit price.
  final int unitPrice;

  /// Minor units (cents).
  final int totalRefund;
}
