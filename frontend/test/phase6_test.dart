import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mepharma/src/app/providers.dart';
import 'package:mepharma/src/core/services/product_csv_service.dart';
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
import 'package:mepharma/src/domain/models/payment_method.dart';
import 'package:mepharma/src/domain/models/sale_receipt.dart';
import 'package:mepharma/src/domain/models/store_settings.dart';
import 'package:mepharma/src/domain/repositories/category_repository.dart';
import 'package:mepharma/src/presentation/pos/pos_controller.dart';

void main() {
  late ProviderContainer container;
  late AppDatabase db;
  late SqliteProductRepository products;
  late SqliteSaleRepository sales;
  late SqliteCustomerRepository customers;
  late int userId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
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
      ],
    );
    products =
        container.read(productRepositoryProvider) as SqliteProductRepository;
    sales = container.read(saleRepositoryProvider) as SqliteSaleRepository;
    customers =
        container.read(customerRepositoryProvider) as SqliteCustomerRepository;
    userId =
        (await (container.read(userRepositoryProvider) as SqliteUserRepository)
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

  Future<void> sell({
    required int productId,
    required String name,
    required int quantity,
    required int unitPrice,
    required String paymentMethod,
    int? customerId,
    String? customerName,
    required int paidAmount,
  }) async {
    final total = quantity * unitPrice;
    await sales.completeSale(
      items: [
        SaleLineItem(
          productId: productId,
          productName: name,
          quantity: quantity,
          unitPrice: unitPrice,
          totalPrice: total,
        ),
      ],
      subtotal: total,
      discount: 0,
      taxAmount: 0,
      totalAmount: total,
      paidAmount: paidAmount,
      changeAmount: 0,
      paymentMethod: paymentMethod,
      userId: userId,
      customerName: customerName,
      customerId: customerId,
    );
  }

  group('customers', () {
    test(
      'watchAll returns customers ordered by name with zero balances',
      () async {
        await customers.create(name: 'Zed', creditLimit: 10000);
        await customers.create(name: 'Anna');

        final all = await customers.watchAll().first;
        expect(all.map((e) => e.customer.name).toList(), ['Anna', 'Zed']);
        expect(all.every((e) => e.outstanding == 0), isTrue);
        expect(all.last.totalCredit, 0);
        expect(all.last.customer.creditLimit, 10000);
      },
    );

    test(
      'credit sale charges the account and a payment reduces the balance',
      () async {
        final customer = await customers.create(name: 'Credit Co.');
        final p = await products.create(
          sku: 'CC1',
          name: 'Item',
          costPrice: 1000,
          sellingPrice: 2500,
          stockQuantity: 10,
        );

        await sell(
          productId: p.id,
          name: p.name,
          quantity: 2,
          unitPrice: 2500,
          paymentMethod: 'credit',
          customerId: customer.id,
          customerName: customer.name,
          paidAmount: 0,
        );

        expect(await customers.getBalance(customer.id), 5000);
        final row = await (db.select(
          db.sales,
        )..where((s) => s.id.isNotNull())).getSingle();
        expect(row.customerId, customer.id);
        expect(row.paymentMethod, 'credit');
        expect(row.paidAmount, 0);

        await customers.recordPayment(
          customerId: customer.id,
          amount: 3000,
          userId: userId,
          note: 'partial',
        );
        expect(await customers.getBalance(customer.id), 2000);

        final watch = await customers.watchAll().first;
        final entry = watch.singleWhere((e) => e.customer.id == customer.id);
        expect(entry.totalCredit, 5000);
        expect(entry.totalPaid, 3000);
        expect(entry.outstanding, 2000);

        final payments = await customers.watchPayments(customer.id).first;
        expect(payments.single.amount, 3000);
        expect(payments.single.note, 'partial');
      },
    );

    test('delete unlinks sales and cascades payments', () async {
      final customer = await customers.create(name: 'To Delete');
      final p = await products.create(
        sku: 'DL1',
        name: 'Item',
        sellingPrice: 1000,
        stockQuantity: 10,
      );
      await sell(
        productId: p.id,
        name: p.name,
        quantity: 1,
        unitPrice: 1000,
        paymentMethod: 'credit',
        customerId: customer.id,
        customerName: customer.name,
        paidAmount: 0,
      );
      await customers.recordPayment(customerId: customer.id, amount: 500);

      await customers.delete(customer.id);

      expect(await customers.findById(customer.id), isNull);
      expect(await customers.watchPayments(customer.id).first, isEmpty);
      final saleRow = await (db.select(db.sales)).getSingle();
      expect(saleRow.customerId, isNull);
      expect(saleRow.customerName, customer.name);
    });

    test('isNameTaken is case-insensitive', () async {
      await customers.create(name: 'Pharmacy One');
      expect(await customers.isNameTaken('PHARMACY ONE'), isTrue);
      expect(await customers.isNameTaken('Other'), isFalse);
    });

    test('isNameTaken excludes the customer being edited', () async {
      final customer = await customers.create(name: 'Self');
      expect(
        await customers.isNameTaken('Self', excludeId: customer.id),
        isFalse,
      );
    });

    test('isOverLimit flags customers above their credit limit', () async {
      final entry = await customers.create(name: 'Over', creditLimit: 10000);
      final p = await products.create(
        sku: 'OL1',
        name: 'Item',
        sellingPrice: 15000,
        stockQuantity: 10,
      );
      await sell(
        productId: p.id,
        name: p.name,
        quantity: 1,
        unitPrice: 15000,
        paymentMethod: 'credit',
        customerId: entry.id,
        customerName: entry.name,
        paidAmount: 0,
      );

      final watch = await customers.watchAll().first;
      final over = watch.singleWhere((e) => e.customer.id == entry.id);
      expect(over.outstanding, 15000);
      expect(over.isOverLimit, isTrue);
      expect(over.customer.creditLimit, 10000);

      final unlimited = await customers.create(name: 'No Limit');
      final watch2 = await customers.watchAll().first;
      final noLimit = watch2.singleWhere((e) => e.customer.id == unlimited.id);
      expect(noLimit.isOverLimit, isFalse);
    });
  });

  group('pos credit', () {
    test('credit sale without a customer is rejected', () async {
      final p = await products.create(
        sku: 'CR1',
        name: 'Item',
        sellingPrice: 1000,
        stockQuantity: 10,
      );
      final notifier = container.read(posControllerProvider.notifier);
      notifier.addProduct(p);

      expect(
        () => notifier.completeSale(
          method: PaymentMethod.credit,
          receivedCents: 0,
          taxRatePercent: 0,
          userId: userId,
        ),
        throwsA(isA<PosSaleException>()),
      );
      expect(container.read(posControllerProvider).isEmpty, isFalse);
    });

    test(
      'credit sale is rejected when the balance plus total exceeds the limit',
      () async {
        final customer = await customers.create(
          name: 'Limited',
          creditLimit: 3000,
        );
        final p = await products.create(
          sku: 'CR3',
          name: 'Item',
          sellingPrice: 2000,
          stockQuantity: 10,
        );
        // Existing balance of 2000, new sale of 2000 -> 4000 > 3000 limit.
        await sell(
          productId: p.id,
          name: p.name,
          quantity: 1,
          unitPrice: 2000,
          paymentMethod: 'credit',
          customerId: customer.id,
          customerName: customer.name,
          paidAmount: 0,
        );
        expect(await customers.getBalance(customer.id), 2000);

        final notifier = container.read(posControllerProvider.notifier);
        notifier.addProduct(p);
        notifier.setCustomer(customer.id);

        await expectLater(
          notifier.completeSale(
            method: PaymentMethod.credit,
            receivedCents: 0,
            taxRatePercent: 0,
            userId: userId,
          ),
          throwsA(
            isA<PosSaleException>().having(
              (e) => e.code,
              'code',
              PosError.creditLimitExceeded,
            ),
          ),
        );
        expect(await customers.getBalance(customer.id), 2000);
        expect(container.read(posControllerProvider).isEmpty, isFalse);
      },
    );

    test('credit sale is allowed up to the credit limit', () async {
      final customer = await customers.create(
        name: 'Exactly',
        creditLimit: 4000,
      );
      final p = await products.create(
        sku: 'CR4',
        name: 'Item',
        sellingPrice: 2000,
        stockQuantity: 10,
      );
      await sell(
        productId: p.id,
        name: p.name,
        quantity: 1,
        unitPrice: 2000,
        paymentMethod: 'credit',
        customerId: customer.id,
        customerName: customer.name,
        paidAmount: 0,
      );
      final notifier = container.read(posControllerProvider.notifier);
      notifier.addProduct(p);
      notifier.setCustomer(customer.id);

      final receipt = await notifier.completeSale(
        method: PaymentMethod.credit,
        receivedCents: 0,
        taxRatePercent: 0,
        userId: userId,
      );
      expect(receipt.totalAmount, 2000);
      expect(await customers.getBalance(customer.id), 4000);
    });

    test('credit sale with no limit is always allowed', () async {
      final customer = await customers.create(name: 'Unlimited');
      final p = await products.create(
        sku: 'CR5',
        name: 'Item',
        sellingPrice: 5000,
        stockQuantity: 10,
      );
      await sell(
        productId: p.id,
        name: p.name,
        quantity: 1,
        unitPrice: 5000,
        paymentMethod: 'credit',
        customerId: customer.id,
        customerName: customer.name,
        paidAmount: 0,
      );
      final notifier = container.read(posControllerProvider.notifier);
      notifier.addProduct(p);
      notifier.setCustomer(customer.id);

      final receipt = await notifier.completeSale(
        method: PaymentMethod.credit,
        receivedCents: 0,
        taxRatePercent: 0,
        userId: userId,
      );
      expect(receipt.totalAmount, 5000);
      expect(await customers.getBalance(customer.id), 10000);
    });

    test('credit sale stores the customer and zero paid', () async {
      final customer = await customers.create(name: 'On Account');
      final p = await products.create(
        sku: 'CR2',
        name: 'Item',
        sellingPrice: 2000,
        stockQuantity: 10,
      );
      final notifier = container.read(posControllerProvider.notifier);
      notifier.addProduct(p);
      notifier.setCustomer(customer.id);

      final receipt = await notifier.completeSale(
        method: PaymentMethod.credit,
        receivedCents: 0,
        taxRatePercent: 0,
        userId: userId,
      );
      expect(receipt.paymentMethod, 'credit');
      expect(receipt.paidAmount, 0);
      expect(receipt.totalAmount, 2000);
      expect(receipt.customerId, customer.id);
      expect(receipt.customerName, customer.name);
      expect(await customers.getBalance(customer.id), 2000);
      expect(container.read(posControllerProvider).isEmpty, isTrue);
    });
  });

  group('expiry', () {
    final now = DateTime.now();

    test(
      'watchExpiring returns expired and soon products oldest first',
      () async {
        final expired = await products.create(
          sku: 'EX1',
          name: 'Expired',
          sellingPrice: 100,
          stockQuantity: 1,
          expiryDate: now.subtract(const Duration(days: 3)),
        );
        final soon = await products.create(
          sku: 'EX2',
          name: 'Soon',
          sellingPrice: 100,
          stockQuantity: 1,
          expiryDate: now.add(const Duration(days: 20)),
        );
        final far = await products.create(
          sku: 'EX3',
          name: 'Far',
          sellingPrice: 100,
          stockQuantity: 1,
          expiryDate: now.add(const Duration(days: 120)),
        );
        await products.create(
          sku: 'EX4',
          name: 'No Expiry',
          sellingPrice: 100,
          stockQuantity: 1,
        );

        final expiring = await products.watchExpiring(withinDays: 30).first;
        expect(expiring.map((p) => p.sku).toList(), ['EX1', 'EX2']);
        expect(expiring.any((p) => p.id == far.id), isFalse);

        expect(expired.isExpired, isTrue);
        expect(soon.isExpired, isFalse);
        expect(soon.isExpiringWithin(30), isTrue);
        expect(far.isExpiringWithin(30), isFalse);
        expect(soon.daysUntilExpiry, lessThanOrEqualTo(30));
      },
    );
  });

  group('reports depth', () {
    test('getMonthlySummary buckets the current month', () async {
      final p = await products.create(
        sku: 'M1',
        name: 'Item',
        sellingPrice: 1000,
        stockQuantity: 10,
      );
      await sell(
        productId: p.id,
        name: p.name,
        quantity: 2,
        unitPrice: 1000,
        paymentMethod: 'cash',
        paidAmount: 2000,
      );

      final report =
          container.read(reportRepositoryProvider) as SqliteReportRepository;
      final months = await report.getMonthlySummary(months: 3);

      expect(months.length, 3);
      final current = DateTime.now();
      final currentKey = '${current.year}-${current.month}';
      final bucket = months.singleWhere((m) => m.key == currentKey);
      expect(bucket.salesCount, 1);
      expect(bucket.revenue, 2000);
      expect(bucket.refunds, 0);
      expect(bucket.netRevenue, 2000);
    });

    test('getCategorySummary computes revenue, cost and profit', () async {
      final CategoryRepository categoriesRepo = container.read(
        categoryRepositoryProvider,
      );
      final category = await categoriesRepo.create(name: 'Analgesics');
      final generic = await categoriesRepo.create(name: 'Generic');

      final paracetamol = await products.create(
        sku: 'G1',
        name: 'Paracetamol',
        categoryId: category.id,
        costPrice: 1000,
        sellingPrice: 2500,
        stockQuantity: 20,
      );
      final aspirin = await products.create(
        sku: 'G2',
        name: 'Aspirin',
        categoryId: category.id,
        costPrice: 800,
        sellingPrice: 2000,
        stockQuantity: 20,
      );
      final vitamin = await products.create(
        sku: 'G3',
        name: 'Vitamin C',
        categoryId: generic.id,
        costPrice: 300,
        sellingPrice: 900,
        stockQuantity: 20,
      );

      await sell(
        productId: paracetamol.id,
        name: paracetamol.name,
        quantity: 2,
        unitPrice: 2500,
        paymentMethod: 'cash',
        paidAmount: 5000,
      );
      await sell(
        productId: aspirin.id,
        name: aspirin.name,
        quantity: 1,
        unitPrice: 2000,
        paymentMethod: 'cash',
        paidAmount: 2000,
      );
      await sell(
        productId: vitamin.id,
        name: vitamin.name,
        quantity: 3,
        unitPrice: 900,
        paymentMethod: 'cash',
        paidAmount: 2700,
      );

      final now = DateTime.now();
      final report =
          container.read(reportRepositoryProvider) as SqliteReportRepository;
      final categories = await report.getCategorySummary(
        from: DateTime(now.year, now.month, now.day),
        to: DateTime(now.year, now.month, now.day, 23, 59, 59),
      );

      expect(categories.map((c) => c.categoryName).toList(), [
        'Analgesics',
        'Generic',
      ]);
      final analgesics = categories.singleWhere(
        (c) => c.categoryName == 'Analgesics',
      );
      // Cost uses the *current* product cost price: 2*1000 + 1*800.
      expect(analgesics.revenue, 7000);
      expect(analgesics.cost, 2800);
      expect(analgesics.salesCount, 2);
      expect(analgesics.profit, 4200);

      final genericBucket = categories.singleWhere(
        (c) => c.categoryName == 'Generic',
      );
      expect(genericBucket.revenue, 2700);
      expect(genericBucket.cost, 900);
      expect(genericBucket.profit, 1800);
    });

    test('getStockValuation sums cost and retail values', () async {
      await products.create(
        sku: 'V1',
        name: 'A',
        costPrice: 1000,
        sellingPrice: 2500,
        stockQuantity: 5,
      );
      await products.create(
        sku: 'V2',
        name: 'B',
        costPrice: 200,
        sellingPrice: 500,
        stockQuantity: 10,
      );

      final report =
          container.read(reportRepositoryProvider) as SqliteReportRepository;
      final valuation = await report.getStockValuation();
      expect(valuation.items, 2);
      expect(valuation.costValue, 5000 + 2000);
      expect(valuation.retailValue, 12500 + 5000);
    });
  });

  group('settings', () {
    test('low stock threshold defaults to 10 and round-trips', () async {
      final settings =
          container.read(settingsRepositoryProvider)
              as SqliteSettingsRepository;
      expect(await settings.getDefaultLowStockThreshold(), 10);

      final stored = await settings.getStoreSettings();
      await settings.saveStoreSettings(
        StoreSettings(
          storeName: stored.storeName,
          storeAddress: stored.storeAddress,
          storePhone: stored.storePhone,
          storeTaxId: stored.storeTaxId,
          taxRate: stored.taxRate,
          currencySymbol: stored.currencySymbol,
          defaultLowStockThreshold: '15',
          receiptFooter: 'Thank you for your visit!',
        ),
      );

      expect(await settings.getDefaultLowStockThreshold(), 15);
      final loaded = await settings.getStoreSettings();
      expect(loaded.defaultLowStockThreshold, '15');
      expect(loaded.receiptFooter, 'Thank you for your visit!');
    });
  });

  group('product csv', () {
    test('parseProductsCsv parses rows and quoted commas', () {
      final content = [
        productCsvHeader.join(','),
        'P1,"Tylenol, Extra",123,Medic,MedSupply,1000,2500,8,5,2027-01-15,"Fast relief"',
        'P2,Vitamin C,,,,250,500,0,10,,',
      ].join('\n');

      final result = parseProductsCsv(content);

      expect(result.errors, isEmpty);
      expect(result.rows.length, 2);

      final first = result.rows[0];
      expect(first.sku, 'P1');
      expect(first.name, 'Tylenol, Extra');
      expect(first.barcode, '123');
      expect(first.categoryName, 'Medic');
      expect(first.supplierName, 'MedSupply');
      expect(first.costPrice, 1000);
      expect(first.sellingPrice, 2500);
      expect(first.stockQuantity, 8);
      expect(first.lowStockThreshold, 5);
      expect(first.expiryDate, DateTime(2027, 1, 15));
      expect(first.description, 'Fast relief');

      final second = result.rows[1];
      expect(second.stockQuantity, 0);
      expect(second.expiryDate, isNull);
      expect(second.barcode, isNull);
    });

    test('parseProductsCsv reports rows missing sku or name', () {
      final content = [
        productCsvHeader.join(','),
        ',NoName,1.00,2.00,1,5,,',
        'P3,Good,1.00,2.00,1,5,,',
      ].join('\n');

      final result = parseProductsCsv(content);

      expect(result.rows.length, 1);
      expect(result.rows.single.sku, 'P3');
      expect(result.errors.length, 1);
      expect(result.errors.single.$1, 2);
    });

    test('parseProductsCsv strips a UTF-8 BOM and matches case-insensitive '
        'headers', () {
      final content = '\uFEFF${['SKU,NAME,Barcode', 'P1,One,111'].join('\n')}';

      final result = parseProductsCsv(content);

      expect(result.errors, isEmpty);
      expect(result.rows.single.sku, 'P1');
      expect(result.rows.single.name, 'One');
      expect(result.rows.single.barcode, '111');
    });

    test('parseProductsCsv rejects a file without required headers', () {
      final result = parseProductsCsv('a,b\n1,2\n');

      expect(result.rows, isEmpty);
      expect(result.errors.single.$1, 1);
    });

    test('parseProductsCsv clamps negative prices and stock to zero', () {
      final content = [
        productCsvHeader.join(','),
        'P1,Neg,,,,-5.00,-2.00,-3,-4,,',
      ].join('\n');

      final result = parseProductsCsv(content);

      expect(result.errors, isEmpty);
      final row = result.rows.single;
      expect(row.costPrice, 0);
      expect(row.sellingPrice, 0);
      expect(row.stockQuantity, 0);
      expect(row.lowStockThreshold, 0);
    });

    test('parseProductsCsv reports duplicate skus within the file', () {
      final content = [
        productCsvHeader.join(','),
        'P1,First,1.00,2.00,1,5,,',
        'p1,Second,1.00,2.00,1,5,,',
      ].join('\n');

      final result = parseProductsCsv(content);

      expect(result.rows.length, 1);
      expect(result.errors.length, 1);
      expect(result.errors.single.$2, contains('Duplicate sku'));
    });
  });

  group('users', () {
    test(
      'usernames are stored lowercased and found case-insensitively',
      () async {
        final users =
            container.read(userRepositoryProvider) as SqliteUserRepository;
        final created = await users.createUser(
          username: '  CashierOne  ',
          password: 'secret',
          role: UserRole.staff,
        );
        expect(created.username, 'cashierone');

        final found = await users.findByUsername('CASHIERONE');
        expect(found?.id, created.id);
        final foundLower = await users.findByUsername('cashierone');
        expect(foundLower?.id, created.id);
        expect(await users.findByUsername('other'), isNull);
      },
    );

    test('createUser rejects a case-insensitive duplicate', () async {
      final users =
          container.read(userRepositoryProvider) as SqliteUserRepository;
      await users.createUser(
        username: 'Admin',
        password: 'secret',
        role: UserRole.admin,
      );

      await expectLater(
        users.createUser(
          username: 'admin',
          password: 'secret',
          role: UserRole.staff,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
