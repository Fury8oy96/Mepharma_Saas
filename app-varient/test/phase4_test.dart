import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mepharma/src/app/providers.dart';
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

void main() {
  late ProviderContainer container;
  late AppDatabase db;
  late SqliteProductRepository products;
  late SqliteSaleRepository sales;
  late SqliteReturnRepository returns;
  late SqlitePurchaseRepository purchases;
  late SqliteSupplierRepository suppliers;
  late SqliteUserRepository users;
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
    users = container.read(userRepositoryProvider) as SqliteUserRepository;
    userId = (await users.createUser(
      username: 'cashier',
      password: 'secret',
      role: UserRole.staff,
    )).id;
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
    String paymentMethod = 'cash',
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

  group('returns', () {
    test('partial return restocks and writes adjustments', () async {
      final p = await products.create(
        sku: 'R1',
        name: 'Paracetamol',
        sellingPrice: 2500,
        stockQuantity: 10,
      );
      final saleId = await sell(
        productId: p.id,
        name: p.name,
        quantity: 4,
        unitPrice: 2500,
      );

      final detail = await sales.getSaleDetail(saleId);
      final item = detail.items.single;

      final created = await returns.createReturn(
        saleId: saleId,
        userId: userId,
        reason: 'wrong item',
        items: [
          ReturnLineInput(
            saleItemId: item.id,
            productId: p.id,
            productName: p.name,
            unitPrice: 2500,
            quantity: 2,
          ),
        ],
      );

      expect(created.totalRefund, 5000);
      expect(created.reason, 'wrong item');
      expect(created.invoiceNumber, detail.sale.invoiceNumber);

      expect((await products.findById(p.id))!.stockQuantity, 8);

      final adjustments =
          await container.read(stockAdjustmentRepositoryProvider).getAll();
      final returnAdjustment = adjustments.singleWhere(
        (a) => a.reference == 'return:${created.id}',
      );
      expect(returnAdjustment.adjustmentQuantity, 2);
      expect(returnAdjustment.reason, 'POS return');

      final allReturns = await returns.getReturnsForSale(saleId);
      expect(allReturns.single.id, created.id);

      final returnedItems = await returns.getReturnItemsForSale(saleId);
      expect(returnedItems.single.saleItemId, item.id);

      final refreshed = await sales.getSaleDetail(saleId);
      expect(refreshed.sale.status, SaleStatus.completed);
    });

    test('cannot return more than sold or already returned', () async {
      final p = await products.create(
        sku: 'R2',
        name: 'Amoxicillin',
        sellingPrice: 1500,
        stockQuantity: 5,
      );
      final saleId = await sell(
        productId: p.id,
        name: p.name,
        quantity: 4,
        unitPrice: 1500,
      );
      final item = (await sales.getSaleDetail(saleId)).items.single;

      await expectLater(
        returns.createReturn(
          saleId: saleId,
          userId: userId,
          items: [
            ReturnLineInput(
              saleItemId: item.id,
              productId: p.id,
              productName: p.name,
              unitPrice: 1500,
              quantity: 5,
            ),
          ],
        ),
        throwsA(isA<StateError>()),
      );

      await returns.createReturn(
        saleId: saleId,
        userId: userId,
        items: [
          ReturnLineInput(
            saleItemId: item.id,
            productId: p.id,
            productName: p.name,
            unitPrice: 1500,
            quantity: 3,
          ),
        ],
      );

      await expectLater(
        returns.createReturn(
          saleId: saleId,
          userId: userId,
          items: [
            ReturnLineInput(
              saleItemId: item.id,
              productId: p.id,
              productName: p.name,
              unitPrice: 1500,
              quantity: 2,
            ),
          ],
        ),
        throwsA(isA<StateError>()),
      );

      expect((await products.findById(p.id))!.stockQuantity, 4);
    });

    test('fully returned sale is marked returned', () async {
      final p = await products.create(
        sku: 'R3',
        name: 'Ibuprofen',
        sellingPrice: 1200,
        stockQuantity: 3,
      );
      final saleId = await sell(
        productId: p.id,
        name: p.name,
        quantity: 2,
        unitPrice: 1200,
      );
      final item = (await sales.getSaleDetail(saleId)).items.single;

      await returns.createReturn(
        saleId: saleId,
        userId: userId,
        items: [
          ReturnLineInput(
            saleItemId: item.id,
            productId: p.id,
            productName: p.name,
            unitPrice: 1200,
            quantity: 2,
          ),
        ],
      );

      final detail = await sales.getSaleDetail(saleId);
      expect(detail.sale.status, SaleStatus.returned);
      expect((await products.findById(p.id))!.stockQuantity, 3);
    });

    test('sale detail lists processed returns', () async {
      final p = await products.create(
        sku: 'R4',
        name: 'Vitamin C',
        sellingPrice: 800,
        stockQuantity: 10,
      );
      final saleId = await sell(
        productId: p.id,
        name: p.name,
        quantity: 5,
        unitPrice: 800,
      );
      final item = (await sales.getSaleDetail(saleId)).items.single;

      await returns.createReturn(
        saleId: saleId,
        userId: userId,
        reason: 'damaged',
        items: [
          ReturnLineInput(
            saleItemId: item.id,
            productId: p.id,
            productName: p.name,
            unitPrice: 800,
            quantity: 1,
          ),
        ],
      );

      final detail = await sales.getSaleDetail(saleId);
      expect(detail.returns.length, 1);
      expect(detail.returns.single.reason, 'damaged');
      expect(detail.returns.single.totalRefund, 800);
    });
  });

  group('purchases', () {
    test('purchase numbers have a date-stamped prefix', () async {
      final number = await purchases.generatePurchaseNumber();
      expect(number, matches(RegExp(r'^PUR-\d{8}-\d{4}$')));
    });

    test('createPurchase restocks, updates cost and writes adjustments',
        () async {
      final supplier = await suppliers.create(name: 'MedSupply');
      final p = await products.create(
        sku: 'P1',
        name: 'Aspirin',
        costPrice: 1000,
        sellingPrice: 2000,
        stockQuantity: 5,
      );

      final created = await purchases.createPurchase(
        userId: userId,
        supplierId: supplier.id,
        purchaseDate: DateTime(2026, 1, 15),
        items: [
          PurchaseLineInput(
            productId: p.id,
            productName: p.name,
            quantity: 10,
            costPrice: 1200,
          ),
          PurchaseLineInput(
            productId: p.id,
            productName: p.name,
            quantity: 5,
            costPrice: 1300,
          ),
        ],
      );

      expect(created.invoiceNumber, startsWith('PUR-'));
      expect(created.supplierId, supplier.id);
      expect(created.totalAmount, 10 * 1200 + 5 * 1300);
      expect(created.purchaseDate, DateTime(2026, 1, 15));

      final refreshed = (await products.findById(p.id))!;
      expect(refreshed.stockQuantity, 20);
      expect(refreshed.costPrice, 1300);

      final adjustments =
          await container.read(stockAdjustmentRepositoryProvider).getAll();
      final purchaseAdjustments = adjustments
          .where((a) => a.reference == 'purchase:${created.id}')
          .toList();
      expect(purchaseAdjustments.length, 2);
      expect(
        purchaseAdjustments
            .fold<int>(0, (sum, a) => sum + a.adjustmentQuantity),
        15,
      );
      expect(purchaseAdjustments.every((a) => a.reason == 'Purchase'), isTrue);

      expect((await purchases.watchPurchases().first).single.id, created.id);

      final detail = await purchases.getPurchaseDetail(created.id);
      expect(detail.items.length, 2);
      expect(detail.items.first.productId, p.id);
      expect(detail.items.last.costPrice, 1300);
    });
  });

  group('sale history queries', () {
    test('watchSales filters by status, payment method and search',
        () async {
      final p1 = await products.create(
        sku: 'Q1',
        name: 'Alpha',
        sellingPrice: 1000,
        stockQuantity: 10,
      );
      final p2 = await products.create(
        sku: 'Q2',
        name: 'Beta',
        sellingPrice: 1000,
        stockQuantity: 10,
      );
      final cashId = await sell(
        productId: p1.id,
        name: p1.name,
        quantity: 1,
        unitPrice: 1000,
        paymentMethod: 'cash',
      );
      final cardId = await sell(
        productId: p2.id,
        name: p2.name,
        quantity: 1,
        unitPrice: 1000,
        paymentMethod: 'card',
      );
      final cashDetail = await sales.getSaleDetail(cashId);
      final cardDetail = await sales.getSaleDetail(cardId);

      // Fully return the card sale so its status flips to 'returned'.
      for (final item in cardDetail.items) {
        await returns.createReturn(
          saleId: cardId,
          userId: userId,
          items: [
            ReturnLineInput(
              saleItemId: item.id,
              productId: item.productId,
              productName: item.productName,
              unitPrice: item.unitPrice,
              quantity: item.quantity,
            ),
          ],
        );
      }

      final completed = await sales
          .watchSales(status: SaleStatus.completed)
          .first;
      expect(completed.single.id, cashId);

      final returned = await sales
          .watchSales(status: SaleStatus.returned)
          .first;
      expect(returned.single.id, cardId);

      final cashOnly = await sales
          .watchSales(paymentMethod: 'cash')
          .first;
      expect(cashOnly.map((s) => s.id).toSet(), {cashId});

      final byNumber = await sales
          .watchSales(search: cashDetail.sale.invoiceNumber)
          .first;
      expect(byNumber.single.id, cashId);

      final all = await sales.watchSales().first;
      expect(all.length, 2);
    });
  });
}
