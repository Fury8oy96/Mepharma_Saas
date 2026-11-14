import '../models/staff_product_feedback.dart';

abstract class StaffFeedbackRepository {
  Stream<List<StaffProductFeedback>> watchBranchFeedbacks({
    int? branchId,
    String? status,
  });

  Future<List<StaffProductFeedback>> getBranchFeedbacks({
    int? branchId,
    String? status,
  });

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
  });

  Future<void> updateStatus(int id, String status);

  Future<void> refresh();
}
