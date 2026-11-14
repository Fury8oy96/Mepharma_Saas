import 'dart:async';
import 'dart:convert';

import '../../../domain/models/app_stock_adjustment.dart';
import '../../../domain/repositories/stock_adjustment_repository.dart';
import '../../../core/services/api_client.dart';

class ApiStockAdjustmentRepository implements StockAdjustmentRepository {
  ApiStockAdjustmentRepository(this._client);

  final ApiClient _client;

  AppStockAdjustment _mapAdjustment(Map<String, dynamic> json) {
    return AppStockAdjustment(
      id: json['id'] as int,
      productId: json['product_id'] as int? ?? json['productId'] as int? ?? 0,
      adjustmentQuantity: json['adjustment_quantity'] as int? ?? json['adjustmentQuantity'] as int? ?? 0,
      reason: json['reason'] as String?,
      reference: json['reference'] as String?,
      userId: json['user_id'] as int? ?? json['userId'] as int?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  @override
  Stream<List<AppStockAdjustment>> watchForProduct(int productId) {
    final controller = StreamController<List<AppStockAdjustment>>();
    Timer? timer;

    Future<void> fetch() async {
      try {
        final response = await _client.get('/products/$productId/adjustments');
        final data = jsonDecode(response.body) as List;
        final list = data.map((item) => _mapAdjustment(item as Map<String, dynamic>)).toList();
        if (!controller.isClosed) {
          controller.add(list);
        }
      } catch (_) {}
    }

    controller.onListen = () {
      fetch();
      timer = Timer.periodic(const Duration(seconds: 5), (_) => fetch());
    };

    controller.onCancel = () {
      timer?.cancel();
      controller.close();
    };

    return controller.stream;
  }

  @override
  Future<List<AppStockAdjustment>> getAll() async {
    final response = await _client.get('/stock-adjustments');
    final data = jsonDecode(response.body) as List;
    return data.map((item) => _mapAdjustment(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> adjustStock({
    required int productId,
    required int adjustmentQuantity,
    String? reason,
    String? reference,
    int? userId,
  }) async {
    await _client.post('/stock-adjustments', body: {
      'product_id': productId,
      'adjustment_quantity': adjustmentQuantity,
      'reason': reason,
      'reference': reference,
      'user_id': userId,
    });
  }
}
