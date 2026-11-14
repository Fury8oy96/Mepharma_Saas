import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mepharma/src/app/providers.dart';
import 'package:mepharma/src/core/services/backup_service.dart';
import 'package:mepharma/src/data/db/app_database.dart';
import 'package:mepharma/src/data/db/enums.dart';
import 'package:mepharma/src/data/repositories/sqlite_auth_repository.dart';
import 'package:mepharma/src/data/repositories/sqlite_category_repository.dart';
import 'package:mepharma/src/data/repositories/sqlite_customer_repository.dart';
import 'package:mepharma/src/data/repositories/sqlite_product_repository.dart';
import 'package:mepharma/src/data/repositories/sqlite_purchase_repository.dart';
import 'package:mepharma/src/data/repositories/sqlite_report_repository.dart';
import 'package:mepharma/src/data/repositories/sqlite_return_repository.dart';
import 'package:mepharma/src/data/repositories/sqlite_sale_repository.dart';
import 'package:mepharma/src/data/repositories/sqlite_sales_hold_repository.dart';
import 'package:mepharma/src/data/repositories/sqlite_settings_repository.dart';
import 'package:mepharma/src/data/repositories/sqlite_stock_adjustment_repository.dart';
import 'package:mepharma/src/data/repositories/sqlite_supplier_repository.dart';
import 'package:mepharma/src/data/repositories/sqlite_user_repository.dart';
import 'package:mepharma/src/domain/models/sale_receipt.dart';
import 'package:mepharma/src/domain/repositories/purchase_repository.dart';
import 'package:mepharma/src/domain/repositories/return_repository.dart';
import 'package:mepharma/src/l10n/generated/app_localizations.dart';
import 'package:mepharma/src/presentation/session/session_controller.dart';
import 'package:mepharma/src/presentation/users/users_page.dart';
import 'package:path/path.dart' as p;

void main() {
  group('users', () {
    late ProviderContainer container;
    late AppDatabase db;
    late SqliteUserRepository users;
    late SqliteAuthRepository auth;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        userRepositoryProvider.overrideWith((ref) => SqliteUserRepository(db)),
        authRepositoryProvider.overrideWith((ref) => SqliteAuthRepository(db)),
        settingsRepositoryProvider.overrideWith((ref) => SqliteSettingsRepository(db)),
        categoryRepositoryProvider.overrideWith((ref) => SqliteCategoryRepository(db)),
        supplierRepositoryProvider.overrideWith((ref) => SqliteSupplierRepository(db)),
        productRepositoryProvider.overrideWith((ref) => SqliteProductRepository(db)),
        customerRepositoryProvider.overrideWith((ref) => SqliteCustomerRepository(db)),
        stockAdjustmentRepositoryProvider.overrideWith((ref) => SqliteStockAdjustmentRepository(db)),
        saleRepositoryProvider.overrideWith((ref) => SqliteSaleRepository(db)),
        salesHoldRepositoryProvider.overrideWith((ref) => SqliteSalesHoldRepository(db)),
        returnRepositoryProvider.overrideWith((ref) => SqliteReturnRepository(db)),
        purchaseRepositoryProvider.overrideWith((ref) => SqlitePurchaseRepository(db)),
        reportRepositoryProvider.overrideWith((ref) => SqliteReportRepository(db)),
      ]);
      users = container.read(userRepositoryProvider) as SqliteUserRepository;
      auth = container.read(authRepositoryProvider) as SqliteAuthRepository;
    });

    tearDown(() {
      container.dispose();
      db.close();
    });

    test('watchUsers orders admins before staff', () async {
      await users.createUser(
        username: 'bob',
        password: 'secret',
        role: UserRole.staff,
      );
      await users.createUser(
        username: 'alice',
        password: 'secret',
        role: UserRole.admin,
      );

      final all = await users.watchUsers().first;
      expect(all.map((u) => u.username).toList(), ['alice', 'bob']);
    });

    test('updateUser resets password, changes role and toggles active',
        () async {
      final created = await users.createUser(
        username: 'carol',
        password: 'oldpass',
        role: UserRole.staff,
      );

      await users.updateUser(created.id, role: UserRole.admin);
      final admin = await users.findById(created.id);
      expect(admin!.isAdmin, isTrue);

      await users.updateUser(created.id, isActive: false);
      expect((await users.findById(created.id))!.isActive, isFalse);

      await users.updateUser(created.id, isActive: true);
      expect((await users.findById(created.id))!.isActive, isTrue);

      await users.updateUser(created.id, password: 'newpass');
      expect(
        await auth.login(username: 'carol', password: 'oldpass'),
        isNull,
      );
      final loggedIn =
          await auth.login(username: 'carol', password: 'newpass');
      expect(loggedIn!.isActive, isTrue);
    });

    testWidgets('self account cannot be deactivated in the UI', (tester) async {
      late ProviderContainer widgetContainer;
      late AppDatabase widgetDb;
      await tester.runAsync(() async {
        widgetDb = AppDatabase(NativeDatabase.memory());
        widgetContainer = ProviderContainer(overrides: [
          databaseProvider.overrideWithValue(widgetDb),
          userRepositoryProvider.overrideWith((ref) => SqliteUserRepository(widgetDb)),
          authRepositoryProvider.overrideWith((ref) => SqliteAuthRepository(widgetDb)),
          settingsRepositoryProvider.overrideWith((ref) => SqliteSettingsRepository(widgetDb)),
          categoryRepositoryProvider.overrideWith((ref) => SqliteCategoryRepository(widgetDb)),
          supplierRepositoryProvider.overrideWith((ref) => SqliteSupplierRepository(widgetDb)),
          productRepositoryProvider.overrideWith((ref) => SqliteProductRepository(widgetDb)),
          customerRepositoryProvider.overrideWith((ref) => SqliteCustomerRepository(widgetDb)),
          stockAdjustmentRepositoryProvider.overrideWith((ref) => SqliteStockAdjustmentRepository(widgetDb)),
          saleRepositoryProvider.overrideWith((ref) => SqliteSaleRepository(widgetDb)),
          salesHoldRepositoryProvider.overrideWith((ref) => SqliteSalesHoldRepository(widgetDb)),
          returnRepositoryProvider.overrideWith((ref) => SqliteReturnRepository(widgetDb)),
          purchaseRepositoryProvider.overrideWith((ref) => SqlitePurchaseRepository(widgetDb)),
          reportRepositoryProvider.overrideWith((ref) => SqliteReportRepository(widgetDb)),
        ]);
        final userRepo = widgetContainer.read(userRepositoryProvider);
        await userRepo.createUser(
          username: 'boss',
          password: 'secret',
          role: UserRole.admin,
        );
        await userRepo.createUser(
          username: 'cashier',
          password: 'secret',
          role: UserRole.staff,
        );
        final boss = await userRepo.findByUsername('boss');
        widgetContainer.read(sessionProvider.notifier).state = boss;
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: widgetContainer,
          child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const UsersPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final adminTile = find.widgetWithText(ListTile, 'boss');
      final adminSwitch = tester.widget<Switch>(
        find.descendant(
          of: adminTile,
          matching: find.byType(Switch),
        ),
      );
      expect(adminSwitch.onChanged, isNull);

      final staffTile = find.widgetWithText(ListTile, 'cashier');
      final staffSwitch = tester.widget<Switch>(
        find.descendant(
          of: staffTile,
          matching: find.byType(Switch),
        ),
      );
      expect(staffSwitch.onChanged, isNotNull);

      // The container is intentionally left undisposed: disposing it cancels
      // the drift watch stream, which leaves a pending zero-duration timer in
      // the fake async zone and fails the test.
      await tester.runAsync(() => widgetDb.close());
    });
  });

  group('reports', () {
    late ProviderContainer container;
    late AppDatabase db;
    late SqliteProductRepository products;
    late SqliteSaleRepository sales;
    late SqliteReturnRepository returns;
    late SqliteSupplierRepository suppliers;
    late SqlitePurchaseRepository purchases;
    late int userId;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        userRepositoryProvider.overrideWith((ref) => SqliteUserRepository(db)),
        authRepositoryProvider.overrideWith((ref) => SqliteAuthRepository(db)),
        settingsRepositoryProvider.overrideWith((ref) => SqliteSettingsRepository(db)),
        categoryRepositoryProvider.overrideWith((ref) => SqliteCategoryRepository(db)),
        supplierRepositoryProvider.overrideWith((ref) => SqliteSupplierRepository(db)),
        productRepositoryProvider.overrideWith((ref) => SqliteProductRepository(db)),
        customerRepositoryProvider.overrideWith((ref) => SqliteCustomerRepository(db)),
        stockAdjustmentRepositoryProvider.overrideWith((ref) => SqliteStockAdjustmentRepository(db)),
        saleRepositoryProvider.overrideWith((ref) => SqliteSaleRepository(db)),
        salesHoldRepositoryProvider.overrideWith((ref) => SqliteSalesHoldRepository(db)),
        returnRepositoryProvider.overrideWith((ref) => SqliteReturnRepository(db)),
        purchaseRepositoryProvider.overrideWith((ref) => SqlitePurchaseRepository(db)),
        reportRepositoryProvider.overrideWith((ref) => SqliteReportRepository(db)),
      ]);
      products =
          container.read(productRepositoryProvider) as SqliteProductRepository;
      sales = container.read(saleRepositoryProvider) as SqliteSaleRepository;
      returns =
          container.read(returnRepositoryProvider) as SqliteReturnRepository;
      purchases =
          container.read(purchaseRepositoryProvider) as SqlitePurchaseRepository;
      suppliers =
          container.read(supplierRepositoryProvider) as SqliteSupplierRepository;
      userId = (await (container.read(userRepositoryProvider) as SqliteUserRepository)
              .createUser(
        username: 'cashier',
        password: 'secret',
        role: UserRole.staff,
      ))
          .id;
    });

    tearDown(() {
      container.dispose();
      db.close();
    });

    Future<int> sell({
      required int productId,
      required String name,
      required int quantity,
      required int unitPrice,
      required String paymentMethod,
    }) async {
      final receipt = await sales.completeSale(
        items: [
          SaleLineItem(
            productId: productId,
            productName: name,
            quantity: quantity,
            unitPrice: unitPrice,
            totalPrice: quantity * unitPrice,
          ),
        ],
        subtotal: quantity * unitPrice,
        discount: 0,
        taxAmount: 0,
        totalAmount: quantity * unitPrice,
        paidAmount: quantity * unitPrice,
        changeAmount: 0,
        paymentMethod: paymentMethod,
        userId: userId,
      );
      return receipt.id;
    }

    test('getSummary aggregates the current day', () async {
      final paracetamol = await products.create(
        sku: 'A1',
        name: 'Paracetamol',
        costPrice: 1000,
        sellingPrice: 2500,
        stockQuantity: 50,
      );
      final aspirin = await products.create(
        sku: 'A2',
        name: 'Aspirin',
        costPrice: 1000,
        sellingPrice: 1000,
        stockQuantity: 50,
      );
      await products.create(
        sku: 'A3',
        name: 'Vitamin C',
        costPrice: 300,
        sellingPrice: 900,
        stockQuantity: 0,
      );

      final cashSale = await sell(
        productId: paracetamol.id,
        name: paracetamol.name,
        quantity: 2,
        unitPrice: 2500,
        paymentMethod: 'cash',
      );
      await sell(
        productId: aspirin.id,
        name: aspirin.name,
        quantity: 1,
        unitPrice: 1000,
        paymentMethod: 'card',
      );

      final cashDetail = await sales.getSaleDetail(cashSale);
      final cashItem = cashDetail.items.single;
      await returns.createReturn(
        saleId: cashSale,
        userId: userId,
        reason: 'damaged',
        items: [
          ReturnLineInput(
            saleItemId: cashItem.id,
            productId: paracetamol.id,
            productName: paracetamol.name,
            unitPrice: 2500,
            quantity: 1,
          ),
        ],
      );

      final supplier = await suppliers.create(name: 'MedSupply');
      await purchases.createPurchase(
        userId: userId,
        supplierId: supplier.id,
        purchaseDate: DateTime.now(),
        items: [
          PurchaseLineInput(
            productId: aspirin.id,
            productName: aspirin.name,
            quantity: 5,
            costPrice: 800,
          ),
        ],
      );

      final now = DateTime.now();
      final report = container.read(reportRepositoryProvider) as SqliteReportRepository;
      final summary = await report.getSummary(
        from: DateTime(now.year, now.month, now.day),
        to: DateTime(now.year, now.month, now.day, 23, 59, 59),
      );

      expect(summary.salesCount, 2);
      expect(summary.revenue, 6000);
      expect(summary.refunds, 2500);
      expect(summary.netRevenue, 3500);
      expect(summary.purchasesCost, 4000);
      // The purchase bumped Aspirin's cost to 800, so COGS = 2*1000 + 1*800.
      expect(summary.costOfGoods, 2800);
      expect(summary.estimatedProfit, 3200);
      expect(summary.lowStockCount, 1);

      expect(summary.salesByPayment.length, 2);
      final cash = summary.salesByPayment
          .singleWhere((b) => b.method == 'cash');
      expect(cash.count, 1);
      expect(cash.total, 5000);

      expect(summary.topProducts.length, 2);
      expect(summary.topProducts.first.name, 'Paracetamol');
      expect(summary.topProducts.first.quantity, 2);
      expect(summary.topProducts.first.revenue, 5000);
    });
  });

  group('backup', () {
    late Directory temp;
    late AppDatabase db;
    late File liveFile;
    late Directory backupsDir;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('mepharma_backup_test');
      liveFile = File(p.join(temp.path, 'live.sqlite'));
      backupsDir = Directory(p.join(temp.path, 'backups'));
    });

    tearDown(() async {
      try {
        await temp.delete(recursive: true);
      } catch (_) {}
    });

    BackupService serviceFor(AppDatabase database, File live) {
      return BackupService(
        database,
        paths: BackupPaths(
          backupsDirectory: () async => backupsDir,
          liveDatabaseFile: () async => live,
        ),
      );
    }

    test('createBackup copies a valid database and logs success', () async {
      db = AppDatabase(NativeDatabase(liveFile));
      final users = SqliteUserRepository(db);
      await users.createUser(
        username: 'u1',
        password: 'secret',
        role: UserRole.admin,
      );

      final service = serviceFor(db, liveFile);
      final record = await service.createBackup();

      expect(record.status, BackupStatus.success);
      final file = File(record.filePath!);
      expect(await file.exists(), isTrue);
      final bytes = await file.readAsBytes();
      expect(
        String.fromCharCodes(bytes.sublist(0, 16)),
        'SQLite format 3\x00',
      );

      final history = await service.watchLogs().first;
      expect(history.single.id, record.id);
      expect(history.single.filePath, record.filePath);

      final readBack = await service.readBackupBytes(record.id);
      expect(readBack, bytes);

      await service.deleteBackup(record.id);
      expect(await file.exists(), isFalse);
      expect(await service.watchLogs().first, isEmpty);

      await db.close();
      await service.replaceLiveDatabase(bytes);
      final reopened = AppDatabase(NativeDatabase(liveFile));
      final reopenedUsers = SqliteUserRepository(reopened);
      expect(await reopenedUsers.hasAnyUsers(), isTrue);
      expect(
        (await reopenedUsers.findByUsername('u1'))?.isAdmin,
        isTrue,
      );
      await reopened.close();
    });

    test('createBackup logs failure when the database file is missing',
        () async {
      db = AppDatabase(NativeDatabase.memory());
      final missing = File(p.join(temp.path, 'missing.sqlite'));
      final service = serviceFor(db, missing);

      await expectLater(
        service.createBackup(),
        throwsA(isA<StateError>()),
      );

      final history = await service.watchLogs().first;
      expect(history.single.status, BackupStatus.failed);
    });
  });
}
