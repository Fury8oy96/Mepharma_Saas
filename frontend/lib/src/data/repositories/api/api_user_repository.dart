import 'dart:async';
import 'dart:convert';

import '../../../domain/models/app_user.dart';
import '../../../domain/repositories/user_repository.dart';
import '../../../core/services/api_client.dart';
import '../../db/enums.dart';

class ApiUserRepository implements UserRepository {
  ApiUserRepository(this._client) {
    _initStream();
  }

  final ApiClient _client;
  final _usersController = StreamController<List<AppUser>>.broadcast();
  List<AppUser> _cachedUsers = [];

  void _initStream() {
    _usersController.onListen = () {
      _refreshUsers();
    };
  }

  Future<void> _refreshUsers() async {
    try {
      final users = await _fetchUsers();
      _cachedUsers = users;
      _usersController.add(users);
    } catch (_) {
      _usersController.add(_cachedUsers);
    }
  }

  Future<List<AppUser>> _fetchUsers() async {
    final response = await _client.get('/users');
    final data = jsonDecode(response.body) as List;
    return data.map((item) => _mapUser(item as Map<String, dynamic>)).toList();
  }

  AppUser _mapUser(Map<String, dynamic> json) {
    final roleStr = (json['role'] as String? ?? '').toLowerCase();
    final mappedRole = (roleStr == 'super_admin' || roleStr == 'superadmin')
        ? UserRole.superAdmin
        : (roleStr == 'pharmacy_admin' ||
                roleStr == 'pharmacyadmin')
            ? UserRole.pharmacyAdmin
            : (roleStr == 'branch_admin' ||
                    roleStr == 'branchadmin')
                ? UserRole.branchAdmin
            : (roleStr == 'supervisor')
                ? UserRole.supervisor
                : (roleStr == 'pharmacist')
                    ? UserRole.pharmacist
                    : (roleStr == 'admin')
                        ? UserRole.admin
                        : UserRole.staff;

    return AppUser(
      id: json['id'] as int,
      username: json['username'] as String,
      role: mappedRole,
      isActive: json['is_active'] as bool? ?? json['isActive'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  @override
  Future<bool> hasAnyUsers() async {
    try {
      final response = await _client.get('/users/count');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['count'] as int? ?? 0) > 0;
    } catch (_) {
      return _cachedUsers.isNotEmpty;
    }
  }

  @override
  Future<AppUser?> findByUsername(String username) async {
    try {
      final response = await _client.get('/users/username/${Uri.encodeQueryComponent(username)}');
      return _mapUser(jsonDecode(response.body) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<AppUser?> findById(int id) async {
    try {
      final response = await _client.get('/users/$id');
      return _mapUser(jsonDecode(response.body) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<AppUser> createUser({
    required String username,
    required String password,
    required UserRole role,
  }) async {
    String roleName = role.name;
    if (role == UserRole.superAdmin) roleName = 'super_admin';
    if (role == UserRole.pharmacyAdmin) roleName = 'pharmacy_admin';
    if (role == UserRole.branchAdmin) roleName = 'branch_admin';
    if (role == UserRole.supervisor) roleName = 'supervisor';
    if (role == UserRole.pharmacist) roleName = 'pharmacist';

    final response = await _client.post('/users', body: {
      'username': username,
      'password': password,
      'role': roleName,
    });
    final user = _mapUser(jsonDecode(response.body) as Map<String, dynamic>);
    _refreshUsers();
    return user;
  }

  @override
  Stream<List<AppUser>> watchUsers() {
    return _usersController.stream;
  }

  @override
  Future<AppUser> updateUser(
    int id, {
    String? password,
    UserRole? role,
    bool? isActive,
  }) async {
    final body = <String, dynamic>{};
    if (password != null) body['password'] = password;
    if (role != null) {
      String roleName = role.name;
      if (role == UserRole.superAdmin) roleName = 'super_admin';
      if (role == UserRole.pharmacyAdmin) roleName = 'pharmacy_admin';
      if (role == UserRole.branchAdmin) roleName = 'branch_admin';
      if (role == UserRole.supervisor) roleName = 'supervisor';
      if (role == UserRole.pharmacist) roleName = 'pharmacist';
      body['role'] = roleName;
    }
    if (isActive != null) body['is_active'] = isActive;

    final response = await _client.put('/users/$id', body: body);
    final user = _mapUser(jsonDecode(response.body) as Map<String, dynamic>);
    _refreshUsers();
    return user;
  }

  @override
  Future<void> ensureDefaultAdmin() async {
    try {
      await _client.post('/users/ensure-default-admin');
    } catch (_) {
      // Safe no-op, server-side seeder is the primary source of truth.
    }
  }
}
