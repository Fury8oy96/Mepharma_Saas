import 'package:drift/drift.dart';

import '../../core/utils/stream_utils.dart';
import '../../domain/models/customer.dart';
import '../../domain/repositories/customer_repository.dart';
import '../db/app_database.dart' hide Customer, CustomerPayment;
import '../db/app_database.dart' as db show Customer, CustomerPayment;
import '../db/enums.dart';

class SqliteCustomerRepository implements CustomerRepository {
  SqliteCustomerRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<CustomerWithBalance>> watchAll() {
    final customers = _db.select(_db.customers)
      ..orderBy([(c) => OrderingTerm(expression: c.name)]);

    final creditQuery = _db.select(_db.sales)
      ..where((s) =>
          s.customerId.isNotNull() &
          s.status.equals(SaleStatus.completed.name))
      ..orderBy([(s) => OrderingTerm.asc(s.id)]);

    final paymentsQuery = _db.select(_db.customerPayments);

    final refundsQuery = _db.select(_db.returns);

    return combineLatestStream([
      customers.watch(),
      creditQuery.watch(),
      paymentsQuery.watch(),
      refundsQuery.watch(),
    ]).map((values) => _withBalances(
          values[0] as List<db.Customer>,
          values[1] as List<Sale>,
          values[2] as List<db.CustomerPayment>,
          values[3] as List<Return>,
        ));
  }

  @override
  Future<Customer?> findById(int id) async {
    final row = await (_db.select(_db.customers)
          ..where((c) => c.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _map(row);
  }

  @override
  Future<Customer> create({
    required String name,
    String? phone,
    String? email,
    String? address,
    String? notes,
    int creditLimit = 0,
  }) async {
    final id = await _db.into(_db.customers).insert(
          CustomersCompanion.insert(
            name: name,
            phone: Value(phone),
            email: Value(email),
            address: Value(address),
            notes: Value(notes),
            creditLimit: Value(creditLimit),
          ),
        );
    return (await findById(id))!;
  }

  @override
  Future<void> update(
    int id, {
    required String name,
    String? phone,
    String? email,
    String? address,
    String? notes,
    int? creditLimit,
  }) async {
    await (_db.update(_db.customers)..where((c) => c.id.equals(id))).write(
      CustomersCompanion(
        name: Value(name),
        phone: Value(phone),
        email: Value(email),
        address: Value(address),
        notes: Value(notes),
        creditLimit: Value(creditLimit ?? 0),
      ),
    );
  }

  @override
  Future<void> delete(int id) async {
    await _db.transaction(() async {
      // Keep the sale references but drop the link so sales history remains
      // intact. Payments are removed explicitly rather than relying on the
      // database foreign-key cascade (foreign keys may be disabled).
      await (_db.delete(_db.customerPayments)
            ..where((p) => p.customerId.equals(id)))
          .go();
      await (_db.update(_db.sales)..where((s) => s.customerId.equals(id)))
          .write(const SalesCompanion(customerId: Value(null)));
      await (_db.delete(_db.customers)..where((c) => c.id.equals(id))).go();
    });
  }

  @override
  Future<bool> isNameTaken(String name, {int? excludeId}) async {
    final rows = await (_db.select(_db.customers)
          ..where((c) => excludeId == null
              ? c.name.lower().equals(name.toLowerCase())
              : c.name.lower().equals(name.toLowerCase()) &
                  c.id.equals(excludeId).not()))
        .get();
    return rows.isNotEmpty;
  }

  @override
  Future<int> getBalance(int customerId) async {
    final sales = await (_db.select(_db.sales)
          ..where((s) =>
              s.customerId.equals(customerId) &
              s.status.equals(SaleStatus.completed.name)))
        .get();
    final saleIds = sales.map((s) => s.id).toList();
    final refundRows = saleIds.isEmpty
        ? const <Return>[]
        : await (_db.select(_db.returns)
              ..where((r) => r.saleId.isIn(saleIds)))
              .get();
    final refundBySale = <int, int>{};
    for (final refund in refundRows) {
      refundBySale[refund.saleId] =
          (refundBySale[refund.saleId] ?? 0) + refund.totalRefund;
    }
    final debited = sales.fold<int>(
      0,
      (sum, s) =>
          sum + (s.totalAmount - s.paidAmount - (refundBySale[s.id] ?? 0)),
    );
    final payments = await (_db.select(_db.customerPayments)
          ..where((p) => p.customerId.equals(customerId)))
        .get();
    final paid = payments.fold<int>(0, (sum, p) => sum + p.amount);
    return debited - paid;
  }

  @override
  Future<CustomerPayment> recordPayment({
    required int customerId,
    required int amount,
    int? userId,
    String? note,
  }) async {
    final id = await _db.into(_db.customerPayments).insert(
          CustomerPaymentsCompanion.insert(
            customerId: customerId,
            userId: Value(userId),
            amount: amount,
            note: Value(note),
          ),
        );
    final row = await (_db.select(_db.customerPayments)
          ..where((p) => p.id.equals(id)))
        .getSingle();
    return _mapPayment(row);
  }

  @override
  Stream<List<CustomerPayment>> watchPayments(int customerId) {
    final query = _db.select(_db.customerPayments)
      ..where((p) => p.customerId.equals(customerId))
      ..orderBy([(p) => OrderingTerm.desc(p.createdAt)]);
    return query.watch().map((rows) => rows.map(_mapPayment).toList());
  }

  List<CustomerWithBalance> _withBalances(
    List<db.Customer> customers,
    List<Sale> creditSales,
    List<db.CustomerPayment> payments,
    List<Return> refunds,
  ) {
    final refundBySale = <int, int>{};
    for (final refund in refunds) {
      refundBySale[refund.saleId] =
          (refundBySale[refund.saleId] ?? 0) + refund.totalRefund;
    }
    final debited = <int, int>{};
    for (final sale in creditSales) {
      final id = sale.customerId;
      if (id != null) {
        final refunded = refundBySale[sale.id] ?? 0;
        debited[id] =
            (debited[id] ?? 0) +
            (sale.totalAmount - sale.paidAmount - refunded);
      }
    }
    final paid = <int, int>{};
    for (final payment in payments) {
      paid[payment.customerId] = (paid[payment.customerId] ?? 0) + payment.amount;
    }
    return [
      for (final customer in customers)
        CustomerWithBalance(
          customer: _map(customer),
          totalCredit: debited[customer.id] ?? 0,
          totalPaid: paid[customer.id] ?? 0,
          outstanding: (debited[customer.id] ?? 0) - (paid[customer.id] ?? 0),
        ),
    ];
  }

  Customer _map(db.Customer row) {
    return Customer(
      id: row.id,
      name: row.name,
      phone: row.phone,
      email: row.email,
      address: row.address,
      notes: row.notes,
      creditLimit: row.creditLimit,
      createdAt: row.createdAt,
    );
  }

  CustomerPayment _mapPayment(db.CustomerPayment row) {
    return CustomerPayment(
      id: row.id,
      customerId: row.customerId,
      userId: row.userId,
      amount: row.amount,
      note: row.note,
      createdAt: row.createdAt,
    );
  }

  @override
  Future<void> refresh() async {}
}
