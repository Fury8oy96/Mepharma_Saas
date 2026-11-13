import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'src/app/app.dart';
import 'src/app/providers.dart';
import 'src/core/constants/app_constants.dart';
import 'src/core/services/api_config_manager.dart';
import 'src/data/repositories/sqlite_user_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Pre-load configuration before building UI/router to guarantee
  // synchronous availability of mode and license state.
  final configManager = ApiConfigManager();
  final initialConfig = await configManager.loadConfig();

  // A single container shared by startup bootstrap and the widget tree.
  final container = ProviderContainer(
    overrides: [
      apiConfigProvider.overrideWith(
        (ref) => ApiConfigNotifier(configManager, initialConfig),
      ),
    ],
  );

  try {
    // Opens the database (creating the schema if needed) and seeds the
    // default admin account on first run.
    final db = container.read(databaseProvider);

    // If a clean install flag file exists (dropped by installer during fresh setup),
    // wipe the SQLite database immediately on startup to guarantee a 100% clean state.
    try {
      final exeDir = File(Platform.resolvedExecutable).parent;
      final flagFile1 = File(p.join(exeDir.path, 'clean_install.flag'));
      final flagFile2 = File(p.join(Directory.current.path, 'clean_install.flag'));
      final flagFile = await flagFile1.exists()
          ? flagFile1
          : (await flagFile2.exists() ? flagFile2 : null);

      if (flagFile != null) {
        debugPrint('Clean installation flag detected: wiping SQLite database...');
        await db.wipeAndReset();
        try {
          await flagFile.delete();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Clean install flag check notice: $e');
    }

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
