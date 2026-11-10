import 'dart:async';
import 'dart:convert';

import '../../../domain/models/app_supplier.dart';
import '../../../domain/repositories/supplier_repository.dart';
import '../../../core/services/api_client.dart';

class ApiSupplierRepository implements SupplierRepository {
  ApiSupplierRepository(this._client) {
    _refreshAll();
  }

  final ApiClient _client;
  final _allController = StreamController<List<AppSupplier>>.broadcast();
  List<AppSupplier> _cachedSuppliers = [];

  Future<void> _refreshAll() async {
    try {
      final suppliers = await getAll();
      _cachedSuppliers = suppliers;
      _allController.add(suppliers);
    } catch (_) {
      _allController.add(_cachedSuppliers);
    }
  }

  AppSupplier _mapSupplier(Map<String, dynamic> json) {
    return AppSupplier(
      id: json['id'] as int,
      name: json['name'] as String,
      contactPerson: json['contact_person'] as String? ?? json['contactPerson'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
    );
  }

  @override
  Stream<List<AppSupplier>> watchAll() async* {
    yield _cachedSuppliers;
    try {
      final suppliers = await getAll();
      _cachedSuppliers = suppliers;
      yield suppliers;
    } catch (_) {}
    yield* _allController.stream;
  }

  @override
  Future<List<AppSupplier>> getAll() async {
    final response = await _client.get('/suppliers');
    final data = jsonDecode(response.body) as List;
    return data.map((item) => _mapSupplier(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<AppSupplier?> findById(int id) async {
    try {
      final response = await _client.get('/suppliers/$id');
      return _mapSupplier(jsonDecode(response.body) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<AppSupplier> create({
    required String name,
    String? contactPerson,
    String? phone,
    String? email,
    String? address,
  }) async {
    final response = await _client.post('/suppliers', body: {
      'name': name,
      'contact_person': contactPerson,
      'phone': phone,
      'email': email,
      'address': address,
    });
    final supplier = _mapSupplier(jsonDecode(response.body) as Map<String, dynamic>);
    _refreshAll();
    return supplier;
  }

  @override
  Future<void> update(
    int id, {
    required String name,
    String? contactPerson,
    String? phone,
    String? email,
    String? address,
  }) async {
    await _client.put('/suppliers/$id', body: {
      'name': name,
      'contact_person': contactPerson,
      'phone': phone,
      'email': email,
      'address': address,
    });
    _refreshAll();
  }

  @override
  Future<void> delete(int id) async {
    await _client.delete('/suppliers/$id');
    _refreshAll();
  }

  @override
  Future<void> refresh() async {
    await _refreshAll();
  }
}
