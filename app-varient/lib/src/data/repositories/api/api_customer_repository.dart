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

  int _asInt(dynamic v, [int fallback = 0]) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? double.tryParse(v)?.toInt() ?? fallback;
    return fallback;
  }

  Customer _mapCustomer(Map<String, dynamic> json) {
    return Customer(
      id: _asInt(json['id']),
      name: (json['name'] ?? '').toString(),
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      notes: json['notes'] as String?,
      creditLimit: _asInt(json['credit_limit'] ?? json['creditLimit']),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  CustomerWithBalance _mapCustomerWithBalance(Map<String, dynamic> json) {
    final customerMap = json['customer'] is Map<String, dynamic>
        ? json['customer'] as Map<String, dynamic>
        : json;
    return CustomerWithBalance(
      customer: _mapCustomer(customerMap),
      outstanding: _asInt(json['outstanding']),
      totalPaid: _asInt(json['total_paid'] ?? json['totalPaid']),
      totalCredit: _asInt(json['total_credit'] ?? json['totalCredit']),
    );
  }

  CustomerPayment _mapCustomerPayment(Map<String, dynamic> json) {
    return CustomerPayment(
      id: _asInt(json['id']),
      customerId: _asInt(json['customer_id'] ?? json['customerId']),
      userId: json['user_id'] != null ? _asInt(json['user_id']) : (json['userId'] != null ? _asInt(json['userId']) : null),
      amount: _asInt(json['amount']),
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
