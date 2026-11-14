import '../models/app_user.dart';

abstract interface class AuthRepository {
  /// Authenticates [username] with [password].
  ///
  /// Returns the authenticated user or `null` on invalid credentials.
  Future<AppUser?> login({required String username, required String password});
}
