import 'dart:async';
import 'dart:convert';

import '../../../domain/models/app_category.dart';
import '../../../domain/repositories/category_repository.dart';
import '../../../core/services/api_client.dart';

class ApiCategoryRepository implements CategoryRepository {
  ApiCategoryRepository(this._client) {
    _refreshAll();
  }

  final ApiClient _client;
  final _allController = StreamController<List<AppCategory>>.broadcast();
  List<AppCategory> _cachedCategories = [];

  Future<void> _refreshAll() async {
    try {
      final categories = await getAll();
      _cachedCategories = categories;
      _allController.add(categories);
    } catch (_) {
      _allController.add(_cachedCategories);
    }
  }

  AppCategory _mapCategory(Map<String, dynamic> json) {
    return AppCategory(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
    );
  }

  @override
  Stream<List<AppCategory>> watchAll() async* {
    yield _cachedCategories;
    try {
      final categories = await getAll();
      _cachedCategories = categories;
      yield categories;
    } catch (_) {}
    yield* _allController.stream;
  }

  @override
  Future<List<AppCategory>> getAll() async {
    final response = await _client.get('/categories');
    final data = jsonDecode(response.body) as List;
    return data.map((item) => _mapCategory(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<AppCategory?> findById(int id) async {
    try {
      final response = await _client.get('/categories/$id');
      return _mapCategory(jsonDecode(response.body) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<AppCategory> create({required String name, String? description}) async {
    final response = await _client.post('/categories', body: {
      'name': name,
      'description': description,
    });
    final category = _mapCategory(jsonDecode(response.body) as Map<String, dynamic>);
    _refreshAll();
    return category;
  }

  @override
  Future<void> update(int id, {required String name, String? description}) async {
    await _client.put('/categories/$id', body: {
      'name': name,
      'description': description,
    });
    _refreshAll();
  }

  @override
  Future<void> delete(int id) async {
    await _client.delete('/categories/$id');
    _refreshAll();
  }

  @override
  Future<void> refresh() async {
    await _refreshAll();
  }
}
