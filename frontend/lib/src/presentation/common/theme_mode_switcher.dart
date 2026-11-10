import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/app_constants.dart';

/// Theme mode selector (Light / Dark / System) with persistence and compact mode.
class ThemeModeSwitcher extends ConsumerWidget {
  const ThemeModeSwitcher({super.key, this.showLabels = false});

  final bool showLabels;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return SegmentedButton<ThemeMode>(
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      ),
      segments: [
        ButtonSegment<ThemeMode>(
          value: ThemeMode.light,
          icon: const Icon(Icons.light_mode_outlined, size: 16),
          label: showLabels ? Text(isArabic ? 'فاتح' : 'Light') : null,
          tooltip: isArabic ? 'الوضع الفاتح' : 'Light Mode',
        ),
        ButtonSegment<ThemeMode>(
          value: ThemeMode.dark,
          icon: const Icon(Icons.dark_mode_outlined, size: 16),
          label: showLabels ? Text(isArabic ? 'داكن' : 'Dark') : null,
          tooltip: isArabic ? 'الوضع الداكن' : 'Dark Mode',
        ),
        ButtonSegment<ThemeMode>(
          value: ThemeMode.system,
          icon: const Icon(Icons.settings_brightness_outlined, size: 16),
          label: showLabels ? Text(isArabic ? 'تلقائي' : 'System') : null,
          tooltip: isArabic ? 'تلقائي حسب النظام' : 'System Match',
        ),
      ],
      selected: {themeMode},
      onSelectionChanged: (selection) async {
        final selected = selection.first;
        final code = switch (selected) {
          ThemeMode.light => 'light',
          ThemeMode.dark => 'dark',
          ThemeMode.system => 'system',
        };
        try {
          await ref
              .read(settingsRepositoryProvider)
              .setValue(AppConstants.settingThemeMode, code);
        } on Exception {
          // Non-fatal; theme still applies for the active session.
        }
        ref.read(themeModeProvider.notifier).state = selected;
      },
    );
  }
}
