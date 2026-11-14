enum PurchaseStatus {
  pending,
  approved,
}

/// A purchase (stock intake) recorded against a supplier.
class AppPurchase {
  const AppPurchase({
    required this.id,
    required this.invoiceNumber,
    this.transactionReference,
    this.supplierId,
    required this.userId,
    required this.totalAmount,
    required this.purchaseDate,
    required this.createdAt,
    required this.status,
  });

  final int id;
  final String invoiceNumber;

  /// External transaction reference / receipt / bank reference (رقم العملية)
  final String? transactionReference;
  final int? supplierId;
  final int userId;

  /// Minor units (cents).
  final int totalAmount;
  final DateTime purchaseDate;
  final DateTime createdAt;
  final PurchaseStatus status;

  bool get isPending => status == PurchaseStatus.pending;
  bool get isApproved => status == PurchaseStatus.approved;
}

/// One line of a purchase, with snapshots.
class AppPurchaseItem {
  const AppPurchaseItem({
    required this.id,
    required this.purchaseId,
    this.productId,
    required this.productName,
    required this.quantity,
    required this.costPrice,
    required this.totalCost,
  });

  final int id;
  final int purchaseId;
  final int? productId;
  final String productName;
  final int quantity;

  /// Minor units (cents).
  final int costPrice;

  /// Minor units (cents).
  final int totalCost;
}

/// A purchase together with its lines, for the detail view.
class PurchaseDetail {
  const PurchaseDetail({required this.purchase, required this.items});

  final AppPurchase purchase;
  final List<AppPurchaseItem> items;
}
