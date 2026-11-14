import 'package:drift/drift.dart';

import '../../domain/models/app_purchase.dart';
import '../../domain/repositories/purchase_repository.dart';
import '../db/app_database.dart';

class SqlitePurchaseRepository implements PurchaseRepository {
  SqlitePurchaseRepository(this._db);

  final AppDatabase _db;

  @override
  Future<String> generatePurchaseNumber() async {
    final last = await (_db.select(_db.purchases)
          ..orderBy([(p) => OrderingTerm.desc(p.id)])
          ..limit(1))
        .getSingleOrNull();
    final stamp = _dateStamp(DateTime.now());
    final prefix = 'PUR-$stamp-';
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
  Future<AppPurchase> createPurchase({
    int? supplierId,
    required int userId,
    required DateTime purchaseDate,
    required List<PurchaseLineInput> items,
    bool autoApprove = true,
    String? transactionReference,
  }) {
    return _db.transaction(() async {
      final filtered = items.where((i) => i.quantity > 0).toList();
      if (filtered.isEmpty) {
        throw StateError('No items to purchase.');
      }
      final totalAmount = filtered.fold<int>(0, (sum, i) => sum + i.totalCost);
      final invoiceNumber = await generatePurchaseNumber();
      final now = DateTime.now();

      final purchaseId = await _db.into(_db.purchases).insert(
            PurchasesCompanion.insert(
              invoiceNumber: invoiceNumber,
              supplierId: supplierId ?? 1,
              userId: userId,
              totalAmount: totalAmount,
              purchaseDate: purchaseDate,
              status: Value(autoApprove ? 'approved' : 'pending'),
              transactionReference: Value(transactionReference),
              createdAt: Value(now),
            ),
          );

      for (final item in filtered) {
        await _db.into(_db.purchaseItems).insert(
              PurchaseItemsCompanion.insert(
                purchaseId: purchaseId,
                productId: Value(item.productId),
                productName: item.productName,
                quantity: item.quantity,
                costPrice: item.costPrice,
                totalCost: item.totalCost,
              ),
            );

        if (autoApprove && item.productId != null && item.productId! > 0) {
          final product = await (_db.select(_db.products)
                ..where((p) => p.id.equals(item.productId!)))
              .getSingleOrNull();
          if (product != null) {
            await (_db.update(_db.products)
                  ..where((p) => p.id.equals(item.productId!)))
                .write(
              ProductsCompanion(
                stockQuantity: Value(product.stockQuantity + item.quantity),
                costPrice: Value(item.costPrice),
                updatedAt: Value(now),
              ),
            );
            await _db.into(_db.stockAdjustments).insert(
                  StockAdjustmentsCompanion.insert(
                    productId: item.productId!,
                    adjustmentQuantity: item.quantity,
                    reason: const Value('Purchase'),
                    reference: Value('purchase:$purchaseId'),
                    userId: Value(userId),
                  ),
                );
          }
        }
      }

      return (await getPurchaseDetail(purchaseId)).purchase;
    });
  }

  @override
  Future<void> approvePurchase(int id) async {
    return _db.transaction(() async {
      final purchaseRow = await (_db.select(_db.purchases)
            ..where((p) => p.id.equals(id)))
          .getSingleOrNull();
      if (purchaseRow == null) {
        throw StateError('Purchase #$id not found.');
      }
      if (purchaseRow.status == 'approved') {
        return;
      }

      final items = await (_db.select(_db.purchaseItems)
            ..where((i) => i.purchaseId.equals(id)))
          .get();
      final now = DateTime.now();

      for (final item in items) {
        if (item.productId != null && item.productId! > 0) {
          final product = await (_db.select(_db.products)
                ..where((p) => p.id.equals(item.productId!)))
              .getSingleOrNull();
          if (product != null) {
            await (_db.update(_db.products)
                  ..where((p) => p.id.equals(item.productId!)))
                .write(
              ProductsCompanion(
                stockQuantity: Value(product.stockQuantity + item.quantity),
                costPrice: Value(item.costPrice),
                updatedAt: Value(now),
              ),
            );
            await _db.into(_db.stockAdjustments).insert(
                  StockAdjustmentsCompanion.insert(
                    productId: item.productId!,
                    adjustmentQuantity: item.quantity,
                    reason: Value('Purchase order #${purchaseRow.invoiceNumber} approved'),
                    reference: Value('purchase:$id'),
                    userId: Value(purchaseRow.userId),
                  ),
                );
          }
        }
      }

      await (_db.update(_db.purchases)..where((p) => p.id.equals(id))).write(
        const PurchasesCompanion(
          status: Value('approved'),
        ),
      );
    });
  }

  @override
  Stream<List<AppPurchase>> watchPurchases() {
    final query = _db.select(_db.purchases)
      ..orderBy([(p) => OrderingTerm.desc(p.purchaseDate)]);
    return query.watch().map((rows) => rows.map(_mapPurchase).toList());
  }

  @override
  Future<PurchaseDetail> getPurchaseDetail(int id) async {
    final purchaseRow = await (_db.select(_db.purchases)
          ..where((p) => p.id.equals(id)))
        .getSingleOrNull();
    if (purchaseRow == null) {
      throw StateError('Purchase #$id not found.');
    }
    final itemRows = await (_db.select(_db.purchaseItems)
          ..where((i) => i.purchaseId.equals(id)))
        .get();
    return PurchaseDetail(
      purchase: _mapPurchase(purchaseRow),
      items: itemRows.map(_mapItem).toList(),
    );
  }

  @override
  Future<void> refresh() async {}

  AppPurchase _mapPurchase(Purchase row) {
    return AppPurchase(
      id: row.id,
      invoiceNumber: row.invoiceNumber,
      transactionReference: row.transactionReference,
      supplierId: row.supplierId,
      userId: row.userId,
      totalAmount: row.totalAmount,
      purchaseDate: row.purchaseDate,
      createdAt: row.createdAt,
      status: row.status == 'approved' ? PurchaseStatus.approved : PurchaseStatus.pending,
    );
  }

  AppPurchaseItem _mapItem(PurchaseItem row) {
    return AppPurchaseItem(
      id: row.id,
      purchaseId: row.purchaseId,
      productId: row.productId,
      productName: row.productName,
      quantity: row.quantity,
      costPrice: row.costPrice,
      totalCost: row.totalCost,
    );
  }

  static String _dateStamp(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }
}
