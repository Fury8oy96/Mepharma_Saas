import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mepharma/src/data/db/app_database.dart';
import 'package:mepharma/src/data/db/enums.dart';
import 'package:mepharma/src/data/repositories/sqlite_product_repository.dart';
import 'package:mepharma/src/data/repositories/sqlite_staff_feedback_repository.dart';
import 'package:mepharma/src/domain/models/app_user.dart';
import 'package:mepharma/src/domain/models/staff_product_feedback.dart';

void main() {
  late AppDatabase db;
  late SqliteProductRepository productRepo;
  late SqliteStaffFeedbackRepository feedbackRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    productRepo = SqliteProductRepository(db);
    feedbackRepo = SqliteStaffFeedbackRepository(db);
  });

  tearDown(() => db.close());

  group('StaffProductFeedback Domain & Roles', () {
    test('Role permissions scoping', () {
      final staffUser = AppUser(
        id: 10,
        username: 'cashier_sarah',
        role: UserRole.staff,
        isActive: true,
        createdAt: DateTime.now(),
        branchId: 2,
      );

      expect(staffUser.isStaff, isTrue);
      expect(staffUser.isAdmin, isFalse);
      expect(staffUser.isBranchAdmin, isFalse);
      expect(staffUser.isSuperAdmin, isFalse);
      expect(staffUser.branchId, 2);

      final branchAdmin = AppUser(
        id: 2,
        username: 'admin_branch2',
        role: UserRole.branchAdmin,
        isActive: true,
        createdAt: DateTime.now(),
        branchId: 2,
      );

      expect(branchAdmin.isStaff, isFalse);
      expect(branchAdmin.isAdmin, isTrue);
      expect(branchAdmin.isBranchAdmin, isTrue);
      expect(branchAdmin.isSuperAdmin, isFalse);
    });

    test('StaffProductFeedback JSON serialization and helper getters', () {
      final now = DateTime.now();
      final feedback = StaffProductFeedback(
        id: 1,
        productId: 42,
        productName: 'Amoxicillin 500mg',
        productSku: 'AMX-500',
        supplierId: 3,
        supplierName: 'PharmaSupply Ltd',
        currentStock: 0,
        staffUserId: 10,
        staffUsername: 'cashier_sarah',
        branchId: 2,
        urgency: 'urgent',
        suggestedQuantity: 25,
        notes: 'Out of stock, 8 patients requested today',
        status: 'pending',
        createdAt: now,
      );

      expect(feedback.isPending, isTrue);
      expect(feedback.isUrgent, isTrue);
      expect(feedback.isHighDemand, isFalse);
      expect(feedback.isOrdered, isFalse);

      final json = feedback.toJson();
      final restored = StaffProductFeedback.fromJson(json);

      expect(restored.id, feedback.id);
      expect(restored.productName, feedback.productName);
      expect(restored.suggestedQuantity, 25);
      expect(restored.staffUsername, 'cashier_sarah');
      expect(restored.urgency, 'urgent');
    });
  });

  group('SqliteStaffFeedbackRepository Workflow', () {
    test('Submit restock feedback, filter by branch, update status to ordered', () async {
      // 1. Create a product in database
      final product = await productRepo.create(
        sku: 'PAN-500',
        name: 'Panadol Extra 500mg',
        costPrice: 500,
        sellingPrice: 750,
        stockQuantity: 2,
        lowStockThreshold: 10,
      );

      // 2. Staff cashier submits restock recommendation for branch 1
      final feedback = await feedbackRepo.submitFeedback(
        productId: product.id,
        productName: product.name,
        currentStock: product.stockQuantity,
        staffUserId: 10,
        staffUsername: 'cashier_john',
        branchId: 1,
        urgency: 'urgent',
        suggestedQuantity: 30,
        notes: 'Selling rapidly, almost depleted',
      );

      expect(feedback.id, greaterThan(0));
      expect(feedback.status, 'pending');
      expect(feedback.urgency, 'urgent');
      expect(feedback.suggestedQuantity, 30);

      // 3. Query branch 1 pending feedbacks
      final branch1Feedbacks = await feedbackRepo.getBranchFeedbacks(
        branchId: 1,
        status: 'pending',
      );
      expect(branch1Feedbacks.length, 1);
      expect(branch1Feedbacks.first.productName, 'Panadol Extra 500mg');
      expect(branch1Feedbacks.first.currentStock, 2);

      // 4. Other branch (branch 2) should NOT see branch 1 recommendations
      final branch2Feedbacks = await feedbackRepo.getBranchFeedbacks(
        branchId: 2,
        status: 'pending',
      );
      expect(branch2Feedbacks, isEmpty);

      // 5. Branch Admin creates purchase order and marks feedback as ordered
      await feedbackRepo.updateStatus(feedback.id, 'ordered');

      final updatedList = await feedbackRepo.getBranchFeedbacks(
        branchId: 1,
        status: 'pending',
      );
      expect(updatedList, isEmpty);

      final allBranch1 = await feedbackRepo.getBranchFeedbacks(
        branchId: 1,
        status: 'all',
      );
      expect(allBranch1.length, 1);
      expect(allBranch1.first.status, 'ordered');
    });

    test('Dismiss restock recommendation', () async {
      final feedback = await feedbackRepo.submitFeedback(
        productName: 'Vitamin C 1000mg',
        currentStock: 15,
        branchId: 1,
        urgency: 'normal',
        suggestedQuantity: 10,
      );

      expect(feedback.isPending, isTrue);

      await feedbackRepo.updateStatus(feedback.id, 'dismissed');

      final pending = await feedbackRepo.getBranchFeedbacks(
        branchId: 1,
        status: 'pending',
      );
      expect(pending, isEmpty);
    });
  });
}
