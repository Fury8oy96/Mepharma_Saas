import '../../data/db/enums.dart';
import '../models/app_sales_hold.dart';

abstract interface class SalesHoldRepository {
  Stream<List<AppSalesHold>> watchAll();

  Future<AppSalesHold> createHold({
    required int userId,
    required String itemsJson,
    required int subtotal,
    required int discount,
    DiscountType? discountType,
    required int totalAmount,
  });

  Future<void> deleteHold(int id);
}
