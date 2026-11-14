import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mepharma/src/data/db/app_database.dart';
import 'package:mepharma/src/data/repositories/sqlite_category_repository.dart';
import 'package:mepharma/src/data/repositories/sqlite_product_repository.dart';
import 'package:mepharma/src/data/repositories/sqlite_settings_repository.dart';
import 'package:mepharma/src/data/repositories/sqlite_stock_adjustment_repository.dart';
import 'package:mepharma/src/data/repositories/sqlite_supplier_repository.dart';
import 'package:mepharma/src/domain/models/store_settings.dart';

void main() {
  late AppDatabase db;
  late SqliteCategoryRepository categories;
  late SqliteSupplierRepository suppliers;
  late SqliteProductRepository products;
  late SqliteStockAdjustmentRepository stockAdjustments;
  late SqliteSettingsRepository settings;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    categories = SqliteCategoryRepository(db);
    suppliers = SqliteSupplierRepository(db);
    products = SqliteProductRepository(db);
    stockAdjustments = SqliteStockAdjustmentRepository(db);
    settings = SqliteSettingsRepository(db);
  });

  tearDown(() => db.close());

  group('categories', () {
    test('create, read, update, delete', () async {
      final created = await categories.create(name: 'Antibiotics');
      expect(created.id, greaterThan(0));
      expect(created.name, 'Antibiotics');

      final found = await categories.findById(created.id);
      expect(found, isNotNull);
      expect(found!.name, 'Antibiotics');

      await categories.update(created.id, name: 'Antibiotics (Updated)');
      final updated = await categories.findById(created.id);
      expect(updated!.name, 'Antibiotics (Updated)');

      await categories.delete(created.id);
      expect(await categories.findById(created.id), isNull);
    });

    test('watchAll emits ordered list', () async {
      await categories.create(name: 'Zeta');
      await categories.create(name: 'Alpha');
      final all = await categories.getAll();
      expect(all.map((c) => c.name).toList(), ['Alpha', 'Zeta']);
    });
  });

  group('suppliers', () {
    test('create, update, delete', () async {
      final created = await suppliers.create(
        name: 'PharmaCo',
        contactPerson: 'John Doe',
        phone: '123456',
        email: 'john@pharmaco.test',
      );
      expect(created.contactPerson, 'John Doe');

      await suppliers.update(
        created.id,
        name: 'PharmaCo Ltd',
        contactPerson: 'Jane Doe',
        phone: '654321',
        email: 'jane@pharmaco.test',
        address: 'New St',
      );
      final updated = await suppliers.findById(created.id);
      expect(updated!.name, 'PharmaCo Ltd');
      expect(updated.contactPerson, 'Jane Doe');
      expect(updated.phone, '654321');

      await suppliers.delete(created.id);
      expect(await suppliers.findById(created.id), isNull);
    });
  });

  group('products', () {
    test('create with unique SKU and barcode', () async {
      final p = await products.create(
        sku: 'SKU-001',
        name: 'Paracetamol 500mg',
        barcode: '6291001001234',
        costPrice: 1000,
        sellingPrice: 2500,
        stockQuantity: 50,
        lowStockThreshold: 10,
      );
      expect(p.sku, 'SKU-001');
      expect(p.sellingPrice, 2500);
      expect(p.isLowStock, isFalse);

      expect(await products.findBySku('sku-001'), isNotNull);
      expect(await products.findByBarcode('6291001001234'), isNotNull);
    });

    test('SKU and barcode uniqueness', () async {
      await products.create(sku: 'S1', name: 'A', barcode: 'B1');
      expect(await products.isSkuTaken('s1'), isTrue);
      expect(await products.isSkuTaken('S2'), isFalse);
      expect(await products.isBarcodeTaken('B1'), isTrue);
      expect(await products.isBarcodeTaken(''), isFalse);
    });

    test('search matches name, SKU, and barcode', () async {
      await products.create(sku: 'SKU-A', name: 'Vitamin C', barcode: 'BC-A');
      await products.create(sku: 'SKU-B', name: 'Vitamin D', barcode: 'BC-B');

      expect((await products.search('vitamin')).length, 2);
      expect((await products.search('sku-a')).length, 1);
      expect((await products.search('BC-B')).length, 1);
      expect(
        (await products.search('')).length,
        (await products.getAll()).length,
      );
    });

    test('low stock detection', () async {
      await products.create(
        sku: 'L1',
        name: 'Low item',
        stockQuantity: 3,
        lowStockThreshold: 5,
      );
      await products.create(
        sku: 'OK',
        name: 'OK item',
        stockQuantity: 50,
        lowStockThreshold: 5,
      );

      expect(await products.countLowStock(), 1);
      final low = await products.watchLowStock().first;
      expect(low.single.sku, 'L1');
      expect(low.single.isLowStock, isTrue);
    });

    test('delete removes product', () async {
      final p = await products.create(sku: 'DEL', name: 'Delete me');
      await products.delete(p.id);
      expect(await products.findById(p.id), isNull);
    });
  });

  group('stock adjustments', () {
    test('adjustStock updates stock and records adjustment', () async {
      final p = await products.create(
        sku: 'ST',
        name: 'Stock item',
        stockQuantity: 10,
      );

      await stockAdjustments.adjustStock(
        productId: p.id,
        adjustmentQuantity: -4,
        reason: 'damaged',
      );

      final updated = await products.findById(p.id);
      expect(updated!.stockQuantity, 6);

      final history = await stockAdjustments.watchForProduct(p.id).first;
      expect(history.single.adjustmentQuantity, -4);
      expect(history.single.reason, 'damaged');
      expect(history.single.reference, 'manual');
    });

    test('zero adjustment is a no-op', () async {
      final p = await products.create(sku: 'Z', name: 'Zero', stockQuantity: 5);
      await stockAdjustments.adjustStock(productId: p.id, adjustmentQuantity: 0);
      expect((await products.findById(p.id))!.stockQuantity, 5);
      expect(await stockAdjustments.getAll(), isEmpty);
    });
  });

  group('settings', () {
    test('store settings round trip', () async {
      final defaults = await settings.getStoreSettings();
      expect(defaults.currencySymbol, 'ج.س');
      expect(defaults.taxRate, '0');

      await settings.saveStoreSettings(
        const StoreSettings(
          storeName: 'My Pharmacy',
          storeAddress: 'Main Street 1',
          storePhone: '012345',
          storeTaxId: 'TAX-1',
          taxRate: '7.5',
          currencySymbol: 'ج.س',
        ),
      );

      final loaded = await settings.getStoreSettings();
      expect(loaded.storeName, 'My Pharmacy');
      expect(loaded.taxRate, '7.5');
      expect(await settings.getCurrencySymbol(), 'ج.س');
    });
  });
}
