import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/app_constants.dart';
import '../../l10n/generated/app_localizations.dart';

/// Language selector shown on the login page and in the app header.
class LanguageSwitcher extends ConsumerWidget {
  const LanguageSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final l10n = AppLocalizations.of(context);
    final currentSelected = locale.languageCode == 'ar' ? const Locale('ar') : const Locale('en');

    return SegmentedButton<Locale>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment<Locale>(
          value: const Locale('en'),
          label: Text(l10n.english),
        ),
        ButtonSegment<Locale>(
          value: const Locale('ar'),
          label: Text(l10n.arabic),
        ),
      ],
      selected: {currentSelected},
      onSelectionChanged: (selection) async {
        final newLocale = selection.first;
        final code = newLocale.languageCode;
        ref.read(localeProvider.notifier).state = newLocale;
        try {
          await ref
              .read(settingsRepositoryProvider)
              .setValue(AppConstants.settingLocale, code);
        } catch (e) {
          debugPrint('Language preference save non-fatal notice: $e');
        }
      },
    );
  }
}
