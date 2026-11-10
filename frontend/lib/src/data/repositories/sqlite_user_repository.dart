import 'package:drift/drift.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/password_hash.dart';
import '../../domain/models/app_user.dart';
import '../../domain/repositories/user_repository.dart';
import '../db/app_database.dart';
import '../db/enums.dart';

class SqliteUserRepository implements UserRepository {
  SqliteUserRepository(this._db);

  final AppDatabase _db;

  @override
  Future<bool> hasAnyUsers() async {
    return (await _db.users.count().getSingle()) > 0;
  }

  @override
  Future<AppUser?> findByUsername(String username) async {
    final row =
        await (_db.select(_db.users)
              ..where((u) => u.username.lower().equals(username.toLowerCase())))
            .getSingleOrNull();
    return row == null ? null : _map(row);
  }

  @override
  Future<AppUser?> findById(int id) async {
    final row = await (_db.select(
      _db.users,
    )..where((u) => u.id.equals(id))).getSingleOrNull();
    return row == null ? null : _map(row);
  }

  @override
  Future<AppUser> createUser({
    required String username,
    required String password,
    required UserRole role,
  }) async {
    final hash = await hashPassword(password);
    final id = await _db
        .into(_db.users)
        .insert(
          UsersCompanion.insert(
            username: username.trim().toLowerCase(),
            passwordHash: hash,
            role: role,
          ),
        );
    return _getById(id);
  }

  @override
  Stream<List<AppUser>> watchUsers() {
    final query = _db.select(_db.users)
      ..orderBy([
        (u) => OrderingTerm.asc(u.role),
        (u) => OrderingTerm.asc(u.createdAt),
      ]);
    return query.watch().map((rows) => rows.map(_map).toList());
  }

  @override
  Future<AppUser> updateUser(
    int id, {
    String? password,
    UserRole? role,
    bool? isActive,
  }) async {
    final hash = password == null ? null : await hashPassword(password);
    await (_db.update(_db.users)..where((u) => u.id.equals(id))).write(
      UsersCompanion(
        passwordHash: hash == null ? Value.absent() : Value(hash),
        role: role == null ? Value.absent() : Value(role),
        isActive: isActive == null ? Value.absent() : Value(isActive),
      ),
    );
    return _getById(id);
  }

  Future<AppUser> _getById(int id) async {
    final row = await (_db.select(
      _db.users,
    )..where((u) => u.id.equals(id))).getSingle();
    return _map(row);
  }

  @override
  Future<void> ensureDefaultAdmin() async {
    if (await hasAnyUsers()) {
      return;
    }
    await createUser(
      username: AppConstants.defaultAdminUsername,
      password: AppConstants.defaultAdminPassword,
      role: UserRole.admin,
    );
  }

  AppUser _map(User row) {
    return AppUser(
      id: row.id,
      username: row.username,
      role: row.role,
      isActive: row.isActive,
      createdAt: row.createdAt,
    );
  }
}
