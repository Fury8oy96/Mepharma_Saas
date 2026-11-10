import 'dart:convert';

import '../../../domain/models/app_return.dart';
import '../../../domain/repositories/return_repository.dart';
import '../../../core/services/api_client.dart';

class ApiReturnRepository implements ReturnRepository {
  ApiReturnRepository(this._client);

  final ApiClient _client;

  AppReturn _mapReturn(Map<String, dynamic> json) {
    return AppReturn(
      id: json['id'] as int,
      saleId: json['sale_id'] as int? ?? json['saleId'] as int? ?? 0,
      invoiceNumber: json['invoice_number'] as String? ?? json['invoiceNumber'] as String? ?? '',
      userId: json['user_id'] as int? ?? json['userId'] as int? ?? 0,
      totalRefund: json['total_refund'] as int? ?? json['totalRefund'] as int? ?? 0,
      reason: json['reason'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  AppReturnItem _mapReturnItem(Map<String, dynamic> json) {
    return AppReturnItem(
      id: json['id'] as int,
      returnId: json['return_id'] as int? ?? json['returnId'] as int? ?? 0,
      saleItemId: json['sale_item_id'] as int? ?? json['saleItemId'] as int?,
      productId: json['product_id'] as int? ?? json['productId'] as int?,
      productName: json['product_name'] as String? ?? json['productName'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 0,
      unitPrice: json['unit_price'] as int? ?? json['unitPrice'] as int? ?? 0,
      totalRefund: json['total_refund'] as int? ?? json['totalRefund'] as int? ?? 0,
    );
  }

  @override
  Future<AppReturn> createReturn({
    required int saleId,
    required int userId,
    String? reason,
    required List<ReturnLineInput> items,
  }) async {
    final bodyItems = items.map((i) => {
      'sale_item_id': i.saleItemId,
      'product_id': i.productId,
      'product_name': i.productName,
      'unit_price': i.unitPrice,
      'quantity': i.quantity,
    }).toList();

    final response = await _client.post('/returns', body: {
      'sale_id': saleId,
      'user_id': userId,
      'reason': reason,
      'items': bodyItems,
    });

    return _mapReturn(jsonDecode(response.body) as Map<String, dynamic>);
  }

  @override
  Future<List<AppReturn>> getReturnsForSale(int saleId) async {
    final response = await _client.get('/sales/$saleId/returns');
    final data = jsonDecode(response.body) as List;
    return data.map((item) => _mapReturn(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<AppReturnItem>> getReturnItemsForSale(int saleId) async {
    final response = await _client.get('/sales/$saleId/return-items');
    final data = jsonDecode(response.body) as List;
    return data.map((item) => _mapReturnItem(item as Map<String, dynamic>)).toList();
  }
}
