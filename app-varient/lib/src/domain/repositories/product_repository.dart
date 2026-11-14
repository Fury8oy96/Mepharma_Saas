import '../models/app_product.dart';

abstract interface class ProductRepository {
  Stream<List<AppProduct>> watchAll();

  Stream<List<AppProduct>> watchLowStock();

  /// Products that expire within [withinDays] days (already expired included),
  /// oldest expiry first. Products without an expiry date are skipped.
  Stream<List<AppProduct>> watchExpiring({required int withinDays});

  Future<List<AppProduct>> getAll();

  /// Case-insensitive search across name, SKU and barcode.
  Future<List<AppProduct>> search(String query);

  Future<AppProduct?> findById(int id);

  Future<AppProduct?> findBySku(String sku);

  Future<AppProduct?> findByBarcode(String barcode);

  Future<AppProduct> create({
    required String sku,
    required String name,
    String? barcode,
    int? categoryId,
    int? supplierId,
    int costPrice,
    int sellingPrice,
    int stockQuantity,
    int lowStockThreshold,
    DateTime? expiryDate,
    String? description,
  });

  Future<void> update(
    int id, {
    required String name,
    String? barcode,
    int? categoryId,
    int? supplierId,
    int? costPrice,
    int? sellingPrice,
    int? lowStockThreshold,
    DateTime? expiryDate,
    String? description,
  });

  Future<void> delete(int id);

  Future<bool> isSkuTaken(String sku, {int? excludeId});

  Future<bool> isBarcodeTaken(String barcode, {int? excludeId});

  Future<int> countLowStock();

  Future<void> refresh();
}
