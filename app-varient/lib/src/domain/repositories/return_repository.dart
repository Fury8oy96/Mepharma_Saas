import '../models/app_return.dart';

/// One returned line: how much of a specific sold line is being returned.
class ReturnLineInput {
  const ReturnLineInput({
    required this.saleItemId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    this.productId,
  });

  final int saleItemId;

  /// Null when the product has been deleted; such lines are refunded but not
  /// restocked.
  final int? productId;
  final String productName;

  /// Minor units (cents), the original sale unit price.
  final int unitPrice;
  final int quantity;
}

abstract interface class ReturnRepository {
  /// Records a return, restocks the returned products, writes stock adjustment
  /// entries and marks the sale fully returned when everything is returned —
  /// all in a single transaction.
  ///
  /// Throws if a returned quantity exceeds what was sold (minus earlier
  /// returns) for any line.
  Future<AppReturn> createReturn({
    required int saleId,
    required int userId,
    String? reason,
    required List<ReturnLineInput> items,
  });

  /// Returns processed against a sale, newest first.
  Future<List<AppReturn>> getReturnsForSale(int saleId);

  /// All returned lines for a sale (to compute how much is still returnable).
  Future<List<AppReturnItem>> getReturnItemsForSale(int saleId);

  /// Real-time stream of all processed returns, newest first.
  Stream<List<AppReturn>> watchAllReturns();

  /// Retrieve all processed returns.
  Future<List<AppReturn>> getAllReturns();
}
