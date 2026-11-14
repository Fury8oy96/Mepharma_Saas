import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mepharma/src/data/db/app_database.dart';
import 'package:mepharma/src/data/db/enums.dart';
import 'package:mepharma/src/data/repositories/sqlite_product_repository.dart';
import 'package:mepharma/src/data/repositories/sqlite_return_repository.dart';
import 'package:mepharma/src/data/repositories/sqlite_sale_repository.dart';
import 'package:mepharma/src/data/repositories/sqlite_user_repository.dart';
import 'package:mepharma/src/domain/models/sale_receipt.dart';
import 'package:mepharma/src/domain/repositories/return_repository.dart';
import 'package:mepharma/src/presentation/shell/navigation.dart';

void main() {
  late AppDatabase db;
  late SqliteProductRepository productRepo;
  late SqliteSaleRepository saleRepo;
  late SqliteReturnRepository returnRepo;
  late SqliteUserRepository userRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    productRepo = SqliteProductRepository(db);
    saleRepo = SqliteSaleRepository(db);
    returnRepo = SqliteReturnRepository(db);
    userRepo = SqliteUserRepository(db);
  });

  tearDown(() => db.close());

  group('Variant Features Tests (Open Pricing & Unrestricted Returns)', () {
    test('Open Pricing: Products can be created and updated with arbitrary user selling prices', () async {
      // User specifies Cost = 1500, Selling Price = 7500 (completely arbitrary, not 1500 * 1.3 = 1950)
      final created = await productRepo.create(
        sku: 'CUSTOM-PRICE-001',
        name: 'Custom Price Drug',
        costPrice: 1500,
        sellingPrice: 7500,
        stockQuantity: 50,
      );

      expect(created.costPrice, equals(1500));
      expect(created.sellingPrice, equals(7500));

      // User updates selling price freely to 6200 without changing cost
      await productRepo.update(
        created.id,
        name: created.name,
        costPrice: 1500,
        sellingPrice: 6200,
      );

      final updated = (await productRepo.findById(created.id))!;
      expect(updated.costPrice, equals(1500));
      expect(updated.sellingPrice, equals(6200));
    });

    test('Unrestricted Sales Return: Non-admin staff can process return and restock inventory', () async {
      // Create staff user
      final staff = await userRepo.createUser(
        username: 'cashier_sam',
        password: 'password123',
        role: UserRole.staff,
      );
      expect(staff.role, equals(UserRole.staff));
      expect(staff.role.isAnyAdmin, isFalse);

      // Create product with initial stock = 20
      final product = await productRepo.create(
        sku: 'MED-RETURN-TEST',
        name: 'Returnable Medicine',
        costPrice: 1000,
        sellingPrice: 2500,
        stockQuantity: 20,
      );

      // Complete a sale of 5 units (stock becomes 15)
      final receipt = await saleRepo.completeSale(
        items: [
          SaleLineItem(
            productId: product.id,
            productName: product.name,
            quantity: 5,
            unitPrice: 2500,
            totalPrice: 12500,
          ),
        ],
        subtotal: 12500,
        discount: 0,
        taxAmount: 0,
        totalAmount: 12500,
        paidAmount: 12500,
        changeAmount: 0,
        paymentMethod: 'cash',
        userId: staff.id,
      );

      final afterSaleProduct = (await productRepo.findById(product.id))!;
      expect(afterSaleProduct.stockQuantity, equals(15));

      final saleDetail = await saleRepo.getSaleDetail(receipt.id);
      final saleItemId = saleDetail.items.first.id;

      // Staff user processes return of 2 units directly
      final processedReturn = await returnRepo.createReturn(
        saleId: receipt.id,
        userId: staff.id,
        reason: 'Customer requested refund - defective batch',
        items: [
          ReturnLineInput(
            saleItemId: saleItemId,
            productId: product.id,
            productName: product.name,
            unitPrice: 2500,
            quantity: 2,
          ),
        ],
      );

      expect(processedReturn.totalRefund, equals(5000));
      expect(processedReturn.userId, equals(staff.id));

      // Verify inventory is restocked by 2 (15 + 2 = 17)
      final afterReturnProduct = (await productRepo.findById(product.id))!;
      expect(afterReturnProduct.stockQuantity, equals(17));

      // Verify watchAllReturns streams this return
      final allReturns = await returnRepo.watchAllReturns().first;
      expect(allReturns.length, equals(1));
      expect(allReturns.first.id, equals(processedReturn.id));
      expect(allReturns.first.invoiceNumber, equals(receipt.invoiceNumber));
    });

    test('Sidebar Navigation: Returns section is exposed under Operations and visible to all roles', () {
      final returnsSection = appSections.firstWhere((s) => s.path == '/returns');
      expect(returnsSection.name, equals('returns'));
      expect(returnsSection.category, equals(NavigationCategory.operations));
      expect(returnsSection.adminOnly, isFalse);
      expect(returnsSection.superAdminOnly, isFalse);

      // Visible to staff, branchAdmin, and superAdmin
      expect(returnsSection.isVisibleTo(UserRole.staff), isTrue);
      expect(returnsSection.isVisibleTo(UserRole.branchAdmin), isTrue);
      expect(returnsSection.isVisibleTo(UserRole.superAdmin), isTrue);
    });
  });
}
