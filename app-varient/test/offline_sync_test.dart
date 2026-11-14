import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:mepharma/src/core/services/api_client.dart';
import 'package:mepharma/src/core/services/network_monitor.dart';
import 'package:mepharma/src/core/services/security_delegator.dart';
import 'package:mepharma/src/core/services/sync_engine.dart';
import 'package:mepharma/src/data/db/app_database.dart';
import 'package:mepharma/src/data/repositories/api/api_sale_repository.dart';
import 'package:mepharma/src/data/repositories/offline_first_sale_repository.dart';
import 'package:mepharma/src/data/repositories/sqlite_product_repository.dart';
import 'package:mepharma/src/data/repositories/sqlite_sale_repository.dart';
import 'package:mepharma/src/domain/models/sale_receipt.dart';

void main() {
  group('SecurityDelegator Tests', () {
    test('generateIdempotencyKey creates unique, non-colliding keys', () {
      final key1 = SecurityDelegator.generateIdempotencyKey(prefix: 'sale');
      final key2 = SecurityDelegator.generateIdempotencyKey(prefix: 'sale');

      expect(key1, isNotEmpty);
      expect(key2, isNotEmpty);
      expect(key1, isNot(equals(key2)));
      expect(key1.startsWith('sale-'), isTrue);
    });

    test('calculatePayloadSignature generates consistent and verifiable signatures', () {
      const payload = '{"product_id":1,"quantity":2}';
      final sig1 = SecurityDelegator.calculatePayloadSignature(payload);
      final sig2 = SecurityDelegator.calculatePayloadSignature(payload);
      final sigDiff = SecurityDelegator.calculatePayloadSignature('{"product_id":1,"quantity":3}');

      expect(sig1, equals(sig2));
      expect(sig1, isNot(equals(sigDiff)));
    });
  });

  group('NetworkMonitor Tests', () {
    test('reportFailure and reportSuccess transition states correctly', () {
      final monitor = NetworkMonitor(baseUrl: 'http://localhost:8000/api', pingInterval: const Duration(hours: 1));

      expect(monitor.isOnline, isTrue);

      monitor.reportFailure('Network timeout');
      expect(monitor.isOffline, isTrue);
      expect(monitor.consecutiveFailures, equals(1));

      monitor.reportSuccess();
      expect(monitor.isOnline, isTrue);
      expect(monitor.consecutiveFailures, equals(0));

      monitor.dispose();
    });
  });

  group('Offline-First Sale & SQLite Outbox Queue Tests', () {
    late AppDatabase db;
    late SqliteProductRepository productRepo;
    late SqliteSaleRepository sqliteSaleRepo;
    late NetworkMonitor networkMonitor;
    late SyncEngine syncEngine;
    late OfflineFirstSaleRepository offlineSaleRepo;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      productRepo = SqliteProductRepository(db);
      sqliteSaleRepo = SqliteSaleRepository(db);
      networkMonitor = NetworkMonitor(baseUrl: 'http://localhost:8000/api', pingInterval: const Duration(hours: 1));
      final apiClient = ApiClient(baseUrl: 'http://localhost:8000/api');
      syncEngine = SyncEngine(
        db: db,
        apiClient: apiClient,
        networkMonitor: networkMonitor,
      );
      offlineSaleRepo = OfflineFirstSaleRepository(
        apiRepo: ApiSaleRepository(apiClient),
        localRepo: sqliteSaleRepo,
        syncEngine: syncEngine,
        networkMonitor: networkMonitor,
      );

      // Create test product with stock 50
      await productRepo.create(
        sku: 'AMX-500',
        name: 'Amoxicillin 500mg',
        costPrice: 500,
        sellingPrice: 1000,
        stockQuantity: 50,
      );
    });

    tearDown(() async {
      networkMonitor.dispose();
      syncEngine.dispose();
      await db.close();
    });

    test('Offline sale writes locally, decrements local stock, and enqueues sync item', () async {
      // 1. Force offline
      networkMonitor.reportFailure('Disconnected');
      expect(networkMonitor.isOffline, isTrue);

      final product = (await productRepo.findBySku('AMX-500'))!;

      // 2. Complete sale while offline
      final receipt = await offlineSaleRepo.completeSale(
        items: [
          SaleLineItem(
            productId: product.id,
            productName: product.name,
            barcode: product.barcode,
            quantity: 3,
            unitPrice: product.sellingPrice,
            totalPrice: 3000,
          ),
        ],
        subtotal: 3000,
        discount: 0,
        taxAmount: 0,
        totalAmount: 3000,
        paidAmount: 3000,
        changeAmount: 0,
        paymentMethod: 'cash',
        userId: 1,
      );

      expect(receipt.invoiceNumber, isNotEmpty);
      expect(receipt.totalAmount, equals(3000));

      // 3. Verify local stock was decremented from 50 to 47
      final updatedProduct = (await productRepo.findById(product.id))!;
      expect(updatedProduct.stockQuantity, equals(47));

      // 4. Verify transaction is safely queued in SQLite SyncQueueEntries
      final queueItems = await (db.select(db.syncQueueEntries)).get();
      expect(queueItems.length, equals(1));

      final queueItem = queueItems.first;
      expect(queueItem.entityType, equals('sale'));
      expect(queueItem.action, equals('create'));
      expect(queueItem.status, equals('pending'));
      expect(queueItem.idempotencyKey, isNotEmpty);
      expect(queueItem.payloadSignature, isNotEmpty);
      expect(queueItem.payloadJson, contains(receipt.invoiceNumber));
    });
  });
}
