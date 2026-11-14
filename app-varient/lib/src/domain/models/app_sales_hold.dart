import '../../data/db/enums.dart';

/// A held (paused) POS cart, so it can be resumed later.
class AppSalesHold {
  const AppSalesHold({
    required this.id,
    required this.holdNumber,
    required this.userId,
    required this.itemsJson,
    required this.subtotal,
    required this.discount,
    required this.discountType,
    required this.totalAmount,
    required this.createdAt,
  });

  final int id;
  final String holdNumber;
  final int userId;

  /// Serialized cart (JSON list of product snapshots).
  final String itemsJson;

  /// Minor units (cents).
  final int subtotal;

  /// Discount value: cents when [discountType] is fixed, percent * 100 when
  /// percentage.
  final int discount;
  final DiscountType? discountType;

  /// Minor units (cents), before tax.
  final int totalAmount;
  final DateTime createdAt;
}
