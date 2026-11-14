import 'dart:async';

import '../../core/services/network_monitor.dart';
import '../../core/services/sync_engine.dart';
import '../../domain/models/staff_product_feedback.dart';
import '../../domain/repositories/staff_feedback_repository.dart';
import 'api/api_staff_feedback_repository.dart';
import 'sqlite_staff_feedback_repository.dart';

class OfflineFirstStaffFeedbackRepository implements StaffFeedbackRepository {
  OfflineFirstStaffFeedbackRepository({
    required ApiStaffFeedbackRepository apiRepo,
    required SqliteStaffFeedbackRepository localRepo,
    SyncEngine? syncEngine,
    required NetworkMonitor networkMonitor,
  })  : _apiRepo = apiRepo,
        _localRepo = localRepo,
        _networkMonitor = networkMonitor;

  final ApiStaffFeedbackRepository _apiRepo;
  final SqliteStaffFeedbackRepository _localRepo;
  final NetworkMonitor _networkMonitor;

  bool get _isOnline => _networkMonitor.isOnline;

  @override
  Stream<List<StaffProductFeedback>> watchBranchFeedbacks({
    int? branchId,
    String? status,
  }) async* {
    if (_isOnline) {
      try {
        final serverList = await _apiRepo.getBranchFeedbacks(
          branchId: branchId,
          status: status,
        );
        _mirrorToLocal(serverList);
      } catch (_) {}
      yield* _apiRepo.watchBranchFeedbacks(branchId: branchId, status: status);
    } else {
      yield* _localRepo.watchBranchFeedbacks(branchId: branchId, status: status);
    }
  }

  Future<void> _mirrorToLocal(List<StaffProductFeedback> list) async {
    for (final item in list) {
      try {
        final local = await _localRepo.getBranchFeedbacks(branchId: item.branchId);
        final exists = local.any((f) => f.id == item.id);
        if (!exists) {
          await _localRepo.submitFeedback(
            productId: item.productId,
            productName: item.productName,
            currentStock: item.currentStock,
            staffUserId: item.staffUserId,
            staffUsername: item.staffUsername,
            branchId: item.branchId,
            urgency: item.urgency,
            suggestedQuantity: item.suggestedQuantity,
            notes: item.notes,
          );
        } else {
          await _localRepo.updateStatus(item.id, item.status);
        }
      } catch (_) {}
    }
  }

  @override
  Future<List<StaffProductFeedback>> getBranchFeedbacks({
    int? branchId,
    String? status,
  }) async {
    if (_isOnline) {
      try {
        final remote = await _apiRepo.getBranchFeedbacks(
          branchId: branchId,
          status: status,
        );
        _mirrorToLocal(remote);
        return remote;
      } catch (_) {
        return _localRepo.getBranchFeedbacks(branchId: branchId, status: status);
      }
    }
    return _localRepo.getBranchFeedbacks(branchId: branchId, status: status);
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
    if (_isOnline) {
      try {
        final feedback = await _apiRepo.submitFeedback(
          productId: productId,
          productName: productName,
          currentStock: currentStock,
          staffUserId: staffUserId,
          staffUsername: staffUsername,
          branchId: branchId,
          urgency: urgency,
          suggestedQuantity: suggestedQuantity,
          notes: notes,
        );
        // Also mirror to local
        try {
          await _localRepo.submitFeedback(
            productId: feedback.productId,
            productName: feedback.productName,
            currentStock: feedback.currentStock,
            staffUserId: feedback.staffUserId,
            staffUsername: feedback.staffUsername,
            branchId: feedback.branchId,
            urgency: feedback.urgency,
            suggestedQuantity: feedback.suggestedQuantity,
            notes: feedback.notes,
          );
        } catch (_) {}
        return feedback;
      } catch (_) {
        // Fallback to local below
      }
    }

    final localFeedback = await _localRepo.submitFeedback(
      productId: productId,
      productName: productName,
      currentStock: currentStock,
      staffUserId: staffUserId,
      staffUsername: staffUsername,
      branchId: branchId,
      urgency: urgency,
      suggestedQuantity: suggestedQuantity,
      notes: notes,
    );
    return localFeedback;
  }

  @override
  Future<void> updateStatus(int id, String status) async {
    await _localRepo.updateStatus(id, status);
    if (_isOnline) {
      try {
        await _apiRepo.updateStatus(id, status);
      } catch (_) {}
    }
  }

  @override
  Future<void> refresh() async {
    if (_isOnline) {
      try {
        await _apiRepo.refresh();
      } catch (_) {}
    }
    await _localRepo.refresh();
  }
}
