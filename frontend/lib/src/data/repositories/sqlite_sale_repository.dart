import 'package:drift/drift.dart';

import '../../domain/models/app_return.dart';
import '../../domain/models/app_sale.dart';
import '../../domain/models/sale_receipt.dart';
import '../../domain/repositories/sale_repository.dart';
import '../db/app_database.dart';
import '../db/enums.dart';

class SqliteSaleRepository implements SaleRepository {
  SqliteSaleRepository(this._db);

  final AppDatabase _db;

  @override
  Future<String> generateInvoiceNumber() async {
    final last = await (_db.select(_db.sales)
          ..orderBy([(s) => OrderingTerm.desc(s.id)])
          ..limit(1))
        .getSingleOrNull();
    final stamp = _dateStamp(DateTime.now());
    final prefix = 'INV-$stamp-';
    var seq = 1;
    if (last != null) {
      final match = RegExp('^$prefix(\\d+)\$').firstMatch(last.invoiceNumber);
      if (match != null) {
        seq = int.parse(match.group(1)!) + 1;
      }
    }
    return '$prefix${seq.toString().padLeft(4, '0')}';
  }

  @override
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
  }) {
    return _db.transaction(() async {
      final invoiceNumber = await generateInvoiceNumber();
      final now = DateTime.now();

      final saleId = await _db.into(_db.sales).insert(
            SalesCompanion.insert(
              invoiceNumber: invoiceNumber,
              userId: userId,
              customerName: Value(customerName),
              customerId: Value(customerId),
              subtotal: Value(subtotal),
              discount: Value(discount),
              discountType: Value(discountType),
              taxAmount: Value(taxAmount),
              totalAmount: totalAmount,
              paidAmount: Value(paidAmount),
              changeAmount: Value(changeAmount),
              paymentMethod: Value(paymentMethod),
              transactionReference: Value(transactionReference),
              status: SaleStatus.completed,
              createdAt: Value(now),
            ),
          );

      for (final item in items) {
        if (item.quantity <= 0) {
          throw StateError('Sale line quantity must be positive.');
        }
        await _db.into(_db.saleItems).insert(
              SaleItemsCompanion.insert(
                saleId: saleId,
                productId: Value(item.productId),
                productName: item.productName,
                barcode: Value(item.barcode),
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                discount: const Value(0),
                totalPrice: item.totalPrice,
              ),
            );

        final product = await (_db.select(_db.products)
              ..where((p) => p.id.equals(item.productId)))
            .getSingle();
        if (item.quantity > product.stockQuantity) {
          throw StateError(
            'Insufficient stock for ${product.name}: '
            '${product.stockQuantity} available.',
          );
        }
        await (_db.update(_db.products)
              ..where((p) => p.id.equals(item.productId)))
            .write(
          ProductsCompanion(
            stockQuantity: Value(product.stockQuantity - item.quantity),
            updatedAt: Value(now),
          ),
        );

        await _db.into(_db.stockAdjustments).insert(
              StockAdjustmentsCompanion.insert(
                productId: item.productId,
                adjustmentQuantity: -item.quantity,
                reason: const Value('POS sale'),
                reference: Value('sale:$saleId'),
                userId: Value(userId),
              ),
            );
      }

      return SaleReceipt(
        id: saleId,
        invoiceNumber: invoiceNumber,
        createdAt: now,
        subtotal: subtotal,
        discount: discount,
        discountType: discountType,
        taxAmount: taxAmount,
        totalAmount: totalAmount,
        paidAmount: paidAmount,
        changeAmount: changeAmount,
        paymentMethod: paymentMethod,
        transactionReference: transactionReference,
        customerName: customerName,
        customerId: customerId,
        items: items,
      );
    });
  }

  @override
  Stream<List<AppSale>> watchSales({
    DateTime? from,
    DateTime? to,
    String? paymentMethod,
    SaleStatus? status,
    String? search,
  }) {
    final query = _db.select(_db.sales);
    if (from != null) {
      query.where((s) => s.createdAt.isBiggerOrEqualValue(from));
    }
    if (to != null) {
      query.where((s) => s.createdAt.isSmallerOrEqualValue(to));
    }
    if (paymentMethod != null && paymentMethod.isNotEmpty) {
      query.where(
        (s) => s.paymentMethod.lower().equals(paymentMethod.toLowerCase()),
      );
    }
    if (status != null) {
      query.where((s) => s.status.equals(status.name));
    }
    if (search != null && search.trim().isNotEmpty) {
      final term = search.trim().toLowerCase();
      query.where((s) =>
          s.invoiceNumber.lower().contains(term) |
          s.customerName.lower().contains(term));
    }
    query.orderBy([(s) => OrderingTerm.desc(s.createdAt)]);
    return query.watch().map((rows) => rows.map(_mapSale).toList());
  }

  @override
  Future<SaleDetail> getSaleDetail(int id) async {
    final saleRow = await (_db.select(_db.sales)
          ..where((s) => s.id.equals(id)))
        .getSingleOrNull();
    if (saleRow == null) {
      throw StateError('Sale $id not found.');
    }
    final itemRows = await (_db.select(_db.saleItems)
          ..where((i) => i.saleId.equals(id)))
        .get();
    final returnRows = await (_db.select(_db.returns)
          ..where((r) => r.saleId.equals(id))
          ..orderBy([(r) => OrderingTerm.desc(r.createdAt)]))
        .get();
    return SaleDetail(
      sale: _mapSale(saleRow),
      items: itemRows.map(_mapItem).toList(),
      returns: returnRows.map(_mapReturn).toList(),
    );
  }

  AppSale _mapSale(Sale row) {
    return AppSale(
      id: row.id,
      invoiceNumber: row.invoiceNumber,
      userId: row.userId,
      customerName: row.customerName,
      customerId: row.customerId,
      subtotal: row.subtotal,
      discount: row.discount,
      discountType: row.discountType,
      taxAmount: row.taxAmount,
      totalAmount: row.totalAmount,
      paidAmount: row.paidAmount,
      changeAmount: row.changeAmount,
      paymentMethod: row.paymentMethod,
      transactionReference: row.transactionReference,
      status: row.status,
      createdAt: row.createdAt,
    );
  }

  AppSaleItem _mapItem(SaleItem row) {
    return AppSaleItem(
      id: row.id,
      saleId: row.saleId,
      productId: row.productId,
      productName: row.productName,
      barcode: row.barcode,
      quantity: row.quantity,
      unitPrice: row.unitPrice,
      discount: row.discount,
      totalPrice: row.totalPrice,
    );
  }

  AppReturn _mapReturn(Return row) {
    return AppReturn(
      id: row.id,
      saleId: row.saleId,
      invoiceNumber: row.invoiceNumber,
      userId: row.userId,
      totalRefund: row.totalRefund,
      reason: row.reason,
      createdAt: row.createdAt,
    );
  }

  static String _dateStamp(DateTime d) =>
      '${d.year}${_two(d.month)}${_two(d.day)}';

  static String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Future<void> refresh() async {}

  /// Idempotently mirrors an already-committed server receipt into local SQLite
  /// without generating a second invoice number or failing on missing local stock.
  Future<void> mirrorServerSale(SaleReceipt receipt, {required int userId}) async {
    await _db.transaction(() async {
      final existing = await (_db.select(_db.sales)
            ..where((s) => s.invoiceNumber.equals(receipt.invoiceNumber)))
          .getSingleOrNull();
      if (existing != null) {
        return;
      }

      final saleId = await _db.into(_db.sales).insert(
            SalesCompanion.insert(
              invoiceNumber: receipt.invoiceNumber,
              userId: userId,
              customerName: Value(receipt.customerName),
              customerId: Value(receipt.customerId),
              subtotal: Value(receipt.subtotal),
              discount: Value(receipt.discount),
              discountType: Value(receipt.discountType),
              taxAmount: Value(receipt.taxAmount),
              totalAmount: receipt.totalAmount,
              paidAmount: Value(receipt.paidAmount),
              changeAmount: Value(receipt.changeAmount),
              paymentMethod: Value(receipt.paymentMethod),
              transactionReference: Value(receipt.transactionReference),
              status: SaleStatus.completed,
              createdAt: Value(receipt.createdAt),
            ),
          );

      for (final item in receipt.items) {
        await _db.into(_db.saleItems).insert(
              SaleItemsCompanion.insert(
                saleId: saleId,
                productId: Value(item.productId),
                productName: item.productName,
                barcode: Value(item.barcode),
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                discount: const Value(0),
                totalPrice: item.totalPrice,
              ),
            );

        final product = await (_db.select(_db.products)
              ..where((p) => p.id.equals(item.productId)))
            .getSingleOrNull();
        if (product != null) {
          final nextStock = (product.stockQuantity - item.quantity) < 0
              ? 0
              : (product.stockQuantity - item.quantity);
          await (_db.update(_db.products)
                ..where((p) => p.id.equals(item.productId)))
              .write(
            ProductsCompanion(
              stockQuantity: Value(nextStock),
              updatedAt: Value(receipt.createdAt),
            ),
          );
        }
      }
    });
  }
}
