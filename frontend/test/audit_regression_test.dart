import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mepharma/src/core/services/api_client.dart';
import 'package:mepharma/src/core/services/api_config_manager.dart';
import 'package:mepharma/src/core/services/network_monitor.dart';
import 'package:mepharma/src/core/services/sync_engine.dart';
import 'package:mepharma/src/core/services/thermal_printer_service.dart';
import 'package:mepharma/src/data/db/app_database.dart';
import 'package:mepharma/src/data/repositories/api/api_sale_repository.dart';
import 'package:mepharma/src/data/repositories/offline_first_sale_repository.dart';
import 'package:mepharma/src/data/repositories/sqlite_product_repository.dart';
import 'package:mepharma/src/data/repositories/sqlite_sale_repository.dart';
import 'package:mepharma/src/domain/models/api_config.dart';
import 'package:mepharma/src/domain/models/sale_receipt.dart';

void main() {
  group('Offline-First & Audit Regression Tests', () {
    test('ApiConfig defaults missing mode to local standalone', () {
      final cfg = ApiConfig.fromJson(const {});
      expect(cfg.mode, equals(DatabaseMode.local));
      expect(cfg.isConfigured, isTrue);
      expect(cfg.isLicenseValid, isTrue);

      final def = ApiConfigManager.defaultOfflineConfig;
      expect(def.mode, equals(DatabaseMode.local));
      expect(def.isConfigured, isTrue);
      expect(def.isLicenseValid, isTrue);
      expect(def.licensePlan, equals('offline_standalone'));
    });

    test('NetworkMonitor disabled in local mode skips health pings cleanly', () {
      final monitor = NetworkMonitor(
        baseUrl: 'http://localhost:8000/api',
        pingInterval: const Duration(hours: 1),
        enabled: false,
      );
      expect(monitor.enabled, isFalse);
      monitor.setEnabled(true);
      expect(monitor.enabled, isTrue);
      monitor.dispose();
    });

    test('ThermalPrinterService formats integer currency amounts accurately', () {
      expect(ThermalPrinterService.formatMoneyForTest(12000, r'$'), equals(r'$ 12,000'));
      expect(ThermalPrinterService.formatMoneyForTest(0, r'$'), equals(r'$ 0'));
      expect(ThermalPrinterService.formatMoneyForTest(-2500, 'IQD'), equals('-IQD 2,500'));
      expect(ThermalPrinterService.formatMoneyForTest(500, ''), equals('500'));
    });

    test('NetworkMonitor.isTransportFailure rejects 4xx client errors from offline fallback', () {
      expect(NetworkMonitor.isTransportFailure(ApiException('Bad input', statusCode: 422)), isFalse);
      expect(NetworkMonitor.isTransportFailure(ApiException('Forbidden', statusCode: 403)), isFalse);
      expect(NetworkMonitor.isTransportFailure(ApiException('Server down', statusCode: 503)), isTrue);
      expect(NetworkMonitor.isTransportFailure(ApiException('Timeout')), isTrue);
    });

    test('mirrorServerSale is idempotent and does not duplicate local rows or stock deduction', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final productRepo = SqliteProductRepository(db);
      final saleRepo = SqliteSaleRepository(db);

      try {
        final product = await productRepo.create(
          sku: 'PARA-500',
          name: 'Paracetamol 500mg',
          costPrice: 100,
          sellingPrice: 250,
          stockQuantity: 20,
        );

        final receipt = SaleReceipt(
          id: 99,
          invoiceNumber: 'INV-SRV-0001',
          createdAt: DateTime.utc(2026, 11, 12, 10, 0),
          subtotal: 500,
          discount: 0,
          discountType: null,
          taxAmount: 0,
          totalAmount: 500,
          paidAmount: 500,
          changeAmount: 0,
          paymentMethod: 'cash',
          items: [
            SaleLineItem(
              productId: product.id,
              productName: product.name,
              quantity: 2,
              unitPrice: 250,
              totalPrice: 500,
            ),
          ],
        );

        await saleRepo.mirrorServerSale(receipt, userId: 1);
        await saleRepo.mirrorServerSale(receipt, userId: 1);

        final allSales = await db.select(db.sales).get();
        expect(allSales.length, equals(1));
        expect(allSales.first.invoiceNumber, equals('INV-SRV-0001'));

        final updated = (await productRepo.findById(product.id))!;
        expect(updated.stockQuantity, equals(18));
      } finally {
        await db.close();
      }
    });

    test('OfflineFirstSaleRepository rethrows 422 validation errors instead of queuing offline', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((req) async {
        req.response.statusCode = 422;
        req.response.headers.contentType = ContentType.json;
        req.response.write(jsonEncode({'message': 'Insufficient server stock'}));
        await req.response.close();
      });

      final db = AppDatabase(NativeDatabase.memory());
      final productRepo = SqliteProductRepository(db);
      final localSaleRepo = SqliteSaleRepository(db);
      final baseUrl = 'http://127.0.0.1:${server.port}/api';
      final networkMonitor = NetworkMonitor(
        baseUrl: baseUrl,
        pingInterval: const Duration(hours: 1),
        enabled: true,
      );
      final apiClient = ApiClient(baseUrl: baseUrl, token: 'jwt-test-token');
      final syncEngine = SyncEngine(
        db: db,
        apiClient: apiClient,
        networkMonitor: networkMonitor,
      );
      final repo = OfflineFirstSaleRepository(
        apiRepo: ApiSaleRepository(apiClient),
        localRepo: localSaleRepo,
        syncEngine: syncEngine,
        networkMonitor: networkMonitor,
      );

      try {
        final product = await productRepo.create(
          sku: 'IBU-400',
          name: 'Ibuprofen 400mg',
          costPrice: 150,
          sellingPrice: 300,
          stockQuantity: 10,
        );

        await expectLater(
          () => repo.completeSale(
            items: [
              SaleLineItem(
                productId: product.id,
                productName: product.name,
                quantity: 2,
                unitPrice: 300,
                totalPrice: 600,
              ),
            ],
            subtotal: 600,
            discount: 0,
            taxAmount: 0,
            totalAmount: 600,
            paidAmount: 600,
            changeAmount: 0,
            paymentMethod: 'cash',
            userId: 1,
          ),
          throwsA(isA<ApiException>()),
        );

        final queue = await db.select(db.syncQueueEntries).get();
        expect(queue, isEmpty);
      } finally {
        networkMonitor.dispose();
        syncEngine.dispose();
        await db.close();
      }
    });
  });
}

