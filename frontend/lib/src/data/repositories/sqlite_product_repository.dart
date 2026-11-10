import 'package:drift/drift.dart';

import '../../domain/models/app_product.dart';
import '../../domain/repositories/product_repository.dart';
import '../db/app_database.dart';

class SqliteProductRepository implements ProductRepository {
  SqliteProductRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<AppProduct>> watchAll() {
    final query = _db.select(_db.products)
      ..orderBy([(p) => OrderingTerm(expression: p.name)]);
    return query.watch().map((rows) => rows.map(_map).toList());
  }

  @override
  Stream<List<AppProduct>> watchLowStock() {
    final query = _db.select(_db.products)
      ..where((p) => p.stockQuantity.isSmallerOrEqual(p.lowStockThreshold))
      ..orderBy([(p) => OrderingTerm.asc(p.stockQuantity)]);
    return query.watch().map((rows) => rows.map(_map).toList());
  }

  @override
  Stream<List<AppProduct>> watchExpiring({required int withinDays}) {
    final cutoff = DateTime.now().add(Duration(days: withinDays));
    final query = _db.select(_db.products)
      ..where((p) =>
          p.expiryDate.isNotNull() &
          p.expiryDate.isSmallerOrEqualValue(cutoff))
      ..orderBy([(p) => OrderingTerm.asc(p.expiryDate)]);
    return query.watch().map((rows) => rows.map(_map).toList());
  }

  @override
  Future<List<AppProduct>> getAll() async {
    final query = _db.select(_db.products)
      ..orderBy([(p) => OrderingTerm(expression: p.name)]);
    final rows = await query.get();
    return rows.map(_map).toList();
  }

  @override
  Future<List<AppProduct>> search(String query) async {
    final term = query.trim().toLowerCase();
    if (term.isEmpty) {
      return getAll();
    }
    final all = await getAll();
    return all.where((p) {
      return p.name.toLowerCase().contains(term) ||
          p.sku.toLowerCase().contains(term) ||
          (p.barcode?.toLowerCase().contains(term) ?? false);
    }).toList();
  }

  @override
  Future<AppProduct?> findById(int id) async {
    final row = await (_db.select(_db.products)
          ..where((p) => p.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _map(row);
  }

  @override
  Future<AppProduct?> findBySku(String sku) async {
    final row = await (_db.select(_db.products)
          ..where((p) => p.sku.lower().equals(sku.toLowerCase())))
        .getSingleOrNull();
    return row == null ? null : _map(row);
  }

  @override
  Future<AppProduct?> findByBarcode(String barcode) async {
    final row = await (_db.select(_db.products)
          ..where((p) => p.barcode.equals(barcode)))
        .getSingleOrNull();
    return row == null ? null : _map(row);
  }

  @override
  Future<AppProduct> create({
    required String sku,
    required String name,
    String? barcode,
    int? categoryId,
    int? supplierId,
    int costPrice = 0,
    int sellingPrice = 0,
    int stockQuantity = 0,
    int lowStockThreshold = 10,
    DateTime? expiryDate,
    String? description,
  }) async {
    final id = await _db.into(_db.products).insert(
          ProductsCompanion.insert(
            sku: sku,
            barcode: Value(barcode),
            name: name,
            categoryId: Value(categoryId),
            supplierId: Value(supplierId),
            costPrice: Value(costPrice),
            sellingPrice: Value(sellingPrice),
            stockQuantity: Value(stockQuantity),
            lowStockThreshold: Value(lowStockThreshold),
            expiryDate: Value(expiryDate),
            description: Value(description),
          ),
        );
    return (await findById(id))!;
  }

  @override
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
  }) async {
    final existing = await findById(id);
    if (existing == null) {
      await _db.into(_db.products).insert(
        ProductsCompanion.insert(
          id: Value(id),
          sku: 'SKU-$id',
          name: name,
          barcode: Value(barcode),
          categoryId: Value(categoryId),
          supplierId: Value(supplierId),
          costPrice: Value(costPrice ?? 0),
          sellingPrice: Value(sellingPrice ?? 0),
          lowStockThreshold: Value(lowStockThreshold ?? 10),
          expiryDate: Value(expiryDate),
          description: Value(description),
        ),
        onConflict: DoUpdate((_) => ProductsCompanion(
          name: Value(name),
          barcode: Value(barcode),
          categoryId: Value(categoryId),
          supplierId: Value(supplierId),
          costPrice: Value(costPrice ?? 0),
          sellingPrice: Value(sellingPrice ?? 0),
          lowStockThreshold: Value(lowStockThreshold ?? 10),
          expiryDate: Value(expiryDate),
          description: Value(description),
          updatedAt: Value(DateTime.now()),
        )),
      );
      return;
    }

    await (_db.update(_db.products)
          ..where((p) => p.id.equals(id)))
        .write(
      ProductsCompanion(
        name: Value(name),
        barcode: Value(barcode),
        categoryId: Value(categoryId),
        supplierId: Value(supplierId),
        costPrice: Value(costPrice ?? existing.costPrice),
        sellingPrice: Value(sellingPrice ?? existing.sellingPrice),
        lowStockThreshold: Value(lowStockThreshold ?? existing.lowStockThreshold),
        expiryDate: Value(expiryDate),
        description: Value(description),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> delete(int id) async {
    await _db.transaction(() async {
      await (_db.delete(_db.stockAdjustments)
            ..where((s) => s.productId.equals(id)))
          .go();
      await (_db.delete(_db.products)..where((p) => p.id.equals(id))).go();
    });
  }

  @override
  Future<bool> isSkuTaken(String sku, {int? excludeId}) async {
    final rows = await (_db.select(_db.products)
          ..where((p) => excludeId == null
              ? p.sku.lower().equals(sku.toLowerCase())
              : p.sku.lower().equals(sku.toLowerCase()) &
                  p.id.equals(excludeId).not()))
        .get();
    return rows.isNotEmpty;
  }

  @override
  Future<bool> isBarcodeTaken(String barcode, {int? excludeId}) async {
    if (barcode.trim().isEmpty) {
      return false;
    }
    final rows = await (_db.select(_db.products)
          ..where((p) => excludeId == null
              ? p.barcode.equals(barcode)
              : p.barcode.equals(barcode) & p.id.equals(excludeId).not()))
        .get();
    return rows.isNotEmpty;
  }

  @override
  Future<int> countLowStock() async {
    final query = _db.selectOnly(_db.products)
      ..addColumns([countAll()])
      ..where(
        _db.products.stockQuantity.isSmallerOrEqual(_db.products.lowStockThreshold),
      );
    final row = await query.getSingle();
    return row.read(countAll()) ?? 0;
  }

  AppProduct _map(Product row) {
    return AppProduct(
      id: row.id,
      sku: row.sku,
      barcode: row.barcode,
      name: row.name,
      categoryId: row.categoryId,
      supplierId: row.supplierId,
      costPrice: row.costPrice,
      sellingPrice: row.sellingPrice,
      stockQuantity: row.stockQuantity,
      lowStockThreshold: row.lowStockThreshold,
      expiryDate: row.expiryDate,
      description: row.description,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  @override
  Future<void> refresh() async {}
}
