import 'dart:async';
import 'dart:convert';

import '../../../domain/models/app_purchase.dart';
import '../../../domain/repositories/purchase_repository.dart';
import '../../../core/services/api_client.dart';

class ApiPurchaseRepository implements PurchaseRepository {
  ApiPurchaseRepository(this._client) {
    _initStream();
  }

  final ApiClient _client;
  final _purchasesController = StreamController<List<AppPurchase>>.broadcast();
  List<AppPurchase> _cachedPurchases = [];

  void _initStream() {
    _purchasesController.onListen = () {
      _refreshPurchases();
    };
  }

  Future<void> _refreshPurchases() async {
    try {
      final purchases = await _fetchPurchases();
      _cachedPurchases = purchases;
      if (!_purchasesController.isClosed) {
        _purchasesController.add(purchases);
      }
    } catch (_) {
      if (!_purchasesController.isClosed) {
        _purchasesController.add(_cachedPurchases);
      }
    }
  }

  Future<List<AppPurchase>> _fetchPurchases() async {
    final response = await _client.get('/purchases');
    final data = jsonDecode(response.body) as List;
    return data.map((item) => _mapPurchase(item as Map<String, dynamic>)).toList();
  }

  AppPurchase _mapPurchase(Map<String, dynamic> json) {
    final rawId = json['id'];
    final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '0') ?? 0;
    
    final rawSup = json['supplier_id'] ?? json['supplierId'];
    final supplierId = rawSup is int ? rawSup : int.tryParse(rawSup?.toString() ?? '');

    final rawUser = json['user_id'] ?? json['userId'];
    final userId = rawUser is int ? rawUser : int.tryParse(rawUser?.toString() ?? '0') ?? 0;

    final rawTotal = json['total_amount'] ?? json['totalAmount'];
    final totalAmount = rawTotal is int ? rawTotal : int.tryParse(rawTotal?.toString() ?? '0') ?? 0;

    return AppPurchase(
      id: id,
      invoiceNumber: json['invoice_number'] as String? ?? json['invoiceNumber'] as String? ?? '',
      transactionReference: json['transaction_reference'] as String? ?? json['transactionReference'] as String?,
      supplierId: supplierId,
      userId: userId,
      totalAmount: totalAmount,
      purchaseDate: DateTime.tryParse(json['purchase_date'] as String? ?? json['purchaseDate'] as String? ?? '') ?? DateTime.now(),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? json['createdAt'] as String? ?? '') ?? DateTime.now(),
      status: PurchaseStatus.values.firstWhere(
        (e) => e.name == (json['status'] as String? ?? '').toLowerCase(),
        orElse: () => PurchaseStatus.pending,
      ),
    );
  }

  AppPurchaseItem _mapItem(Map<String, dynamic> json) {
    final rawId = json['id'];
    final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '0') ?? 0;

    final rawPId = json['purchase_id'] ?? json['purchaseId'];
    final purchaseId = rawPId is int ? rawPId : int.tryParse(rawPId?.toString() ?? '0') ?? 0;

    final rawProdId = json['product_id'] ?? json['productId'];
    final productId = rawProdId is int ? rawProdId : int.tryParse(rawProdId?.toString() ?? '');

    final rawQty = json['quantity'];
    final quantity = rawQty is int ? rawQty : int.tryParse(rawQty?.toString() ?? '0') ?? 0;

    final rawCost = json['cost_price'] ?? json['costPrice'] ?? json['unit_cost'] ?? json['unitCost'];
    final costPrice = rawCost is int ? rawCost : int.tryParse(rawCost?.toString() ?? '0') ?? 0;

    final rawTotal = json['total_cost'] ?? json['totalCost'];
    final totalCost = rawTotal is int ? rawTotal : int.tryParse(rawTotal?.toString() ?? '0') ?? 0;

    return AppPurchaseItem(
      id: id,
      purchaseId: purchaseId,
      productId: productId,
      productName: json['product_name'] as String? ?? json['productName'] as String? ?? '',
      quantity: quantity,
      costPrice: costPrice,
      totalCost: totalCost,
    );
  }

  @override
  Future<String> generatePurchaseNumber() async {
    try {
      final response = await _client.get('/purchases/next-number');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['number'] as String;
    } catch (_) {
      final stamp = DateTime.now().toString().replaceAll('-', '').split(' ').first;
      final seq = _cachedPurchases.length + 1;
      return 'PUR-$stamp-${seq.toString().padLeft(4, '0')}';
    }
  }

  @override
  Future<AppPurchase> createPurchase({
    int? supplierId,
    required int userId,
    required DateTime purchaseDate,
    required List<PurchaseLineInput> items,
    bool autoApprove = true,
    String? transactionReference,
  }) async {
    final bodyItems = items.map((i) => {
      'product_id': (i.productId == 0 || i.productId == null) ? null : i.productId,
      'product_name': i.productName,
      'quantity': i.quantity,
      'cost_price': i.costPrice,
    }).toList();

    final response = await _client.post('/purchases', body: {
      'supplier_id': supplierId,
      'user_id': userId,
      'purchase_date': purchaseDate.toIso8601String().split('T').first,
      'transaction_reference': transactionReference,
      'items': bodyItems,
    });

    final purchase = _mapPurchase(jsonDecode(response.body) as Map<String, dynamic>);
    await _refreshPurchases();
    return purchase;
  }

  @override
  Future<void> approvePurchase(int id) async {
    await _client.put('/purchases/$id/approve');
    await _refreshPurchases();
  }

  @override
  Stream<List<AppPurchase>> watchPurchases() async* {
    yield _cachedPurchases;
    yield* _purchasesController.stream;
  }

  @override
  Future<PurchaseDetail> getPurchaseDetail(int id) async {
    final response = await _client.get('/purchases/$id');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final purchase = _mapPurchase(data['purchase'] as Map<String, dynamic>);
    final itemsList = data['items'] as List;
    final items = itemsList.map((i) => _mapItem(i as Map<String, dynamic>)).toList();
    return PurchaseDetail(purchase: purchase, items: items);
  }

  @override
  Future<void> refresh() async {
    await _refreshPurchases();
  }
}
