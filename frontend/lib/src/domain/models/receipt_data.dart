import 'store_settings.dart';

/// A line on a receipt.
class ReceiptLine {
  const ReceiptLine({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  final String name;
  final int quantity;

  /// Minor units (cents).
  final int unitPrice;

  /// Minor units (cents).
  final int totalPrice;
}

/// All data needed to render and print a receipt.
class ReceiptData {
  const ReceiptData({
    required this.store,
    required this.invoiceNumber,
    required this.dateTime,
    required this.cashierName,
    this.customerName,
    required this.paymentMethod,
    required this.lines,
    required this.subtotal,
    required this.discount,
    required this.taxAmount,
    required this.totalAmount,
    required this.paidAmount,
    required this.changeAmount,
  });

  final StoreSettings store;
  final String invoiceNumber;
  final String dateTime;
  final String cashierName;
  final String? customerName;
  final String paymentMethod;
  final List<ReceiptLine> lines;
  final int subtotal;
  final int discount;
  final int taxAmount;
  final int totalAmount;
  final int paidAmount;
  final int changeAmount;
}
