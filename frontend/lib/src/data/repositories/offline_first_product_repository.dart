import 'dart:async';

import '../../core/services/api_client.dart';
import '../../core/services/network_monitor.dart';
import '../../core/services/sync_engine.dart';
import '../../domain/models/app_product.dart';
import '../../domain/repositories/product_repository.dart';
import 'api/api_product_repository.dart';
import 'sqlite_product_repository.dart';

class OfflineFirstProductRepository implements ProductRepository {
  OfflineFirstProductRepository({
    required ApiProductRepository apiRepo,
    required SqliteProductRepository localRepo,
    required SyncEngine syncEngine,
    required NetworkMonitor networkMonitor,
  })  : _apiRepo = apiRepo,
        _localRepo = localRepo,
        _syncEngine = syncEngine,
        _networkMonitor = networkMonitor;

  final ApiProductRepository _apiRepo;
  final SqliteProductRepository _localRepo;
  final SyncEngine _syncEngine;
  final NetworkMonitor _networkMonitor;

  bool get _isOnline => _networkMonitor.isOnline;

  Future<void> _mirrorToLocal(List<AppProduct> products) async {
    for (final p in products) {
      try {
        await _localRepo.upsertMirror(p);
      } catch (_) {}
    }
  }

  @override
  Stream<List<AppProduct>> watchAll() async* {
    if (_isOnline) {
      try {
        final products = await getAll();
        yield products;
      } catch (_) {}
      yield* _apiRepo.watchAll();
    } else {
      yield* _localRepo.watchAll();
    }
  }

  @override
  Stream<List<AppProduct>> watchLowStock() async* {
    if (_isOnline) {
      yield* _apiRepo.watchLowStock();
    } else {
      yield* _localRepo.watchLowStock();
    }
  }

  @override
  Stream<List<AppProduct>> watchExpiring({required int withinDays}) async* {
    if (_isOnline) {
      yield* _apiRepo.watchExpiring(withinDays: withinDays);
    } else {
      yield* _localRepo.watchExpiring(withinDays: withinDays);
    }
  }

  @override
  Future<List<AppProduct>> getAll() async {
    if (_isOnline) {
      try {
        final products = await _apiRepo.getAll();
        unawaited(_mirrorToLocal(products));
        return products;
      } catch (e) {
        _networkMonitor.reportFailure(e);
        return _localRepo.getAll();
      }
    }
    return _localRepo.getAll();
  }

  @override
  Future<List<AppProduct>> search(String query) async {
    if (_isOnline) {
      try {
        return await _apiRepo.search(query);
      } catch (_) {
        return _localRepo.search(query);
      }
    }
    return _localRepo.search(query);
  }

  @override
  Future<AppProduct?> findById(int id) async {
    if (_isOnline) {
      try {
        return await _apiRepo.findById(id);
      } catch (_) {
        return _localRepo.findById(id);
      }
    }
    return _localRepo.findById(id);
  }

  @override
  Future<AppProduct?> findBySku(String sku) async {
    if (_isOnline) {
      try {
        return await _apiRepo.findBySku(sku);
      } catch (_) {
        return _localRepo.findBySku(sku);
      }
    }
    return _localRepo.findBySku(sku);
  }

  @override
  Future<AppProduct?> findByBarcode(String barcode) async {
    if (_isOnline) {
      try {
        return await _apiRepo.findByBarcode(barcode);
      } catch (_) {
        return _localRepo.findByBarcode(barcode);
      }
    }
    return _localRepo.findByBarcode(barcode);
  }

  @override
  Future<AppProduct> create({
    required String sku,
    required String name,
    String? barcode,
    int? categoryId,
    int? supplierId,
    int costPrice = 0,
    int sellingPrice = 0,
    int stockQuantity = 0,
    int lowStockThreshold = 10,
    DateTime? expiryDate,
    String? description,
  }) async {
    if (_isOnline) {
      try {
        final product = await _apiRepo.create(
          sku: sku,
          name: name,
          barcode: barcode,
          categoryId: categoryId,
          supplierId: supplierId,
          costPrice: costPrice,
          sellingPrice: sellingPrice,
          stockQuantity: stockQuantity,
          lowStockThreshold: lowStockThreshold,
          expiryDate: expiryDate,
          description: description,
        );
        unawaited(_mirrorToLocal([product]));
        return product;
      } catch (e) {
        if (e is ApiException && e.statusCode != null && e.statusCode! >= 400 && e.statusCode! < 500) {
          rethrow;
        }
        _networkMonitor.reportFailure(e);
      }
    }

    // Offline flow
    final product = await _localRepo.create(
      sku: sku,
      name: name,
      barcode: barcode,
      categoryId: categoryId,
      supplierId: supplierId,
      costPrice: costPrice,
      sellingPrice: sellingPrice,
      stockQuantity: stockQuantity,
      lowStockThreshold: lowStockThreshold,
      expiryDate: expiryDate,
      description: description,
    );

    final payload = {
      'sku': sku,
      'name': name,
      'barcode': barcode,
      'category_id': categoryId,
      'supplier_id': supplierId,
      'cost_price': costPrice,
      'selling_price': sellingPrice,
      'stock_quantity': stockQuantity,
      'low_stock_threshold': lowStockThreshold,
      'expiry_date': expiryDate?.toIso8601String(),
      'description': description,
    };

    await _syncEngine.enqueueAction(
      entityType: 'product',
      action: 'create',
      payload: payload,
    );

    return product;
  }

  @override
  Future<void> update(
    int id, {
    required String name,
    String? barcode,
    int? categoryId,
    int? supplierId,
    int? costPrice,
    int? sellingPrice,
    int? lowStockThreshold,
    DateTime? expiryDate,
    String? description,
  }) async {
    if (_isOnline) {
      try {
        await _apiRepo.update(
          id,
          name: name,
          barcode: barcode,
          categoryId: categoryId,
          supplierId: supplierId,
          costPrice: costPrice,
          sellingPrice: sellingPrice,
          lowStockThreshold: lowStockThreshold,
          expiryDate: expiryDate,
          description: description,
        );
        await _localRepo.update(
          id,
          name: name,
          barcode: barcode,
          categoryId: categoryId,
          supplierId: supplierId,
          costPrice: costPrice,
          sellingPrice: sellingPrice,
          lowStockThreshold: lowStockThreshold,
          expiryDate: expiryDate,
          description: description,
        );
        return;
      } catch (e) {
        if (e is ApiException && e.statusCode != null && e.statusCode! >= 400 && e.statusCode! < 500) {
          rethrow;
        }
        _networkMonitor.reportFailure(e);
      }
    }

    // Offline flow
    await _localRepo.update(
      id,
      name: name,
      barcode: barcode,
      categoryId: categoryId,
      supplierId: supplierId,
      costPrice: costPrice,
      sellingPrice: sellingPrice,
      lowStockThreshold: lowStockThreshold,
      expiryDate: expiryDate,
      description: description,
    );

    final payload = {
      'id': id,
      'name': name,
      'barcode': barcode,
      'category_id': categoryId,
      'supplier_id': supplierId,
      'cost_price': costPrice,
      'selling_price': sellingPrice,
      'low_stock_threshold': lowStockThreshold,
      'expiry_date': expiryDate?.toIso8601String(),
      'description': description,
    };

    await _syncEngine.enqueueAction(
      entityType: 'product',
      action: 'update',
      payload: payload,
    );
  }

  @override
  Future<void> delete(int id) async {
    if (_isOnline) {
      try {
        await _apiRepo.delete(id);
        await _localRepo.delete(id);
        return;
      } catch (e) {
        if (e is ApiException && e.statusCode != null && e.statusCode! >= 400 && e.statusCode! < 500) {
          rethrow;
        }
        _networkMonitor.reportFailure(e);
      }
    }

    await _localRepo.delete(id);
    await _syncEngine.enqueueAction(
      entityType: 'product',
      action: 'delete',
      payload: {'id': id},
    );
  }

  @override
  Future<bool> isSkuTaken(String sku, {int? excludeId}) async {
    if (_isOnline) {
      try {
        return await _apiRepo.isSkuTaken(sku, excludeId: excludeId);
      } catch (_) {
        return _localRepo.isSkuTaken(sku, excludeId: excludeId);
      }
    }
    return _localRepo.isSkuTaken(sku, excludeId: excludeId);
  }

  @override
  Future<bool> isBarcodeTaken(String barcode, {int? excludeId}) async {
    if (_isOnline) {
      try {
        return await _apiRepo.isBarcodeTaken(barcode, excludeId: excludeId);
      } catch (_) {
        return _localRepo.isBarcodeTaken(barcode, excludeId: excludeId);
      }
    }
    return _localRepo.isBarcodeTaken(barcode, excludeId: excludeId);
  }

  @override
  Future<int> countLowStock() async {
    if (_isOnline) {
      try {
        return await _apiRepo.countLowStock();
      } catch (_) {
        return _localRepo.countLowStock();
      }
    }
    return _localRepo.countLowStock();
  }

  @override
  Future<void> refresh() async {
    if (_isOnline) {
      await _apiRepo.refresh();
      final products = await _apiRepo.getAll();
      await _mirrorToLocal(products);
    }
    await _localRepo.refresh();
  }
}
