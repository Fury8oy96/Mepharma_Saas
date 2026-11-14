import '../../data/db/enums.dart';
import 'app_return.dart';

/// A completed sale, as stored in history.
class AppSale {
  const AppSale({
    required this.id,
    required this.invoiceNumber,
    required this.userId,
    this.customerName,
    this.customerId,
    required this.subtotal,
    required this.discount,
    this.discountType,
    required this.taxAmount,
    required this.totalAmount,
    required this.paidAmount,
    required this.changeAmount,
    this.paymentMethod,
    this.transactionReference,
    required this.status,
    required this.createdAt,
  });

  final int id;
  final String invoiceNumber;
  final int userId;
  final String? customerName;
  final int? customerId;

  /// Minor units (cents), before discount/tax.
  final int subtotal;

  /// Minor units (cents).
  final int discount;
  final DiscountType? discountType;

  /// Minor units (cents).
  final int taxAmount;

  /// Minor units (cents), final payable.
  final int totalAmount;

  /// Minor units (cents).
  final int paidAmount;

  /// Minor units (cents).
  final int changeAmount;

  /// Enum name: 'cash', 'card', 'bankTransfer', 'credit' or 'mobileMoney'.
  final String? paymentMethod;

  /// Bank transfer or transaction reference number (رقم العملية).
  final String? transactionReference;

  final SaleStatus status;
  final DateTime createdAt;
}

/// One line of a sale, with snapshots for history and reprints.
class AppSaleItem {
  const AppSaleItem({
    required this.id,
    required this.saleId,
    this.productId,
    required this.productName,
    this.barcode,
    required this.quantity,
    required this.unitPrice,
    required this.discount,
    required this.totalPrice,
  });

  final int id;
  final int saleId;

  /// Nullable because products can be deleted (FK set null).
  final int? productId;
  final String productName;
  final String? barcode;
  final int quantity;

  /// Minor units (cents).
  final int unitPrice;

  /// Minor units (cents), line discount.
  final int discount;

  /// Minor units (cents).
  final int totalPrice;
}

/// A sale together with its lines and any returns, for the detail view.
class SaleDetail {
  const SaleDetail({
    required this.sale,
    required this.items,
    required this.returns,
  });

  final AppSale sale;
  final List<AppSaleItem> items;

  /// Returns processed against this sale, newest first.
  final List<AppReturn> returns;
}
