import 'package:drift/drift.dart';

import '../../domain/models/app_sales_hold.dart';
import '../../domain/repositories/sales_hold_repository.dart';
import '../db/app_database.dart';
import '../db/enums.dart';

class SqliteSalesHoldRepository implements SalesHoldRepository {
  SqliteSalesHoldRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<AppSalesHold>> watchAll() {
    final query = _db.select(_db.salesHolds)
      ..orderBy([(s) => OrderingTerm.desc(s.createdAt)]);
    return query.watch().map((rows) => rows.map(_map).toList());
  }

  @override
  Future<AppSalesHold> createHold({
    required int userId,
    required String itemsJson,
    required int subtotal,
    required int discount,
    DiscountType? discountType,
    required int totalAmount,
  }) async {
    final id = await _db.transaction(() async {
      final previous =
          await (_db.select(_db.salesHolds)
                ..orderBy([(s) => OrderingTerm.desc(s.id)])
                ..limit(1))
              .getSingleOrNull();
      final stamp = _dateStamp(DateTime.now());
      final prefix = 'HLD-$stamp-';
      var seq = 1;
      if (previous != null) {
        final match = RegExp(
          '^$prefix(\\d+)\$',
        ).firstMatch(previous.holdNumber);
        if (match != null) {
          seq = int.parse(match.group(1)!) + 1;
        }
      }
      final holdNumber = '$prefix${seq.toString().padLeft(4, '0')}';

      return _db
          .into(_db.salesHolds)
          .insert(
            SalesHoldsCompanion.insert(
              holdNumber: holdNumber,
              userId: userId,
              itemsJson: itemsJson,
              subtotal: subtotal,
              discount: Value(discount),
              discountType: Value(discountType),
              totalAmount: totalAmount,
            ),
          );
    });
    return (await _findById(id))!;
  }

  @override
  Future<void> deleteHold(int id) async {
    await (_db.delete(_db.salesHolds)..where((s) => s.id.equals(id))).go();
  }

  Future<AppSalesHold?> _findById(int id) async {
    final row = await (_db.select(
      _db.salesHolds,
    )..where((s) => s.id.equals(id))).getSingleOrNull();
    return row == null ? null : _map(row);
  }

  AppSalesHold _map(SalesHold row) {
    return AppSalesHold(
      id: row.id,
      holdNumber: row.holdNumber,
      userId: row.userId,
      itemsJson: row.itemsJson,
      subtotal: row.subtotal,
      discount: row.discount,
      discountType: row.discountType,
      totalAmount: row.totalAmount,
      createdAt: row.createdAt,
    );
  }

  static String _dateStamp(DateTime d) =>
      '${d.year}${_two(d.month)}${_two(d.day)}';

  static String _two(int n) => n.toString().padLeft(2, '0');
}
