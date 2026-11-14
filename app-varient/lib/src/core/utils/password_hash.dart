import 'dart:isolate';

import 'package:bcrypt/bcrypt.dart';

import '../constants/app_constants.dart';

/// Hashes a password using bcrypt with the configured cost factor.
///
/// bcrypt is CPU-bound, so the work is offloaded to a background isolate to
/// keep the UI responsive.
Future<String> hashPassword(String password) {
  return Isolate.run(
    () => BCrypt.hashpw(
      password,
      BCrypt.gensalt(logRounds: AppConstants.bcryptCost),
    ),
  );
}

/// Verifies [password] against a previously stored bcrypt [hash].
///
/// Returns false instead of throwing when [hash] is malformed or missing.
Future<bool> verifyPassword(String password, String hash) {
  return Isolate.run(() {
    try {
      return BCrypt.checkpw(password, hash);
    } on ArgumentError {
      return false;
    }
  });
}
