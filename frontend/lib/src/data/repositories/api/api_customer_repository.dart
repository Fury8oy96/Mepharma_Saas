import 'dart:async';
import 'dart:convert';

import '../../../domain/models/customer.dart';
import '../../../domain/repositories/customer_repository.dart';
import '../../../core/services/api_client.dart';

class ApiCustomerRepository implements CustomerRepository {
  ApiCustomerRepository(this._client) {
    _refreshCustomers();
  }

  final ApiClient _client;
  final _allController = StreamController<List<CustomerWithBalance>>.broadcast();
  List<CustomerWithBalance> _cachedCustomers = [];

  Future<void> _refreshCustomers() async {
    try {
      final customers = await _fetchAll();
      _cachedCustomers = customers;
      _allController.add(customers);
    } catch (_) {
      _allController.add(_cachedCustomers);
    }
  }

  Future<List<CustomerWithBalance>> _fetchAll() async {
    final response = await _client.get('/customers');
    final data = jsonDecode(response.body) as List;
    return data.map((item) => _mapCustomerWithBalance(item as Map<String, dynamic>)).toList();
  }

  Customer _mapCustomer(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as int,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      notes: json['notes'] as String?,
      creditLimit: json['credit_limit'] as int? ?? json['creditLimit'] as int? ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  CustomerWithBalance _mapCustomerWithBalance(Map<String, dynamic> json) {
    return CustomerWithBalance(
      customer: _mapCustomer(json['customer'] as Map<String, dynamic>),
      outstanding: json['outstanding'] as int? ?? 0,
      totalPaid: json['total_paid'] as int? ?? json['totalPaid'] as int? ?? 0,
      totalCredit: json['total_credit'] as int? ?? json['totalCredit'] as int? ?? 0,
    );
  }

  CustomerPayment _mapCustomerPayment(Map<String, dynamic> json) {
    return CustomerPayment(
      id: json['id'] as int,
      customerId: json['customer_id'] as int? ?? json['customerId'] as int? ?? 0,
      userId: json['user_id'] as int? ?? json['userId'] as int?,
      amount: json['amount'] as int? ?? 0,
      note: json['note'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  @override
  Stream<List<CustomerWithBalance>> watchAll() async* {
    yield _cachedCustomers;
    try {
      final customers = await _fetchAll();
      _cachedCustomers = customers;
      yield customers;
    } catch (_) {}
    yield* _allController.stream;
  }

  @override
  Future<Customer?> findById(int id) async {
    try {
      final response = await _client.get('/customers/$id');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return _mapCustomer(data);
    } catch (_) {
      return null;
    }
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
    final response = await _client.post('/customers', body: {
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'notes': notes,
      'credit_limit': creditLimit,
    });
    final customer = _mapCustomer(jsonDecode(response.body) as Map<String, dynamic>);
    _refreshCustomers();
    return customer;
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
    await _client.put('/customers/$id', body: {
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'notes': notes,
      'credit_limit': creditLimit,
    });
    _refreshCustomers();
  }

  @override
  Future<void> delete(int id) async {
    await _client.delete('/customers/$id');
    _refreshCustomers();
  }

  @override
  Future<bool> isNameTaken(String name, {int? excludeId}) async {
    try {
      final response = await _client.get('/customers/check-name?name=${Uri.encodeQueryComponent(name)}&exclude_id=${excludeId ?? ""}');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['taken'] as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<int> getBalance(int customerId) async {
    try {
      final response = await _client.get('/customers/$customerId/balance');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['balance'] as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<CustomerPayment> recordPayment({
    required int customerId,
    required int amount,
    int? userId,
    String? note,
  }) async {
    final response = await _client.post('/customers/$customerId/payments', body: {
      'amount': amount,
      'user_id': userId,
      'note': note,
    });
    final payment = _mapCustomerPayment(jsonDecode(response.body) as Map<String, dynamic>);
    _refreshCustomers();
    return payment;
  }

  @override
  Stream<List<CustomerPayment>> watchPayments(int customerId) {
    // Poll payments periodically
    final controller = StreamController<List<CustomerPayment>>();
    Timer? timer;

    Future<void> fetch() async {
      try {
        final response = await _client.get('/customers/$customerId/payments');
        final data = jsonDecode(response.body) as List;
        final list = data.map((item) => _mapCustomerPayment(item as Map<String, dynamic>)).toList();
        if (!controller.isClosed) {
          controller.add(list);
        }
      } catch (_) {}
    }

    controller.onListen = () {
      fetch();
      timer = Timer.periodic(const Duration(seconds: 5), (_) => fetch());
    };

    controller.onCancel = () {
      timer?.cancel();
      controller.close();
    };

    return controller.stream;
  }

  @override
  Future<void> refresh() async {
    await _refreshCustomers();
  }
}
