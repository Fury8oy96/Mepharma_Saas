import 'package:drift/drift.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/pricing_engine.dart';
import '../../core/utils/sku_generator.dart';
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

  Future<double> _getProfitMargin() async {
    final row = await (_db.select(_db.settings)
          ..where((s) => s.key.equals(AppConstants.settingProfitMargin)))
        .getSingleOrNull();
    final raw = double.tryParse(row?.value ?? '0.3') ?? 0.3;
    return raw;
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
      }

      if (autoApprove) {
        await _executeApprovalInternal(purchaseId, invoiceNumber, userId, now);
      }

      return (await getPurchaseDetail(purchaseId)).purchase;
    });
  }

  Future<void> _executeApprovalInternal(
    int purchaseId,
    String invoiceNumber,
    int userId,
    DateTime now,
  ) async {
    final items = await (_db.select(_db.purchaseItems)
          ..where((i) => i.purchaseId.equals(purchaseId)))
        .get();
    final margin = await _getProfitMargin();

    for (final item in items) {
      int? targetProductId = item.productId;

      // Handle unlisted product: check catalog by name or auto-register with governed price
      if (targetProductId == null || targetProductId <= 0) {
        final existing = await (_db.select(_db.products)
              ..where((p) => p.name.equals(item.productName)))
            .getSingleOrNull();
        if (existing != null) {
          targetProductId = existing.id;
        } else {
          final calculatedSelling =
              PricingEngine.calculateSellingPrice(item.costPrice, margin);
          final generatedSku =
              SkuGenerator.generate(brandName: item.productName);
          targetProductId = await _db.into(_db.products).insert(
                ProductsCompanion.insert(
                  sku: generatedSku,
                  name: item.productName,
                  costPrice: Value(item.costPrice),
                  sellingPrice: Value(calculatedSelling),
                  stockQuantity: Value(item.quantity),
                  lowStockThreshold: const Value(10),
                  createdAt: Value(now),
                  updatedAt: Value(now),
                ),
              );
          await (_db.update(_db.purchaseItems)
                ..where((pi) => pi.id.equals(item.id)))
              .write(
            PurchaseItemsCompanion(productId: Value(targetProductId)),
          );
          await _db.into(_db.stockAdjustments).insert(
                StockAdjustmentsCompanion.insert(
                  productId: targetProductId,
                  adjustmentQuantity: item.quantity,
                  reason: const Value('Purchase'),
                  reference: Value('purchase:$purchaseId'),
                  userId: Value(userId),
                ),
              );
          continue;
        }
      }

      final product = await (_db.select(_db.products)
            ..where((p) => p.id.equals(targetProductId!)))
          .getSingleOrNull();
      if (product != null) {
        final newSellingPrice =
            PricingEngine.calculateSellingPrice(item.costPrice, margin);
        await (_db.update(_db.products)
              ..where((p) => p.id.equals(targetProductId!)))
            .write(
          ProductsCompanion(
            stockQuantity: Value(product.stockQuantity + item.quantity),
            costPrice: Value(item.costPrice),
            sellingPrice: Value(newSellingPrice),
            updatedAt: Value(now),
          ),
        );
        await _db.into(_db.stockAdjustments).insert(
              StockAdjustmentsCompanion.insert(
                productId: targetProductId,
                adjustmentQuantity: item.quantity,
                reason: const Value('Purchase'),
                reference: Value('purchase:$purchaseId'),
                userId: Value(userId),
              ),
            );
      }
    }

    await (_db.update(_db.purchases)..where((p) => p.id.equals(purchaseId)))
        .write(
      const PurchasesCompanion(
        status: Value('approved'),
      ),
    );
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
      final now = DateTime.now();
      await _executeApprovalInternal(
        id,
        purchaseRow.invoiceNumber,
        purchaseRow.userId,
        now,
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
