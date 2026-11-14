import '../../data/db/enums.dart';
import '../models/app_user.dart';

abstract interface class UserRepository {
  Future<bool> hasAnyUsers();

  Future<AppUser?> findByUsername(String username);

  Future<AppUser?> findById(int id);

  Future<AppUser> createUser({
    required String username,
    required String password,
    required UserRole role,
  });

  /// All users, admin first then by creation date.
  Stream<List<AppUser>> watchUsers();

  /// Updates only the provided fields. A null password keeps the old one.
  Future<AppUser> updateUser(
    int id, {
    String? username,
    String? password,
    UserRole? role,
    bool? isActive,
  });

  Future<void> ensureDefaultAdmin();

  Future<void> deleteUser(int id);
}
