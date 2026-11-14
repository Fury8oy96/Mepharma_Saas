import '../models/app_purchase.dart';

/// One purchased line.
class PurchaseLineInput {
  const PurchaseLineInput({
    this.productId,
    required this.productName,
    required this.quantity,
    required this.costPrice,
  });

  final int? productId;
  final String productName;
  final int quantity;

  /// Minor units (cents).
  final int costPrice;

  /// Minor units (cents).
  int get totalCost => costPrice * quantity;
}

abstract interface class PurchaseRepository {
  /// Next purchase number, e.g. `PUR-20260101-0001`.
  Future<String> generatePurchaseNumber();

  /// Records a purchase, restocks products and writes stock adjustment entries
  /// — all in a single transaction. Each product's cost price is updated to the
  /// latest purchase cost.
  Future<AppPurchase> createPurchase({
    int? supplierId,
    required int userId,
    required DateTime purchaseDate,
    required List<PurchaseLineInput> items,
    String? transactionReference,
  });

  /// Approves a pending purchase order and ingests stock.
  Future<void> approvePurchase(int id);

  /// Purchases for history, newest first.
  Stream<List<AppPurchase>> watchPurchases();

  /// A purchase with its lines for the detail view.
  Future<PurchaseDetail> getPurchaseDetail(int id);

  Future<void> refresh();
}
