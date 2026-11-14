import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/exceptions/auth_exception.dart';
import '../../domain/models/api_config.dart';
import '../../domain/models/app_user.dart';

/// Legacy exception alias for backwards compatibility
typedef InvalidCredentialsException = AuthException;

final sessionProvider =
    NotifierProvider<SessionController, AppUser?>(SessionController.new);

class SessionController extends Notifier<AppUser?> {
  @override
  AppUser? build() => null;

  Future<AppUser> login({
    required String username,
    required String password,
  }) async {
    final user = await ref
        .read(authRepositoryProvider)
        .login(username: username, password: password);

    if (user == null) {
      throw AuthException.invalidCredentials(
        message: 'The provided credentials do not match our records.',
      );
    }
    state = user;
    // Trigger snapshot pull from the server immediately after login if in online mode
    try {
      final config = ref.read(apiConfigProvider);
      if (config.mode == DatabaseMode.onlineApi) {
        ref.read(syncEngineProvider).takeInitialSnapshot();
      }
    } catch (_) {}
    return user;
  }

  void updateUser(AppUser user) {
    state = user;
  }

  void logout() {
    state = null;
    // A new session should never inherit another user's open cart.
    ref.invalidate(posControllerProvider);
  }
}
