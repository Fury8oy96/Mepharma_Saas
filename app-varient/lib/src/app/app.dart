import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/generated/app_localizations.dart';
import '../presentation/theme/app_theme.dart';
import 'providers.dart';
import 'router.dart';

class PharmaApp extends ConsumerWidget {
  const PharmaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: router,
      builder: (context, child) => _StartupBootstrapWrapper(
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}

class _StartupBootstrapWrapper extends ConsumerStatefulWidget {
  const _StartupBootstrapWrapper({required this.child});
  final Widget child;

  @override
  ConsumerState<_StartupBootstrapWrapper> createState() => _StartupBootstrapWrapperState();
}

class _StartupBootstrapWrapperState extends ConsumerState<_StartupBootstrapWrapper> {
  bool _checkedAutoBackup = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runDailyAutoBackup();
    });
  }

  Future<void> _runDailyAutoBackup() async {
    if (_checkedAutoBackup) return;
    _checkedAutoBackup = true;

    try {
      final backupService = ref.read(backupServiceProvider);
      final dir = await backupService.getBackupsDirectory();
      final now = DateTime.now();
      String two(int n) => n.toString().padLeft(2, '0');
      final targetName = 'backup${now.year}${two(now.month)}${two(now.day)}.db';
      final targetFile = File('${dir.path}${Platform.pathSeparator}$targetName');

      if (await targetFile.exists()) {
        // Already backed up today, do nothing.
        return;
      }

      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'يتم عمل نسخة احتياطية محلية تلقائية لقاعدة البيانات حالياً...',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
          backgroundColor: const Color(0xFF1E293B),
        ),
      );

      final record = await backupService.createDailyAutoBackupIfNeeded();
      if (record != null && mounted) {
        messenger?.clearSnackBars();
        messenger?.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'تم إنشاء النسخة الاحتياطية بنجاح في: ${record.filePath ?? targetFile.path}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 4),
            backgroundColor: const Color(0xFF0F172A),
          ),
        );
      }
    } catch (e) {
      debugPrint('Daily auto backup error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
