import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart';

import '../../core/services/network_monitor.dart';
import '../../core/services/sync_engine.dart';
import '../../domain/models/app_sale.dart';
import '../../domain/models/sale_receipt.dart';
import '../../domain/repositories/sale_repository.dart';
import '../db/app_database.dart';
import '../db/enums.dart';
import 'api/api_sale_repository.dart';
import 'sqlite_sale_repository.dart';

class OfflineFirstSaleRepository implements SaleRepository {
  OfflineFirstSaleRepository({
    required ApiSaleRepository apiRepo,
    required SqliteSaleRepository localRepo,
    required SyncEngine syncEngine,
    required NetworkMonitor networkMonitor,
  })  : _apiRepo = apiRepo,
        _localRepo = localRepo,
        _syncEngine = syncEngine,
        _networkMonitor = networkMonitor;

  final ApiSaleRepository _apiRepo;
  final SqliteSaleRepository _localRepo;
  final SyncEngine _syncEngine;
  final NetworkMonitor _networkMonitor;

  bool get _isOnline => _networkMonitor.isOnline;

  @override
  Future<String> generateInvoiceNumber() async {
    if (_isOnline) {
      try {
        return await _apiRepo.generateInvoiceNumber();
      } catch (_) {
        return _localRepo.generateInvoiceNumber();
      }
    }
    return _localRepo.generateInvoiceNumber();
  }

  @override
  Future<SaleReceipt> completeSale({
    required List<SaleLineItem> items,
    required int subtotal,
    required int discount,
    DiscountType? discountType,
    required int taxAmount,
    required int totalAmount,
    required int paidAmount,
    required int changeAmount,
    required String paymentMethod,
    required int userId,
    String? customerName,
    int? customerId,
  }) async {
    if (_isOnline) {
      try {
        // 1. Process online directly against backend
        final receipt = await _apiRepo.completeSale(
          items: items,
          subtotal: subtotal,
          discount: discount,
          discountType: discountType,
          taxAmount: taxAmount,
          totalAmount: totalAmount,
          paidAmount: paidAmount,
          changeAmount: changeAmount,
          paymentMethod: paymentMethod,
          userId: userId,
          customerName: customerName,
          customerId: customerId,
        );

        // 2. Mirror into local SQLite in the background and mark as synced
        unawaited(_localRepo.completeSale(
          items: items,
          subtotal: subtotal,
          discount: discount,
          discountType: discountType,
          taxAmount: taxAmount,
          totalAmount: totalAmount,
          paidAmount: paidAmount,
          changeAmount: changeAmount,
          paymentMethod: paymentMethod,
          userId: userId,
          customerName: customerName,
          customerId: customerId,
        ).then((localReceipt) async {
          final key = 'online_synced_${localReceipt.invoiceNumber}';
          await _syncEngine.db.into(_syncEngine.db.syncQueueEntries).insert(
                SyncQueueEntriesCompanion(
                  idempotencyKey: Value(key),
                  entityType: const Value('sale'),
                  action: const Value('create'),
                  payloadJson: Value(jsonEncode({'invoice_number': localReceipt.invoiceNumber})),
                  payloadSignature: const Value('online_synced'),
                  createdAt: Value(DateTime.now()),
                  status: const Value('synced'),
                  lastAttemptAt: Value(DateTime.now()),
                ),
                mode: InsertMode.insertOrReplace,
              );
        }).catchError((_) {}));

        return receipt;
      } catch (e) {
        // Do NOT call reportFailure here — a single API error does not mean the
        // network is down; the periodic probe will detect real outages correctly.
        rethrow;
      }
    }

    // Offline flow
    final receipt = await _localRepo.completeSale(
      items: items,
      subtotal: subtotal,
      discount: discount,
      discountType: discountType,
      taxAmount: taxAmount,
      totalAmount: totalAmount,
      paidAmount: paidAmount,
      changeAmount: changeAmount,
      paymentMethod: paymentMethod,
      userId: userId,
      customerName: customerName,
      customerId: customerId,
    );

    final payload = {
      'invoice_number': receipt.invoiceNumber,
      'user_id': userId,
      'customer_id': customerId,
      'customer_name': customerName,
      'subtotal': subtotal,
      'discount': discount,
      'discount_type': discountType?.name,
      'tax_amount': taxAmount,
      'total_amount': totalAmount,
      'paid_amount': paidAmount,
      'change_amount': changeAmount,
      'payment_method': paymentMethod,
      'items': items
          .map((i) => {
                'product_id': i.productId,
                'product_name': i.productName,
                'barcode': i.barcode,
                'quantity': i.quantity,
                'unit_price': i.unitPrice,
                'total_price': i.totalPrice,
              })
          .toList(),
      'created_at': receipt.createdAt.toIso8601String(),
    };

    await _syncEngine.enqueueAction(
      entityType: 'sale',
      action: 'create',
      payload: payload,
    );

    return receipt;
  }

  @override
  Stream<List<AppSale>> watchSales({
    DateTime? from,
    DateTime? to,
    String? paymentMethod,
    SaleStatus? status,
    String? search,
  }) {
    if (_isOnline) {
      final controller = StreamController<List<AppSale>>.broadcast();
      List<AppSale> localSales = [];
      List<AppSale> serverSales = [];

      void emitMerged() {
        if (controller.isClosed) return;
        final map = <String, AppSale>{};
        // Server sales take primary precedence
        for (final s in serverSales) {
          map[s.invoiceNumber] = s;
        }
        // Add any local sales that are not yet confirmed on server
        for (final s in localSales) {
          if (!map.containsKey(s.invoiceNumber)) {
            map[s.invoiceNumber] = s;
          }
        }
        final list = map.values.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        controller.add(list);
      }

      final subLocal = _localRepo
          .watchSales(
            from: from,
            to: to,
            paymentMethod: paymentMethod,
            status: status,
            search: search,
          )
          .listen((data) {
        localSales = data;
        emitMerged();
      });

      final subApi = _apiRepo
          .watchSales(
            from: from,
            to: to,
            paymentMethod: paymentMethod,
            status: status,
            search: search,
          )
          .listen(
        (data) {
          serverSales = data;
          emitMerged();
        },
        onError: (err) {
          _networkMonitor.reportFailure(err);
          if (!controller.isClosed) {
            controller.add(localSales);
          }
        },
      );

      controller.onCancel = () {
        subLocal.cancel();
        subApi.cancel();
      };

      return controller.stream;
    }
    return _localRepo.watchSales(
      from: from,
      to: to,
      paymentMethod: paymentMethod,
      status: status,
      search: search,
    );
  }

  @override
  Future<SaleDetail> getSaleDetail(int id) async {
    if (_isOnline) {
      try {
        return await _apiRepo.getSaleDetail(id);
      } catch (_) {
        return _localRepo.getSaleDetail(id);
      }
    }
    return _localRepo.getSaleDetail(id);
  }

  @override
  Future<void> refresh() async {
    if (_isOnline) {
      await _apiRepo.refresh();
    }
    await _localRepo.refresh();
    await _syncEngine.triggerSync();
  }
}
