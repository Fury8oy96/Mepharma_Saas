import '../../data/db/enums.dart';
import '../models/app_sale.dart';
import '../models/sale_receipt.dart';

abstract interface class SaleRepository {
  /// Next invoice number, e.g. `INV-20260101-0001`.
  Future<String> generateInvoiceNumber();

  /// Records a sale and its lines, deducts stock and writes stock adjustment
  /// entries — all in a single transaction.
  Future<SaleReceipt> completeSale({
    required List<SaleLineItem> items,
    required int subtotal,
    required int discount,
    DiscountType? discountType,
    required int taxAmount,
    required int totalAmount,
    required int paidAmount,
    required int changeAmount,
    required String paymentMethod,
    required int userId,
    String? customerName,
    int? customerId,
    String? transactionReference,
  });

  /// Sales for history, newest first, optionally filtered. Payment method and
  /// search use case-insensitive matching.
  Stream<List<AppSale>> watchSales({
    DateTime? from,
    DateTime? to,
    String? paymentMethod,
    SaleStatus? status,
    String? search,
  });

  /// A sale with its lines and returns for the detail view.
  Future<SaleDetail> getSaleDetail(int id);

  Future<void> refresh();
}
