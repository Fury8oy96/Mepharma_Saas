import '../models/app_supplier.dart';

abstract interface class SupplierRepository {
  Stream<List<AppSupplier>> watchAll();

  Future<List<AppSupplier>> getAll();

  Future<AppSupplier?> findById(int id);

  Future<AppSupplier> create({
    required String name,
    String? contactPerson,
    String? phone,
    String? email,
    String? address,
  });

  Future<void> update(
    int id, {
    required String name,
    String? contactPerson,
    String? phone,
    String? email,
    String? address,
  });

  Future<void> delete(int id);

  Future<void> refresh();
}
