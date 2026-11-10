/// Domain representation of a product.
class AppProduct {
  const AppProduct({
    required this.id,
    required this.sku,
    this.barcode,
    required this.name,
    this.categoryId,
    this.supplierId,
    required this.costPrice,
    required this.sellingPrice,
    required this.stockQuantity,
    required this.lowStockThreshold,
    this.expiryDate,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String sku;
  final String? barcode;
  final String name;
  final int? categoryId;
  final int? supplierId;

  /// Minor units (cents).
  final int costPrice;

  /// Minor units (cents).
  final int sellingPrice;

  final int stockQuantity;
  final int lowStockThreshold;
  final DateTime? expiryDate;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isLowStock => stockQuantity <= lowStockThreshold;

  bool get isExpired {
    final expiry = expiryDate;
    if (expiry == null) {
      return false;
    }
    final today = DateTime.now();
    return expiry.isBefore(DateTime(today.year, today.month, today.day + 1));
  }

  /// Days until expiry (0 when already expired), or null when no expiry set.
  int? get daysUntilExpiry {
    final expiry = expiryDate;
    if (expiry == null) {
      return null;
    }
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = DateTime(expiry.year, expiry.month, expiry.day);
    return end.difference(start).inDays;
  }

  /// True when the product expires within [days] days or is already expired.
  bool isExpiringWithin(int days) {
    final remaining = daysUntilExpiry;
    return remaining != null && remaining <= days;
  }
}
