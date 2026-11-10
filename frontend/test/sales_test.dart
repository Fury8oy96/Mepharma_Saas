import 'dart:convert';

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
import 'package:mepharma/src/domain/models/cart_item.dart';
import 'package:mepharma/src/domain/models/payment_method.dart';
import 'package:mepharma/src/domain/models/sale_receipt.dart';
import 'package:mepharma/src/presentation/pos/pos_controller.dart';

void main() {
  late ProviderContainer container;
  late AppDatabase db;
  late SqliteProductRepository products;
  late SqliteSaleRepository sales;
  late SqliteSalesHoldRepository holds;
  late SqliteUserRepository users;
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
    holds =
        container.read(salesHoldRepositoryProvider)
            as SqliteSalesHoldRepository;
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

  group('sale repository', () {
    test('invoice numbers have a date-stamped prefix', () async {
      final number = await sales.generateInvoiceNumber();
      expect(number, matches(RegExp(r'^INV-\d{8}-\d{4}$')));
    });

    test('completeSale records sale, items, stock and adjustments', () async {
      final p1 = await products.create(
        sku: 'S1',
        name: 'Paracetamol 500mg',
        sellingPrice: 2500,
        stockQuantity: 10,
      );
      final p2 = await products.create(
        sku: 'S2',
        name: 'Amoxicillin 250mg',
        sellingPrice: 1500,
        stockQuantity: 5,
      );

      final receipt = await sales.completeSale(
        items: [
          SaleLineItem(
            productId: p1.id,
            productName: p1.name,
            quantity: 2,
            unitPrice: 2500,
            totalPrice: 5000,
          ),
          SaleLineItem(
            productId: p2.id,
            productName: p2.name,
            quantity: 1,
            unitPrice: 1500,
            totalPrice: 1500,
          ),
        ],
        subtotal: 6500,
        discount: 500,
        discountType: DiscountType.fixed,
        taxAmount: 600,
        totalAmount: 6600,
        paidAmount: 7000,
        changeAmount: 400,
        paymentMethod: 'cash',
        userId: userId,
      );

      expect(receipt.id, greaterThan(0));
      expect(receipt.invoiceNumber, startsWith('INV-'));
      expect(receipt.items.length, 2);
      expect(receipt.paymentMethod, 'cash');

      expect((await products.findById(p1.id))!.stockQuantity, 8);
      expect((await products.findById(p2.id))!.stockQuantity, 4);

      final adjustments = await container
          .read(stockAdjustmentRepositoryProvider)
          .getAll();
      expect(adjustments.length, 2);
      expect(adjustments.map((a) => a.reference).toSet(), {
        'sale:${receipt.id}',
      });
      expect(adjustments.first.adjustmentQuantity, -2);

      final saleRow = await (db.select(
        db.sales,
      )..where((s) => s.id.equals(receipt.id))).getSingle();
      expect(saleRow.status, SaleStatus.completed);
    });

    test('subsequent invoices do not collide', () async {
      final a = await sales.completeSale(
        items: [
          SaleLineItem(
            productId: (await products.create(
              sku: 'N1',
              name: 'A',
              stockQuantity: 1,
            )).id,
            productName: 'A',
            quantity: 1,
            unitPrice: 100,
            totalPrice: 100,
          ),
        ],
        subtotal: 100,
        discount: 0,
        taxAmount: 0,
        totalAmount: 100,
        paidAmount: 100,
        changeAmount: 0,
        paymentMethod: 'card',
        userId: userId,
      );
      final b = await sales.completeSale(
        items: [
          SaleLineItem(
            productId: (await products.create(
              sku: 'N2',
              name: 'B',
              stockQuantity: 1,
            )).id,
            productName: 'B',
            quantity: 1,
            unitPrice: 200,
            totalPrice: 200,
          ),
        ],
        subtotal: 200,
        discount: 0,
        taxAmount: 0,
        totalAmount: 200,
        paidAmount: 200,
        changeAmount: 0,
        paymentMethod: 'cash',
        userId: userId,
      );
      expect(a.invoiceNumber, isNot(b.invoiceNumber));
    });
  });

  group('sales holds', () {
    test('create, watch and delete', () async {
      final held = await holds.createHold(
        userId: userId,
        itemsJson: '[{"productId":1,"quantity":2}]',
        subtotal: 5000,
        discount: 0,
        discountType: DiscountType.percentage,
        totalAmount: 5000,
      );
      expect(held.holdNumber, startsWith('HLD-'));
      expect(held.discountType, DiscountType.percentage);

      final all = await holds.watchAll().first;
      expect(all.single.id, held.id);

      await holds.deleteHold(held.id);
      expect(await holds.watchAll().first, isEmpty);
    });
  });

  group('pos controller', () {
    test('addProduct clamps to available stock', () async {
      final p = await products.create(
        sku: 'C1',
        name: 'Item',
        sellingPrice: 1000,
        stockQuantity: 3,
      );
      final notifier = container.read(posControllerProvider.notifier);

      for (var i = 0; i < 6; i++) {
        notifier.addProduct(p);
      }
      expect(container.read(posControllerProvider).quantityOf(p.id), 3);
    });

    test('discount and tax totals', () async {
      final p = await products.create(
        sku: 'D1',
        name: 'Item',
        sellingPrice: 10000,
        stockQuantity: 5,
      );
      final notifier = container.read(posControllerProvider.notifier);
      notifier.addProduct(p);
      notifier.addProduct(p);

      var state = container.read(posControllerProvider);
      expect(state.subtotal, 20000);

      notifier.setDiscount(DiscountType.percentage, 10);
      state = container.read(posControllerProvider);
      expect(state.discountAmount, 2000);
      expect(state.total(7.5), 19350);
    });

    test('completeSale clears cart and returns receipt', () async {
      final p = await products.create(
        sku: 'E1',
        name: 'Item',
        sellingPrice: 2500,
        stockQuantity: 10,
      );
      final notifier = container.read(posControllerProvider.notifier);
      notifier.addProduct(p);
      notifier.addProduct(p);

      final receipt = await notifier.completeSale(
        method: PaymentMethod.cash,
        receivedCents: 5000,
        taxRatePercent: 0,
        userId: userId,
      );
      expect(receipt.totalAmount, 5000);
      expect(receipt.changeAmount, 0);
      expect(container.read(posControllerProvider).isEmpty, isTrue);
      expect((await products.findById(p.id))!.stockQuantity, 8);
    });

    test('cash change is computed', () async {
      final p = await products.create(
        sku: 'F1',
        name: 'Item',
        sellingPrice: 2500,
        stockQuantity: 10,
      );
      final notifier = container.read(posControllerProvider.notifier);
      notifier.addProduct(p);

      final receipt = await notifier.completeSale(
        method: PaymentMethod.cash,
        receivedCents: 3000,
        taxRatePercent: 0,
        userId: userId,
      );
      expect(receipt.paidAmount, 3000);
      expect(receipt.changeAmount, 500);
    });

    test('insufficient received cash is rejected', () async {
      final p = await products.create(
        sku: 'G1',
        name: 'Item',
        sellingPrice: 2500,
        stockQuantity: 10,
      );
      final notifier = container.read(posControllerProvider.notifier);
      notifier.addProduct(p);

      expect(
        () => notifier.completeSale(
          method: PaymentMethod.cash,
          receivedCents: 2000,
          taxRatePercent: 0,
          userId: userId,
        ),
        throwsA(isA<PosSaleException>()),
      );
      expect(container.read(posControllerProvider).isEmpty, isFalse);
    });

    test('hold and resume round trip', () async {
      final p1 = await products.create(
        sku: 'H1',
        name: 'One',
        sellingPrice: 1000,
        stockQuantity: 10,
      );
      final p2 = await products.create(
        sku: 'H2',
        name: 'Two',
        sellingPrice: 2000,
        stockQuantity: 10,
      );
      final notifier = container.read(posControllerProvider.notifier);
      notifier.addProduct(p1);
      notifier.addProduct(p2);
      notifier.addProduct(p2);
      notifier.setDiscount(DiscountType.percentage, 10);

      final held = await notifier.holdSale(userId: userId);
      expect(container.read(posControllerProvider).isEmpty, isTrue);
      expect(held.discountType, DiscountType.percentage);

      final heldRow = (await holds.watchAll().first).single;
      expect(heldRow.holdNumber, held.holdNumber);

      final restored = <CartItem>[];
      for (final entry in List<Map<String, dynamic>>.from(
        const JsonCodec().decode(heldRow.itemsJson) as List,
      )) {
        final product = await products.findById(
          (entry['productId'] as num).toInt(),
        );
        restored.add(CartItem.fromJson(entry, product!));
      }
      final discountValue = discountFromStored(
        heldRow.discountType,
        heldRow.discount,
      );
      expect(discountValue, 10);
      notifier.loadCart(
        restored,
        discountType: heldRow.discountType,
        discountValue: discountValue,
      );
      final state = container.read(posControllerProvider);
      expect(state.itemCount, 3);
      expect(state.discountType, DiscountType.percentage);
    });

    test('stock is not oversold by the controller', () async {
      final p = await products.create(
        sku: 'I1',
        name: 'Item',
        sellingPrice: 1000,
        stockQuantity: 1,
      );
      final notifier = container.read(posControllerProvider.notifier);
      notifier.addProduct(p);
      notifier.addProduct(p);
      expect(container.read(posControllerProvider).quantityOf(p.id), 1);
      expect(container.read(posControllerProvider).canPay, isTrue);
    });

    test('completeSale on an empty cart reports PosError.emptyCart', () async {
      final notifier = container.read(posControllerProvider.notifier);
      await expectLater(
        notifier.completeSale(
          method: PaymentMethod.cash,
          receivedCents: 0,
          taxRatePercent: 0,
          userId: userId,
        ),
        throwsA(
          isA<PosSaleException>().having(
            (e) => e.code,
            'code',
            PosError.emptyCart,
          ),
        ),
      );
    });

    test('oversold cart reports PosError.insufficientStock', () async {
      final p = await products.create(
        sku: 'I2',
        name: 'Item',
        sellingPrice: 1000,
        stockQuantity: 1,
      );
      final notifier = container.read(posControllerProvider.notifier);
      // A restored hold or stale cart can exceed current stock.
      notifier.loadCart([
        CartItem(product: p, quantity: 3),
      ]);
      expect(container.read(posControllerProvider).hasInsufficientStock, isTrue);
      await expectLater(
        notifier.completeSale(
          method: PaymentMethod.cash,
          receivedCents: 1000,
          taxRatePercent: 0,
          userId: userId,
        ),
        throwsA(
          isA<PosSaleException>().having(
            (e) => e.code,
            'code',
            PosError.insufficientStock,
          ),
        ),
      );
    });

    test(
      'credit sale without customer reports PosError.customerRequired',
      () async {
        final p = await products.create(
          sku: 'I3',
          name: 'Item',
          sellingPrice: 1000,
          stockQuantity: 5,
        );
        final notifier = container.read(posControllerProvider.notifier);
        notifier.addProduct(p);
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
              PosError.customerRequired,
            ),
          ),
        );
      },
    );

    test('short cash reports PosError.insufficientReceived', () async {
      final p = await products.create(
        sku: 'I4',
        name: 'Item',
        sellingPrice: 2000,
        stockQuantity: 5,
      );
      final notifier = container.read(posControllerProvider.notifier);
      notifier.addProduct(p);
      await expectLater(
        notifier.completeSale(
          method: PaymentMethod.cash,
          receivedCents: 1500,
          taxRatePercent: 0,
          userId: userId,
        ),
        throwsA(
          isA<PosSaleException>().having(
            (e) => e.code,
            'code',
            PosError.insufficientReceived,
          ),
        ),
      );
    });

    test('hold is kept when only some products are restored', () async {
      final p1 = await products.create(
        sku: 'J1',
        name: 'One',
        sellingPrice: 1000,
        stockQuantity: 10,
      );
      final p2 = await products.create(
        sku: 'J2',
        name: 'Two',
        sellingPrice: 2000,
        stockQuantity: 10,
      );
      final notifier = container.read(posControllerProvider.notifier);
      notifier.addProduct(p1);
      notifier.addProduct(p2);
      await notifier.holdSale(userId: userId);
      expect(container.read(posControllerProvider).isEmpty, isTrue);

      // Delete one of the held products from the catalog; the hold survives
      // because the other item can still be restored.
      final heldRow = (await holds.watchAll().first).single;
      await (db.delete(db.products)..where((p) => p.id.equals(p1.id))).go();

      final restored = <CartItem>[];
      for (final entry in List<Map<String, dynamic>>.from(
        const JsonCodec().decode(heldRow.itemsJson) as List,
      )) {
        final product = await products.findById(
          (entry['productId'] as num).toInt(),
        );
        if (product != null) {
          restored.add(CartItem.fromJson(entry, product));
        }
      }
      expect(restored.length, 1);
      expect(restored.single.product.id, p2.id);

      // The hold still exists and was not deleted by the partial restore.
      expect((await holds.watchAll().first).single.id, heldRow.id);
    });
  });
}
