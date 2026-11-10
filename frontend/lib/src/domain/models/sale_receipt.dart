import '../../data/db/enums.dart';

/// One line of a completed sale, with snapshots for history and reprints.
class SaleLineItem {
  const SaleLineItem({
    required this.productId,
    required this.productName,
    this.barcode,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  final int productId;
  final String productName;
  final String? barcode;
  final int quantity;

  /// Minor units (cents).
  final int unitPrice;

  /// Minor units (cents).
  final int totalPrice;
}

/// Result of a completed sale, used for receipts and history.
class SaleReceipt {
  const SaleReceipt({
    required this.id,
    required this.invoiceNumber,
    required this.createdAt,
    required this.subtotal,
    required this.discount,
    required this.discountType,
    required this.taxAmount,
    required this.totalAmount,
    required this.paidAmount,
    required this.changeAmount,
    required this.paymentMethod,
    this.customerName,
    this.customerId,
    required this.items,
  });

  final int id;
  final String invoiceNumber;
  final DateTime createdAt;
  final int subtotal;
  final int discount;
  final DiscountType? discountType;
  final int taxAmount;
  final int totalAmount;
  final int paidAmount;
  final int changeAmount;

  /// Enum name: 'cash', 'card', 'mobileMoney' or 'credit'.
  final String paymentMethod;
  final String? customerName;
  final int? customerId;
  final List<SaleLineItem> items;
}
