import 'package:drift/drift.dart';

import '../../domain/models/staff_product_feedback.dart';
import '../../domain/repositories/staff_feedback_repository.dart';
import '../db/app_database.dart';

class SqliteStaffFeedbackRepository implements StaffFeedbackRepository {
  SqliteStaffFeedbackRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<StaffProductFeedback>> watchBranchFeedbacks({
    int? branchId,
    String? status,
  }) {
    final query = _db.select(_db.staffProductFeedbacks)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

    if (branchId != null) {
      query.where((t) => t.branchId.equals(branchId));
    }
    if (status != null && status != 'all') {
      query.where((t) => t.status.equals(status));
    }

    return query.watch().map((rows) => rows.map(_mapToDomain).toList());
  }

  @override
  Future<List<StaffProductFeedback>> getBranchFeedbacks({
    int? branchId,
    String? status,
  }) async {
    final query = _db.select(_db.staffProductFeedbacks)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

    if (branchId != null) {
      query.where((t) => t.branchId.equals(branchId));
    }
    if (status != null && status != 'all') {
      query.where((t) => t.status.equals(status));
    }

    final rows = await query.get();
    return rows.map(_mapToDomain).toList();
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
    final now = DateTime.now();
    final companion = StaffProductFeedbacksCompanion.insert(
      productId: Value(productId),
      productName: productName,
      currentStock: Value(currentStock),
      staffUserId: Value(staffUserId),
      staffUsername: Value(staffUsername),
      branchId: Value(branchId),
      urgency: Value(urgency),
      suggestedQuantity: Value(suggestedQuantity),
      notes: Value(notes),
      status: const Value('pending'),
      createdAt: Value(now),
    );

    final id = await _db.into(_db.staffProductFeedbacks).insert(companion);
    return StaffProductFeedback(
      id: id,
      productId: productId,
      productName: productName,
      currentStock: currentStock,
      staffUserId: staffUserId,
      staffUsername: staffUsername,
      branchId: branchId,
      urgency: urgency,
      suggestedQuantity: suggestedQuantity,
      notes: notes,
      status: 'pending',
      createdAt: now,
    );
  }

  @override
  Future<void> updateStatus(int id, String status) async {
    await (_db.update(_db.staffProductFeedbacks)..where((t) => t.id.equals(id)))
        .write(StaffProductFeedbacksCompanion(
      status: Value(status),
    ));
  }

  @override
  Future<void> refresh() async {
    // No-op for local database
  }

  StaffProductFeedback _mapToDomain(StaffProductFeedbackRow row) {
    return StaffProductFeedback(
      id: row.id,
      productId: row.productId,
      productName: row.productName,
      currentStock: row.currentStock,
      staffUserId: row.staffUserId,
      staffUsername: row.staffUsername,
      branchId: row.branchId,
      urgency: row.urgency,
      suggestedQuantity: row.suggestedQuantity,
      notes: row.notes,
      status: row.status,
      createdAt: row.createdAt,
    );
  }
}
