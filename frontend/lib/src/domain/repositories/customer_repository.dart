import '../models/customer.dart';

abstract interface class CustomerRepository {
  Stream<List<CustomerWithBalance>> watchAll();

  Future<Customer?> findById(int id);

  Future<Customer> create({
    required String name,
    String? phone,
    String? email,
    String? address,
    String? notes,
    int creditLimit = 0,
  });

  Future<void> update(
    int id, {
    required String name,
    String? phone,
    String? email,
    String? address,
    String? notes,
    int? creditLimit,
  });

  Future<void> delete(int id);

  Future<bool> isNameTaken(String name, {int? excludeId});

  /// Outstanding balance for a customer: credit sales minus payments on
  /// account. Minor units (cents).
  Future<int> getBalance(int customerId);

  /// Records a payment towards a customer's account.
  Future<CustomerPayment> recordPayment({
    required int customerId,
    required int amount,
    int? userId,
    String? note,
  });

  Stream<List<CustomerPayment>> watchPayments(int customerId);

  Future<void> refresh();
}
