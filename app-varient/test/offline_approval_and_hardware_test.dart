import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mepharma/src/core/constants/app_constants.dart';
import 'package:mepharma/src/data/db/app_database.dart';
import 'package:mepharma/src/data/repositories/sqlite_auth_repository.dart';
import 'package:mepharma/src/data/repositories/sqlite_product_repository.dart';
import 'package:mepharma/src/data/repositories/sqlite_purchase_repository.dart';
import 'package:mepharma/src/data/repositories/sqlite_supplier_repository.dart';
import 'package:mepharma/src/data/repositories/sqlite_user_repository.dart';
import 'package:mepharma/src/domain/models/app_purchase.dart';
import 'package:mepharma/src/domain/repositories/purchase_repository.dart';

void main() {
  group('Offline Procurement Dual-Approval & Database Reset', () {
    late AppDatabase db;
    late SqliteProductRepository products;
    late SqliteSupplierRepository suppliers;
    late SqlitePurchaseRepository purchases;
    late SqliteUserRepository users;
    late SqliteAuthRepository auth;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      products = SqliteProductRepository(db);
      suppliers = SqliteSupplierRepository(db);
      purchases = SqlitePurchaseRepository(db);
      users = SqliteUserRepository(db);
      auth = SqliteAuthRepository(db);
      await users.ensureDefaultAdmin();
    });

    tearDown(() => db.close());

    test('createPurchase with autoApprove=false creates pending PO without changing stock', () async {
      final supplier = await suppliers.create(name: 'PharmaDist');
      final product = await products.create(
        sku: 'MED-AUG-001',
        name: 'Augmentin 1g',
        barcode: '622000000002',
        costPrice: 2000,
        sellingPrice: 3500,
        stockQuantity: 10,
      );

      final admin = (await users.watchUsers().first).first;

      // 1. Staff creates purchase order with autoApprove=false
      final po = await purchases.createPurchase(
        userId: admin.id,
        supplierId: supplier.id,
        purchaseDate: DateTime.now(),
        autoApprove: false,
        items: [
          PurchaseLineInput(
            productId: product.id,
            productName: product.name,
            quantity: 15,
            costPrice: 2100,
          ),
        ],
      );

      // Verify status is pending
      expect(po.status, equals(PurchaseStatus.pending));
      expect(po.isPending, isTrue);
      expect(po.isApproved, isFalse);

      // Verify stock in inventory is STILL 10 (unchanged)
      final unapprovedProduct = (await products.findById(product.id))!;
      expect(unapprovedProduct.stockQuantity, equals(10));
      expect(unapprovedProduct.costPrice, equals(2000));

      // 2. Branch Manager or Admin approves the purchase order
      await purchases.approvePurchase(po.id);

      // Verify purchase order is now marked approved
      final detail = await purchases.getPurchaseDetail(po.id);
      expect(detail.purchase.status, equals(PurchaseStatus.approved));
      expect(detail.purchase.isApproved, isTrue);

      // Verify inventory stock is now atomically incremented (10 + 15 = 25)
      final approvedProduct = (await products.findById(product.id))!;
      expect(approvedProduct.stockQuantity, equals(25));
      expect(approvedProduct.costPrice, equals(2100));
      // In variant open pricing, user's custom selling price (3500) is preserved
      expect(approvedProduct.sellingPrice, equals(3500));
    });

    test('approvePurchase auto-creates unlisted product and applies governed margin pricing', () async {
      final supplier = await suppliers.create(name: 'Global Supply');
      final admin = (await users.watchUsers().first).first;

      final po = await purchases.createPurchase(
        userId: admin.id,
        supplierId: supplier.id,
        purchaseDate: DateTime.now(),
        autoApprove: false,
        items: [
          const PurchaseLineInput(
            productId: null,
            productName: 'Cataflam 50mg',
            quantity: 30,
            costPrice: 1000,
          ),
        ],
      );

      // Verify not yet in product catalog
      final beforeApproval = (await products.getAll()).where((p) => p.name == 'Cataflam 50mg');
      expect(beforeApproval.isEmpty, isTrue);

      // Approve purchase
      await purchases.approvePurchase(po.id);

      // Verify product is now auto-created with stock and governed price (1000 + 300 = 1300)
      final afterApproval = (await products.getAll()).where((p) => p.name == 'Cataflam 50mg').firstOrNull;
      expect(afterApproval, isNotNull);
      expect(afterApproval!.stockQuantity, equals(30));
      expect(afterApproval.costPrice, equals(1000));
      expect(afterApproval.sellingPrice, equals(1300));
    });

    test('wipeAndReset purges all operational data and restores clean default admin', () async {
      // Seed some data
      await suppliers.create(name: 'Supplier ABC');
      await products.create(
        sku: 'MED-PAN-001',
        name: 'Panadol Extra',
        barcode: '622000000099',
        costPrice: 500,
        sellingPrice: 1200,
        stockQuantity: 50,
      );

      expect((await products.getAll()).length, equals(1));
      expect((await suppliers.getAll()).length, equals(1));

      // Wipe and reset
      await db.wipeAndReset();
      await users.ensureDefaultAdmin();

      // Check operational tables are completely empty
      expect((await products.getAll()).length, equals(0));
      expect((await suppliers.getAll()).length, equals(0));
      expect((await purchases.watchPurchases().first).length, equals(0));

      // Check default admin is restored and can authenticate
      final adminUser = await auth.login(
        username: AppConstants.defaultAdminUsername,
        password: AppConstants.defaultAdminPassword,
      );
      expect(adminUser, isNotNull);
      expect(adminUser!.username, equals('admin'));
    });

    test('Barcode scanner resolution by barcode and SKU', () async {
      final p = await products.create(
        sku: 'AMOX-500',
        name: 'Amoxicillin 500mg',
        barcode: '8901234567890',
        costPrice: 800,
        sellingPrice: 1500,
        stockQuantity: 40,
      );

      // By exact barcode
      final foundByBarcode = await products.findByBarcode('8901234567890');
      expect(foundByBarcode, isNotNull);
      expect(foundByBarcode!.id, equals(p.id));

      // By exact SKU
      final foundBySku = await products.findBySku('amox-500');
      expect(foundBySku, isNotNull);
      expect(foundBySku!.id, equals(p.id));
    });
  });
}
