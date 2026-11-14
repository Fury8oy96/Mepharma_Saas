import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app/app.dart';
import 'src/app/providers.dart';
import 'src/core/constants/app_constants.dart';
import 'src/data/repositories/sqlite_user_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // A single container shared by startup bootstrap and the widget tree.
  final container = ProviderContainer();
  try {
    // Opens the database (creating the schema if needed) and seeds the
    // default admin account on first run.
    final db = container.read(databaseProvider);
    await SqliteUserRepository(db).ensureDefaultAdmin();

    // Restore the persisted language (defaults to English).
    final savedLocale = await container.read(settingsRepositoryProvider).getValue(
          AppConstants.settingLocale,
        );
    final locale = switch (savedLocale) {
      'ar' => const Locale('ar'),
      _ => const Locale('en'),
    };
    container.read(localeProvider.notifier).state = locale;

    // Restore the persisted theme mode (defaults to system).
    final savedTheme = await container.read(settingsRepositoryProvider).getValue(
          AppConstants.settingThemeMode,
        );
    final themeMode = switch (savedTheme) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    container.read(themeModeProvider.notifier).state = themeMode;
  } catch (error) {
    debugPrint('Database bootstrap failed: $error');
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const PharmaApp(),
    ),
  );
}
