import '../models/app_category.dart';

abstract interface class CategoryRepository {
  Stream<List<AppCategory>> watchAll();

  Future<List<AppCategory>> getAll();

  Future<AppCategory?> findById(int id);

  Future<AppCategory> create({required String name, String? description});

  Future<void> update(int id, {required String name, String? description});

  Future<void> delete(int id);

  Future<void> refresh();
}
