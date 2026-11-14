import 'dart:async';
import 'dart:convert';

import '../../../domain/models/app_product.dart';
import '../../../domain/repositories/product_repository.dart';
import '../../../core/services/api_client.dart';

class ApiProductRepository implements ProductRepository {
  ApiProductRepository(this._client) {
    _refreshAll();
  }

  final ApiClient _client;
  final _allController = StreamController<List<AppProduct>>.broadcast();
  List<AppProduct> _cachedProducts = [];

  Future<void> _refreshAll() async {
    try {
      final products = await getAll();
      _cachedProducts = products;
      if (!_allController.isClosed) {
        _allController.add(products);
      }
    } catch (_) {
      if (!_allController.isClosed) {
        _allController.add(_cachedProducts);
      }
    }
  }

  AppProduct _mapProduct(Map<String, dynamic> json) {
    final rawId = json['id'];
    final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '0') ?? 0;
    
    final rawCat = json['category_id'] ?? json['categoryId'];
    final categoryId = rawCat is int ? rawCat : int.tryParse(rawCat?.toString() ?? '');

    final rawSup = json['supplier_id'] ?? json['supplierId'];
    final supplierId = rawSup is int ? rawSup : int.tryParse(rawSup?.toString() ?? '');

    final rawCost = json['cost_price'] ?? json['costPrice'];
    final costPrice = rawCost is int ? rawCost : int.tryParse(rawCost?.toString() ?? '0') ?? 0;

    final rawSell = json['selling_price'] ?? json['sellingPrice'];
    final sellingPrice = rawSell is int ? rawSell : int.tryParse(rawSell?.toString() ?? '0') ?? 0;

    final rawStock = json['stock_quantity'] ?? json['stockQuantity'];
    final stockQuantity = rawStock is int ? rawStock : int.tryParse(rawStock?.toString() ?? '0') ?? 0;

    final rawLow = json['low_stock_threshold'] ?? json['lowStockThreshold'];
    final lowStockThreshold = rawLow is int ? rawLow : int.tryParse(rawLow?.toString() ?? '10') ?? 10;

    return AppProduct(
      id: id,
      sku: json['sku'] as String? ?? '',
      barcode: json['barcode'] as String?,
      name: json['name'] as String? ?? '',
      categoryId: categoryId,
      supplierId: supplierId,
      costPrice: costPrice,
      sellingPrice: sellingPrice,
      stockQuantity: stockQuantity,
      lowStockThreshold: lowStockThreshold,
      expiryDate: json['expiry_date'] != null
          ? DateTime.tryParse(json['expiry_date'].toString())
          : json['expiryDate'] != null
              ? DateTime.tryParse(json['expiryDate'].toString())
              : null,
      description: json['description'] as String?,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  @override
  Stream<List<AppProduct>> watchAll() async* {
    yield _cachedProducts;
    try {
      final products = await getAll();
      _cachedProducts = products;
      yield products;
    } catch (_) {}
    yield* _allController.stream;
  }

  @override
  Stream<List<AppProduct>> watchLowStock() async* {
    yield _cachedProducts.where((p) => p.isLowStock).toList();
    yield* _allController.stream.map(
      (list) => list.where((p) => p.isLowStock).toList(),
    );
  }

  @override
  Stream<List<AppProduct>> watchExpiring({required int withinDays}) async* {
    final list = _cachedProducts.where((p) => p.isExpiringWithin(withinDays)).toList();
    list.sort((a, b) {
      if (a.expiryDate == null) return 1;
      if (b.expiryDate == null) return -1;
      return a.expiryDate!.compareTo(b.expiryDate!);
    });
    yield list;
    yield* _allController.stream.map((list) {
      final expiring = list.where((p) => p.isExpiringWithin(withinDays)).toList();
      expiring.sort((a, b) {
        if (a.expiryDate == null) return 1;
        if (b.expiryDate == null) return -1;
        return a.expiryDate!.compareTo(b.expiryDate!);
      });
      return expiring;
    });
  }

  @override
  Future<List<AppProduct>> getAll() async {
    final response = await _client.get('/products');
    final data = jsonDecode(response.body) as List;
    return data.map((item) => _mapProduct(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<AppProduct>> search(String query) async {
    final response = await _client.get('/products?search=${Uri.encodeQueryComponent(query)}');
    final data = jsonDecode(response.body) as List;
    return data.map((item) => _mapProduct(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<AppProduct?> findById(int id) async {
    try {
      final response = await _client.get('/products/$id');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return _mapProduct(data);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<AppProduct?> findBySku(String sku) async {
    try {
      final response = await _client.get('/products/sku/${Uri.encodeQueryComponent(sku)}');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return _mapProduct(data);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<AppProduct?> findByBarcode(String barcode) async {
    try {
      final response = await _client.get('/products/barcode/${Uri.encodeQueryComponent(barcode)}');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return _mapProduct(data);
    } catch (_) {
      return null;
    }
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
    final response = await _client.post('/products', body: {
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
    });
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final product = _mapProduct(data);
    await _refreshAll();
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
    final body = <String, dynamic>{
      'name': name,
    };
    if (barcode != null) body['barcode'] = barcode;
    if (categoryId != null) body['category_id'] = categoryId;
    if (supplierId != null) body['supplier_id'] = supplierId;
    if (costPrice != null) body['cost_price'] = costPrice;
    if (sellingPrice != null) body['selling_price'] = sellingPrice;
    if (lowStockThreshold != null) body['low_stock_threshold'] = lowStockThreshold;
    if (expiryDate != null) body['expiry_date'] = expiryDate.toIso8601String();
    if (description != null) body['description'] = description;

    await _client.put('/products/$id', body: body);
    await _refreshAll();
  }

  @override
  Future<void> delete(int id) async {
    await _client.delete('/products/$id');
    await _refreshAll();
  }

  @override
  Future<bool> isSkuTaken(String sku, {int? excludeId}) async {
    try {
      final response = await _client.get('/products/check-sku?sku=${Uri.encodeQueryComponent(sku)}&exclude_id=${excludeId ?? ""}');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['taken'] as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> isBarcodeTaken(String barcode, {int? excludeId}) async {
    try {
      final response = await _client.get('/products/check-barcode?barcode=${Uri.encodeQueryComponent(barcode)}&exclude_id=${excludeId ?? ""}');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['taken'] as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<int> countLowStock() async {
    try {
      final response = await _client.get('/products/count-low-stock');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['count'] as int? ?? 0;
    } catch (_) {
      return _cachedProducts.where((p) => p.isLowStock).length;
    }
  }

  @override
  Future<void> refresh() async {
    await _refreshAll();
  }
}
