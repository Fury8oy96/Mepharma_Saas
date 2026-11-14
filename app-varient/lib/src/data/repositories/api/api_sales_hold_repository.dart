import 'dart:async';
import 'dart:convert';

import '../../../domain/models/app_sales_hold.dart';
import '../../../domain/repositories/sales_hold_repository.dart';
import '../../../core/services/api_client.dart';
import '../../db/enums.dart';

class ApiSalesHoldRepository implements SalesHoldRepository {
  ApiSalesHoldRepository(this._client) {
    _refreshHolds();
  }

  final ApiClient _client;
  final _allController = StreamController<List<AppSalesHold>>.broadcast();
  List<AppSalesHold> _cachedHolds = [];

  Future<void> _refreshHolds() async {
    try {
      final holds = await _fetchAll();
      _cachedHolds = holds;
      _allController.add(holds);
    } catch (_) {
      _allController.add(_cachedHolds);
    }
  }

  Future<List<AppSalesHold>> _fetchAll() async {
    final response = await _client.get('/sales-holds');
    final data = jsonDecode(response.body) as List;
    return data.map((item) => _mapHold(item as Map<String, dynamic>)).toList();
  }

  AppSalesHold _mapHold(Map<String, dynamic> json) {
    return AppSalesHold(
      id: json['id'] as int,
      holdNumber: json['hold_number'] as String? ?? json['holdNumber'] as String? ?? '',
      userId: json['user_id'] as int? ?? json['userId'] as int? ?? 0,
      itemsJson: json['items_json'] as String? ?? json['itemsJson'] as String? ?? '[]',
      subtotal: json['subtotal'] as int? ?? 0,
      discount: json['discount'] as int? ?? 0,
      discountType: json['discount_type'] != null
          ? DiscountType.values.firstWhere(
              (e) => e.name == (json['discount_type'] as String).toLowerCase(),
              orElse: () => DiscountType.percentage,
            )
          : null,
      totalAmount: json['total_amount'] as int? ?? json['totalAmount'] as int? ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  @override
  Stream<List<AppSalesHold>> watchAll() async* {
    yield _cachedHolds;
    try {
      final holds = await _fetchAll();
      _cachedHolds = holds;
      yield holds;
    } catch (_) {}
    yield* _allController.stream;
  }

  @override
  Future<AppSalesHold> createHold({
    required int userId,
    required String itemsJson,
    required int subtotal,
    required int discount,
    DiscountType? discountType,
    required int totalAmount,
  }) async {
    final response = await _client.post('/sales-holds', body: {
      'user_id': userId,
      'items_json': itemsJson,
      'subtotal': subtotal,
      'discount': discount,
      'discount_type': discountType?.name,
      'total_amount': totalAmount,
    });
    final hold = _mapHold(jsonDecode(response.body) as Map<String, dynamic>);
    _refreshHolds();
    return hold;
  }

  @override
  Future<void> deleteHold(int id) async {
    await _client.delete('/sales-holds/$id');
    _refreshHolds();
  }
}
