import 'package:drift/drift.dart';

import '../../domain/models/app_supplier.dart';
import '../../domain/repositories/supplier_repository.dart';
import '../db/app_database.dart';

class SqliteSupplierRepository implements SupplierRepository {
  SqliteSupplierRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<AppSupplier>> watchAll() {
    final query = _db.select(_db.suppliers)
      ..orderBy([(s) => OrderingTerm(expression: s.name)]);
    return query.watch().map((rows) => rows.map(_map).toList());
  }

  @override
  Future<List<AppSupplier>> getAll() async {
    final query = _db.select(_db.suppliers)
      ..orderBy([(s) => OrderingTerm(expression: s.name)]);
    final rows = await query.get();
    return rows.map(_map).toList();
  }

  @override
  Future<AppSupplier?> findById(int id) async {
    final row = await (_db.select(_db.suppliers)
          ..where((s) => s.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _map(row);
  }

  @override
  Future<AppSupplier> create({
    required String name,
    String? contactPerson,
    String? phone,
    String? email,
    String? address,
  }) async {
    final id = await _db.into(_db.suppliers).insert(
          SuppliersCompanion.insert(
            name: name,
            contactPerson: Value(contactPerson),
            phone: Value(phone),
            email: Value(email),
            address: Value(address),
          ),
        );
    return (await findById(id))!;
  }

  @override
  Future<void> update(
    int id, {
    required String name,
    String? contactPerson,
    String? phone,
    String? email,
    String? address,
  }) async {
    await (_db.update(_db.suppliers)
          ..where((s) => s.id.equals(id)))
        .write(
      SuppliersCompanion(
        name: Value(name),
        contactPerson: Value(contactPerson),
        phone: Value(phone),
        email: Value(email),
        address: Value(address),
      ),
    );
  }

  @override
  Future<void> delete(int id) async {
    await (_db.delete(_db.suppliers)..where((s) => s.id.equals(id))).go();
  }

  AppSupplier _map(Supplier row) {
    return AppSupplier(
      id: row.id,
      name: row.name,
      contactPerson: row.contactPerson,
      phone: row.phone,
      email: row.email,
      address: row.address,
    );
  }

  @override
  Future<void> refresh() async {}
}
