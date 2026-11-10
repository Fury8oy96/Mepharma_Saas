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
      selected: {locale},
      onSelectionChanged: (selection) async {
        final code = selection.first.languageCode;
        try {
          await ref
              .read(settingsRepositoryProvider)
              .setValue(AppConstants.settingLocale, code);
        } on Exception {
          // Persistence failure is non-fatal; still switch for this session.
        }
        ref.read(localeProvider.notifier).state = selection.first;
      },
    );
  }
}
