import 'package:drift/drift.dart';

import '../../domain/models/app_stock_adjustment.dart';
import '../../domain/repositories/stock_adjustment_repository.dart';
import '../db/app_database.dart';

class SqliteStockAdjustmentRepository implements StockAdjustmentRepository {
  SqliteStockAdjustmentRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<AppStockAdjustment>> watchForProduct(int productId) {
    final query = _db.select(_db.stockAdjustments)
      ..where((s) => s.productId.equals(productId))
      ..orderBy([(s) => OrderingTerm.desc(s.createdAt)]);
    return query.watch().map((rows) => rows.map(_map).toList());
  }

  @override
  Future<List<AppStockAdjustment>> getAll() async {
    final query = _db.select(_db.stockAdjustments)
      ..orderBy([(s) => OrderingTerm.desc(s.createdAt)]);
    final rows = await query.get();
    return rows.map(_map).toList();
  }

  @override
  Future<void> adjustStock({
    required int productId,
    required int adjustmentQuantity,
    String? reason,
    String? reference,
    int? userId,
  }) async {
    if (adjustmentQuantity == 0) {
      return;
    }
    await _db.transaction(() async {
      final product = await (_db.select(_db.products)
            ..where((p) => p.id.equals(productId)))
          .getSingle();
      final newStock = product.stockQuantity + adjustmentQuantity;
      if (newStock < 0) {
        throw StateError(
          'Adjustment would leave ${product.name} with negative stock.',
        );
      }
      await (_db.update(_db.products)
            ..where((p) => p.id.equals(productId)))
          .write(
        ProductsCompanion(
          stockQuantity: Value(newStock),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _db.into(_db.stockAdjustments).insert(
            StockAdjustmentsCompanion.insert(
              productId: productId,
              adjustmentQuantity: adjustmentQuantity,
              reason: Value(reason),
              reference: Value(reference ?? 'manual'),
              userId: Value(userId),
            ),
          );
    });
  }

  AppStockAdjustment _map(StockAdjustment row) {
    return AppStockAdjustment(
      id: row.id,
      productId: row.productId,
      adjustmentQuantity: row.adjustmentQuantity,
      reason: row.reason,
      reference: row.reference,
      userId: row.userId,
      createdAt: row.createdAt,
    );
  }
}
