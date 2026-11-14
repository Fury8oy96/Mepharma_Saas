import 'package:drift/drift.dart';

import '../../core/utils/password_hash.dart';
import '../../domain/models/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../db/app_database.dart';

class SqliteAuthRepository implements AuthRepository {
  SqliteAuthRepository(this._db);

  final AppDatabase _db;

  @override
  Future<AppUser?> login({
    required String username,
    required String password,
  }) async {
    final row =
        await (_db.select(_db.users)
              ..where((u) => u.username.lower().equals(username.toLowerCase())))
            .getSingleOrNull();

    if (row == null || !row.isActive) {
      return null;
    }

    final passwordMatches = await verifyPassword(password, row.passwordHash);
    if (!passwordMatches) {
      return null;
    }

    return AppUser(
      id: row.id,
      username: row.username,
      role: row.role,
      isActive: row.isActive,
      createdAt: row.createdAt,
    );
  }
}
