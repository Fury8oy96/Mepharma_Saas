import 'package:drift/drift.dart';

import '../../domain/models/app_return.dart';
import '../../domain/repositories/return_repository.dart';
import '../db/app_database.dart';
import '../db/enums.dart';

class SqliteReturnRepository implements ReturnRepository {
  SqliteReturnRepository(this._db);

  final AppDatabase _db;

  @override
  Future<List<AppReturn>> getReturnsForSale(int saleId) async {
    final rows = await (_db.select(_db.returns)
          ..where((r) => r.saleId.equals(saleId))
          ..orderBy([(r) => OrderingTerm.desc(r.createdAt)]))
        .get();
    return rows.map(_map).toList();
  }

  @override
  Future<List<AppReturnItem>> getReturnItemsForSale(int saleId) async {
    final returnIds = await (_db.selectOnly(_db.returns)
          ..addColumns([_db.returns.id])
          ..where(_db.returns.saleId.equals(saleId)))
        .map((row) => row.read(_db.returns.id)!)
        .get();
    if (returnIds.isEmpty) {
      return const [];
    }
    final rows = await (_db.select(_db.returnItems)
          ..where((i) => i.returnId.isIn(returnIds)))
        .get();
    return rows.map(_mapItem).toList();
  }

  @override
  Future<AppReturn> createReturn({
    required int saleId,
    required int userId,
    String? reason,
    required List<ReturnLineInput> items,
  }) {
    return _db.transaction(() async {
      final filtered = items.where((i) => i.quantity > 0).toList();
      if (filtered.isEmpty) {
        throw StateError('Nothing to return.');
      }

      final sale = await (_db.select(_db.sales)
            ..where((s) => s.id.equals(saleId)))
          .getSingleOrNull();
      if (sale == null) {
        throw StateError('Sale not found.');
      }
      if (sale.status != SaleStatus.completed) {
        throw StateError('Only completed sales can be returned.');
      }

      // Resolve each line against the stored sale item so the refund uses the
      // price actually charged, and a line cannot be returned more times than
      // it was sold on this sale.
      final resolved = <({ReturnLineInput input, int unitPrice})>[];
      for (final item in filtered) {
        final saleItem = await (_db.select(_db.saleItems)
              ..where((i) =>
                  i.id.equals(item.saleItemId) & i.saleId.equals(saleId)))
            .getSingleOrNull();
        if (saleItem == null) {
          throw StateError(
            'Sale item not found for ${item.productName}.',
          );
        }
        final returned = await (_db.selectOnly(_db.returnItems)
              ..addColumns([_db.returnItems.quantity.sum()])
              ..where(_db.returnItems.saleItemId.equals(item.saleItemId)))
            .getSingle();
        final returnedQty =
            returned.read(_db.returnItems.quantity.sum()) ?? 0;
        if (item.quantity > saleItem.quantity - returnedQty) {
          throw StateError(
            'Return quantity exceeds sold quantity for ${item.productName}.',
          );
        }
        resolved.add((input: item, unitPrice: saleItem.unitPrice));
      }

      final totalRefund = resolved.fold<int>(
        0,
        (sum, r) => sum + r.unitPrice * r.input.quantity,
      );

      final returnId = await _db.into(_db.returns).insert(
            ReturnsCompanion.insert(
              saleId: saleId,
              invoiceNumber: sale.invoiceNumber,
              userId: userId,
              totalRefund: totalRefund,
              reason: Value(reason),
            ),
          );

      final now = DateTime.now();
      for (final r in resolved) {
        final item = r.input;
        await _db.into(_db.returnItems).insert(
              ReturnItemsCompanion.insert(
                returnId: returnId,
                saleItemId: Value(item.saleItemId),
                productId: Value(item.productId),
                productName: item.productName,
                quantity: item.quantity,
                unitPrice: r.unitPrice,
                totalRefund: r.unitPrice * item.quantity,
              ),
            );

        final productId = item.productId;
        if (productId == null) {
          continue;
        }
        final product = await (_db.select(_db.products)
              ..where((p) => p.id.equals(productId)))
            .getSingleOrNull();
        if (product != null) {
          await (_db.update(_db.products)
                ..where((p) => p.id.equals(productId)))
              .write(
            ProductsCompanion(
              stockQuantity: Value(product.stockQuantity + item.quantity),
              updatedAt: Value(now),
            ),
          );
          await _db.into(_db.stockAdjustments).insert(
                StockAdjustmentsCompanion.insert(
                  productId: productId,
                  adjustmentQuantity: item.quantity,
                  reason: const Value('POS return'),
                  reference: Value('return:$returnId'),
                  userId: Value(userId),
                ),
              );
        }
      }

      if (await _isFullyReturned(saleId)) {
        await (_db.update(_db.sales)..where((s) => s.id.equals(saleId))).write(
          SalesCompanion(status: Value(SaleStatus.returned)),
        );
      }

      final row = await (_db.select(_db.returns)
            ..where((r) => r.id.equals(returnId)))
          .getSingle();
      return _map(row);
    });
  }

  Future<bool> _isFullyReturned(int saleId) async {
    final lines = await (_db.select(_db.saleItems)
          ..where((i) => i.saleId.equals(saleId)))
        .get();
    if (lines.isEmpty) {
      return false;
    }
    for (final line in lines) {
      final returned = await (_db.selectOnly(_db.returnItems)
            ..addColumns([_db.returnItems.quantity.sum()])
            ..where(_db.returnItems.saleItemId.equals(line.id)))
          .getSingle();
      final returnedQty = returned.read(_db.returnItems.quantity.sum()) ?? 0;
      if (returnedQty < line.quantity) {
        return false;
      }
    }
    return true;
  }

  AppReturn _map(Return row) {
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

  AppReturnItem _mapItem(ReturnItem row) {
    return AppReturnItem(
      id: row.id,
      returnId: row.returnId,
      saleItemId: row.saleItemId,
      productId: row.productId,
      productName: row.productName,
      quantity: row.quantity,
      unitPrice: row.unitPrice,
      totalRefund: row.totalRefund,
    );
  }
}
