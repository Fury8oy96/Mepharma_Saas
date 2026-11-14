import 'dart:async';
import 'dart:convert';

import '../../../core/services/api_client.dart';
import '../../../domain/models/staff_product_feedback.dart';
import '../../../domain/repositories/staff_feedback_repository.dart';

class ApiStaffFeedbackRepository implements StaffFeedbackRepository {
  ApiStaffFeedbackRepository(this._client) {
    refresh();
  }

  final ApiClient _client;
  final _feedbacksController =
      StreamController<List<StaffProductFeedback>>.broadcast();
  List<StaffProductFeedback> _cachedFeedbacks = [];

  @override
  Stream<List<StaffProductFeedback>> watchBranchFeedbacks({
    int? branchId,
    String? status,
  }) async* {
    yield _filterFeedbacks(_cachedFeedbacks, branchId: branchId, status: status);
    yield* _feedbacksController.stream.map(
      (list) => _filterFeedbacks(list, branchId: branchId, status: status),
    );
  }

  List<StaffProductFeedback> _filterFeedbacks(
    List<StaffProductFeedback> list, {
    int? branchId,
    String? status,
  }) {
    return list.where((item) {
      if (branchId != null && item.branchId != branchId) return false;
      if (status != null && status != 'all' && item.status != status) return false;
      return true;
    }).toList();
  }

  @override
  Future<List<StaffProductFeedback>> getBranchFeedbacks({
    int? branchId,
    String? status,
  }) async {
    final queryParams = <String, String>{};
    if (branchId != null) queryParams['branch_id'] = branchId.toString();
    if (status != null && status != 'all') queryParams['status'] = status;

    final uri = Uri(
      path: '/staff-feedbacks',
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );

    final response = await _client.get(uri.toString());
    final data = jsonDecode(response.body) as List;
    final feedbacks = data
        .map((item) => StaffProductFeedback.fromJson(item as Map<String, dynamic>))
        .toList();
    _cachedFeedbacks = feedbacks;
    _feedbacksController.add(feedbacks);
    return feedbacks;
  }

  @override
  Future<StaffProductFeedback> submitFeedback({
    int? productId,
    required String productName,
    int currentStock = 0,
    int? staffUserId,
    String staffUsername = 'Staff',
    int branchId = 1,
    String urgency = 'normal',
    int suggestedQuantity = 10,
    String? notes,
  }) async {
    final response = await _client.post(
      '/staff-feedbacks',
      body: {
        'product_id': productId,
        'product_name': productName,
        'current_stock': currentStock,
        'staff_user_id': staffUserId,
        'staff_username': staffUsername,
        'branch_id': branchId,
        'urgency': urgency,
        'suggested_quantity': suggestedQuantity,
        'notes': notes,
      },
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final created = StaffProductFeedback.fromJson(data);
    await refresh();
    return created;
  }

  @override
  Future<void> updateStatus(int id, String status) async {
    await _client.patch(
      '/staff-feedbacks/$id',
      body: {'status': status},
    );
    await refresh();
  }

  @override
  Future<void> refresh() async {
    try {
      final response = await _client.get('/staff-feedbacks');
      final data = jsonDecode(response.body) as List;
      _cachedFeedbacks = data
          .map((item) => StaffProductFeedback.fromJson(item as Map<String, dynamic>))
          .toList();
      _feedbacksController.add(_cachedFeedbacks);
    } catch (_) {
      _feedbacksController.add(_cachedFeedbacks);
    }
  }
}
