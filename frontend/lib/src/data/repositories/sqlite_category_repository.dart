import 'package:drift/drift.dart';

import '../../domain/models/app_category.dart';
import '../../domain/repositories/category_repository.dart';
import '../db/app_database.dart';

class SqliteCategoryRepository implements CategoryRepository {
  SqliteCategoryRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<AppCategory>> watchAll() {
    final query = _db.select(_db.categories)
      ..orderBy([(c) => OrderingTerm(expression: c.name)]);
    return query.watch().map((rows) => rows.map(_map).toList());
  }

  @override
  Future<List<AppCategory>> getAll() async {
    final query = _db.select(_db.categories)
      ..orderBy([(c) => OrderingTerm(expression: c.name)]);
    final rows = await query.get();
    return rows.map(_map).toList();
  }

  @override
  Future<AppCategory?> findById(int id) async {
    final row = await (_db.select(_db.categories)
          ..where((c) => c.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _map(row);
  }

  @override
  Future<AppCategory> create({required String name, String? description}) async {
    final id = await _db.into(_db.categories).insert(
          CategoriesCompanion.insert(name: name, description: Value(description)),
        );
    return (await findById(id))!;
  }

  @override
  Future<void> update(int id, {required String name, String? description}) async {
    await (_db.update(_db.categories)
          ..where((c) => c.id.equals(id)))
        .write(CategoriesCompanion(name: Value(name), description: Value(description)));
  }

  @override
  Future<void> delete(int id) async {
    await (_db.delete(_db.categories)..where((c) => c.id.equals(id))).go();
  }

  AppCategory _map(Category row) {
    return AppCategory(id: row.id, name: row.name, description: row.description);
  }

  @override
  Future<void> refresh() async {}
}
