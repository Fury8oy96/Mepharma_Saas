import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../data/db/app_database.dart';
import '../services/api_client.dart';
import 'network_monitor.dart';
import 'security_delegator.dart';

import '../../data/db/enums.dart';

class SyncEngine extends ChangeNotifier {
  SyncEngine({
    required this.db,
    required this.apiClient,
    required this.networkMonitor,
  }) {
    _initListener();
  }

  final AppDatabase db;
  final ApiClient apiClient;
  final NetworkMonitor networkMonitor;

  bool _isDisposed = false;
  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  int _pendingCount = 0;
  int get pendingCount => _pendingCount;

  StreamSubscription? _statusSubscription;
  DateTime? _lastSyncAttempt;

  void _initListener() {
    _refreshPendingCount();
    NetworkState previousState = networkMonitor.state;
    _statusSubscription = networkMonitor.onStatusChange.listen((status) {
      final wasOffline = previousState == NetworkState.offline;
      previousState = status;
      // Auto-trigger sync ONLY when transitioning from offline to online
      if (status == NetworkState.online && wasOffline && !_isDisposed) {
        Future.delayed(const Duration(seconds: 1), () {
          if (!_isDisposed && networkMonitor.isOnline) {
            triggerSync();
          }
        });
      }
    });
  }

  Future<void> _refreshPendingCount() async {
    if (_isDisposed) return;
    try {
      final count = await (db.select(db.syncQueueEntries)
            ..where((t) => t.status.isIn(['pending', 'failed'])))
          .get()
          .then((l) => l.length);
      _pendingCount = count;
      if (!_isDisposed) {
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Enqueues an offline transaction into SQLite SyncQueue
  Future<String> enqueueAction({
    required String entityType,
    required String action,
    required Map<String, dynamic> payload,
    String? idempotencyKey,
  }) async {
    final key = idempotencyKey ?? SecurityDelegator.generateIdempotencyKey(prefix: entityType);
    final payloadJson = jsonEncode(payload);
    final signature = SecurityDelegator.calculatePayloadSignature(payloadJson);

    await db.into(db.syncQueueEntries).insert(
          SyncQueueEntriesCompanion.insert(
            idempotencyKey: key,
            entityType: entityType,
            action: action,
            payloadJson: payloadJson,
            payloadSignature: signature,
            createdAt: Value(DateTime.now()),
            status: const Value('pending'),
          ),
          mode: InsertMode.insertOrReplace,
        );

    await _refreshPendingCount();

    if (networkMonitor.isOnline && !_isDisposed) {
      // Trigger background sync
      unawaited(triggerSync());
    }

    return key;
  }

  /// Triggers a full master snapshot pull from server (e.g. on login or first bootstrap)
  Future<void> takeInitialSnapshot({bool force = false}) async {
    if (!networkMonitor.isOnline || _isDisposed) return;
    await triggerSync(initialBootstrap: force);
  }

  /// Triggers a full sync cycle: push outbox and pull master updates
  Future<void> triggerSync({bool initialBootstrap = false}) async {
    if (_isSyncing || _isDisposed) return;

    final now = DateTime.now();
    if (!initialBootstrap &&
        _lastSyncAttempt != null &&
        now.difference(_lastSyncAttempt!) < const Duration(seconds: 6)) {
      return;
    }
    _lastSyncAttempt = now;

    _isSyncing = true;
    networkMonitor.setSyncing(true);
    if (!_isDisposed) {
      notifyListeners();
    }

    try {
      await _reconcileUnqueuedLocalSales();
      await _pushPendingQueue();
      await _pullDeltaUpdates(initialBootstrap: initialBootstrap);
      if (!_isDisposed) {
        networkMonitor.reportSuccess();
      }
    } catch (e) {
      if (!_isDisposed) {
        final errStr = e.toString();
        final isNetworkErr = errStr.contains('SocketException') ||
            errStr.contains('TimeoutException') ||
            errStr.contains('timed out') ||
            errStr.contains('Cannot reach the server');
        if (isNetworkErr) {
          networkMonitor.reportFailure(e);
        } else {
          debugPrint('SyncEngine non-fatal sync notice: $e');
        }
      }
    } finally {
      _isSyncing = false;
      networkMonitor.setSyncing(false);
      if (!_isDisposed) {
        await _refreshPendingCount();
        notifyListeners();
      }
    }
  }

  /// Sweeps local SQLite sales to ensure any sales recorded without a queue entry get enqueued
  Future<void> _reconcileUnqueuedLocalSales() async {
    try {
      final allLocalSales = await db.select(db.sales).get();
      if (allLocalSales.isEmpty) return;

      final existingQueue = await db.select(db.syncQueueEntries).get();
      final queuedInvoices = <String>{};
      for (final q in existingQueue) {
        if (q.entityType == 'sale') {
          try {
            final payload = jsonDecode(q.payloadJson) as Map<String, dynamic>;
            final inv = payload['invoice_number'] as String?;
            if (inv != null) queuedInvoices.add(inv);
          } catch (_) {}
        }
      }

      for (final sale in allLocalSales) {
        if (!queuedInvoices.contains(sale.invoiceNumber)) {
          final items = await (db.select(db.saleItems)..where((i) => i.saleId.equals(sale.id))).get();
          final payload = {
            'invoice_number': sale.invoiceNumber,
            'user_id': sale.userId,
            'customer_id': sale.customerId,
            'customer_name': sale.customerName,
            'subtotal': sale.subtotal,
            'discount': sale.discount,
            'discount_type': sale.discountType?.name,
            'tax_amount': sale.taxAmount,
            'total_amount': sale.totalAmount,
            'paid_amount': sale.paidAmount,
            'change_amount': sale.changeAmount,
            'payment_method': sale.paymentMethod ?? 'cash',
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
            'created_at': sale.createdAt.toIso8601String(),
          };

          final key = SecurityDelegator.generateIdempotencyKey(prefix: 'sale');
          final payloadJson = jsonEncode(payload);
          final signature = SecurityDelegator.calculatePayloadSignature(payloadJson);

          await db.into(db.syncQueueEntries).insert(
                SyncQueueEntriesCompanion.insert(
                  idempotencyKey: key,
                  entityType: 'sale',
                  action: 'create',
                  payloadJson: payloadJson,
                  payloadSignature: signature,
                  createdAt: Value(DateTime.now()),
                  status: const Value('pending'),
                ),
                mode: InsertMode.insertOrReplace,
              );
          queuedInvoices.add(sale.invoiceNumber);
        }
      }
    } catch (_) {}
  }

  Future<void> _pushPendingQueue() async {
    final pendingItems = await (db.select(db.syncQueueEntries)
          ..where((t) => t.status.isIn(['pending', 'failed']))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();

    if (pendingItems.isEmpty) return;

    final batchPayload = pendingItems.map((entry) {
      return {
        'idempotency_key': entry.idempotencyKey,
        'entity_type': entry.entityType,
        'action': entry.action,
        'payload': jsonDecode(entry.payloadJson),
        'signature': entry.payloadSignature,
        'created_at': entry.createdAt.toIso8601String(),
      };
    }).toList();

    try {
      final response = await apiClient.post(
        '/sync/push-batch',
        body: {
          'items': batchPayload,
          'client_timestamp': DateTime.now().toIso8601String(),
        },
      );

      final resData = jsonDecode(response.body) as Map<String, dynamic>;
      final results = resData['items'] as List? ?? [];

      for (final res in results) {
        final key = res['idempotency_key'] as String?;
        final status = res['status'] as String?;
        final error = res['error'] as String?;

        if (key != null) {
          if (status == 'applied' || status == 'already_processed') {
            await (db.update(db.syncQueueEntries)..where((t) => t.idempotencyKey.equals(key))).write(
              SyncQueueEntriesCompanion(
                status: const Value('synced'),
                errorMessage: const Value(null),
                lastAttemptAt: Value(DateTime.now()),
              ),
            );
          } else {
            await (db.update(db.syncQueueEntries)..where((t) => t.idempotencyKey.equals(key))).write(
              SyncQueueEntriesCompanion(
                status: const Value('failed'),
                errorMessage: Value(error),
                lastAttemptAt: Value(DateTime.now()),
                retryCount: const Value(1),
              ),
            );
          }
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _pullDeltaUpdates({bool initialBootstrap = false}) async {
    try {
      String since = DateTime.fromMillisecondsSinceEpoch(0).toIso8601String();
      if (!initialBootstrap) {
        final lastSyncSetting = await (db.select(db.settings)
              ..where((t) => t.key.equals('last_sync_timestamp')))
            .getSingleOrNull();
        final val = lastSyncSetting?.value;
        if (val != null && val.isNotEmpty) {
          since = val;
        }
      }

      final response = await apiClient.get('/sync/pull-updates?since=$since');
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      final products = data['products'] as List? ?? [];
      final categories = data['categories'] as List? ?? [];
      final suppliers = data['suppliers'] as List? ?? [];
      final customers = data['customers'] as List? ?? [];
      final sales = data['sales'] as List? ?? [];
      final saleItems = data['sale_items'] as List? ?? [];

      await db.transaction(() async {
        // Upsert categories
        for (final cat in categories) {
          await db.into(db.categories).insert(
                CategoriesCompanion(
                  id: Value(cat['id'] as int),
                  name: Value(cat['name'] as String),
                  description: Value(cat['description'] as String?),
                ),
                mode: InsertMode.insertOrReplace,
              );
        }

        // Upsert suppliers
        for (final sup in suppliers) {
          await db.into(db.suppliers).insert(
                SuppliersCompanion(
                  id: Value(sup['id'] as int),
                  name: Value(sup['name'] as String),
                  contactPerson: Value(sup['contact_person'] as String?),
                  phone: Value(sup['phone'] as String?),
                  email: Value(sup['email'] as String?),
                  address: Value(sup['address'] as String?),
                ),
                mode: InsertMode.insertOrReplace,
              );
        }

        // Upsert products
        for (final p in products) {
          await db.into(db.products).insert(
                ProductsCompanion(
                  id: Value(p['id'] as int),
                  sku: Value(p['sku'] as String),
                  barcode: Value(p['barcode'] as String?),
                  name: Value(p['name'] as String),
                  categoryId: Value(p['category_id'] as int?),
                  supplierId: Value(p['supplier_id'] as int?),
                  costPrice: Value((p['cost_price'] as num?)?.round() ?? 0),
                  sellingPrice: Value((p['selling_price'] as num?)?.round() ?? 0),
                  stockQuantity: Value(p['stock_quantity'] as int? ?? 0),
                  lowStockThreshold: Value(p['low_stock_threshold'] as int? ?? 10),
                  expiryDate: Value(p['expiry_date'] != null ? DateTime.tryParse(p['expiry_date'] as String) : null),
                  description: Value(p['description'] as String?),
                  updatedAt: Value(p['updated_at'] != null ? DateTime.tryParse(p['updated_at'] as String) ?? DateTime.now() : DateTime.now()),
                ),
                mode: InsertMode.insertOrReplace,
              );
        }

        // Upsert customers
        for (final c in customers) {
          await db.into(db.customers).insert(
                CustomersCompanion(
                  id: Value(c['id'] as int),
                  name: Value(c['name'] as String),
                  phone: Value(c['phone'] as String?),
                  email: Value(c['email'] as String?),
                  address: Value(c['address'] as String?),
                  notes: Value(c['notes'] as String?),
                  creditLimit: Value((c['credit_limit'] as num?)?.round() ?? 0),
                  createdAt: Value(c['created_at'] != null ? DateTime.tryParse(c['created_at'] as String) ?? DateTime.now() : DateTime.now()),
                ),
                mode: InsertMode.insertOrReplace,
              );
        }

        // Upsert sales from server master snapshot
        for (final s in sales) {
          final invNumber = s['invoice_number'] as String;
          final statusStr = (s['status'] as String?)?.toLowerCase() ?? 'completed';
          final status = (statusStr == 'voided' || statusStr == 'cancelled')
              ? SaleStatus.voided
              : (statusStr == 'returned' ? SaleStatus.returned : SaleStatus.completed);
          final discountTypeStr = s['discount_type'] as String?;
          final discountType = discountTypeStr == 'percentage'
              ? DiscountType.percentage
              : (discountTypeStr == 'fixed' ? DiscountType.fixed : null);

          await db.into(db.sales).insert(
                SalesCompanion(
                  id: Value(s['id'] as int),
                  invoiceNumber: Value(invNumber),
                  userId: Value(s['user_id'] is int ? s['user_id'] as int : 1),
                  customerId: Value(s['customer_id'] is int ? s['customer_id'] as int : null),
                  customerName: Value(s['customer_name'] as String?),
                  subtotal: Value((s['subtotal'] as num?)?.round() ?? 0),
                  discount: Value((s['discount'] as num?)?.round() ?? 0),
                  discountType: Value(discountType),
                  taxAmount: Value((s['tax_amount'] as num?)?.round() ?? 0),
                  totalAmount: Value((s['total_amount'] as num?)?.round() ?? 0),
                  paidAmount: Value((s['paid_amount'] as num?)?.round() ?? 0),
                  changeAmount: Value((s['change_amount'] as num?)?.round() ?? 0),
                  paymentMethod: Value(s['payment_method'] as String?),
                  status: Value(status),
                  createdAt: Value(s['created_at'] != null ? DateTime.tryParse(s['created_at'] as String) ?? DateTime.now() : DateTime.now()),
                ),
                mode: InsertMode.insertOrReplace,
              );

          // Mark as synced in local SQLite queue so it is never swept as unqueued offline sale
          final key = 'server_synced_$invNumber';
          await db.into(db.syncQueueEntries).insert(
                SyncQueueEntriesCompanion(
                  idempotencyKey: Value(key),
                  entityType: const Value('sale'),
                  action: const Value('create'),
                  payloadJson: Value(jsonEncode({'invoice_number': invNumber})),
                  payloadSignature: const Value('server_synced'),
                  createdAt: Value(DateTime.now()),
                  status: const Value('synced'),
                  lastAttemptAt: Value(DateTime.now()),
                ),
                mode: InsertMode.insertOrReplace,
              );
        }

        // Upsert sale items from server
        for (final item in saleItems) {
          await db.into(db.saleItems).insert(
                SaleItemsCompanion(
                  id: Value(item['id'] as int),
                  saleId: Value(item['sale_id'] as int),
                  productId: Value(item['product_id'] is int ? item['product_id'] as int : null),
                  productName: Value(item['product_name'] as String),
                  quantity: Value(item['quantity'] as int? ?? 1),
                  unitPrice: Value((item['unit_price'] as num?)?.round() ?? 0),
                  discount: Value((item['discount'] as num?)?.round() ?? 0),
                  totalPrice: Value((item['total_price'] as num?)?.round() ?? 0),
                ),
                mode: InsertMode.insertOrReplace,
              );
        }

        // Update last sync timestamp
        final serverTime = data['server_time'] as String? ?? DateTime.now().toIso8601String();
        await db.into(db.settings).insert(
              SettingsCompanion(
                key: const Value('last_sync_timestamp'),
                value: Value(serverTime),
              ),
              mode: InsertMode.insertOrReplace,
            );
      });
    } catch (_) {}
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _statusSubscription?.cancel();
    super.dispose();
  }
}
