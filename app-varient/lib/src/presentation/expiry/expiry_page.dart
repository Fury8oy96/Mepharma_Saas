import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/utils/money.dart';
import '../../domain/models/app_product.dart';
import '../../l10n/generated/app_localizations.dart';

/// Products that are expired or expiring soon, grouped into sections.
class ExpiryPage extends ConsumerStatefulWidget {
  const ExpiryPage({super.key});

  @override
  ConsumerState<ExpiryPage> createState() => _ExpiryPageState();
}

class _ExpiryPageState extends ConsumerState<ExpiryPage> {
  int _withinDays = 30;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(l10n.expiry, style: theme.textTheme.titleLarge),
                const Spacer(),
                SegmentedButton<int>(
                  segments: [
                    for (final days in [7, 30, 90])
                      ButtonSegment(
                        value: days,
                        label: Text(l10n.nextDays(days)),
                      ),
                  ],
                  selected: {_withinDays},
                  onSelectionChanged: (selection) {
                    setState(() => _withinDays = selection.first);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(child: _ExpiryList(withinDays: _withinDays)),
            const SizedBox(height: 12),
            Text(
              l10n.expiryHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpiryList extends ConsumerWidget {
  const _ExpiryList({required this.withinDays});

  final int withinDays;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settingsAsync = ref.watch(storeSettingsProvider);
    final symbol = settingsAsync.valueOrNull?.currencySymbol ?? '';
    final list =
        ref.watch(expiringProductsProvider).valueOrNull ?? const <AppProduct>[];
    final expired = list.where((p) => p.isExpired).toList();
    final soon =
        list
            .where(
              (p) => !p.isExpired && (p.daysUntilExpiry ?? 0) <= withinDays,
            )
            .toList()
          ..sort(
            (a, b) =>
                (a.daysUntilExpiry ?? 0).compareTo(b.daysUntilExpiry ?? 0),
          );

    if (expired.isEmpty && soon.isEmpty) {
      return Card(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.verified_outlined,
                size: 56,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.noExpiringProducts,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      children: [
        if (expired.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              '${l10n.expiredProducts} (${expired.length})',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
          Card(
            child: Column(
              children: [
                for (final product in expired)
                  _ExpiryTile(
                    product: product,
                    symbol: symbol,
                    tone: _ExpiryTone.expired,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (soon.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              '${l10n.expiringSoon} (${soon.length})',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.tertiary,
              ),
            ),
          ),
          Card(
            child: Column(
              children: [
                for (final product in soon)
                  _ExpiryTile(
                    product: product,
                    symbol: symbol,
                    tone: _ExpiryTone.warning,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

enum _ExpiryTone { expired, warning }

class _ExpiryTile extends StatelessWidget {
  const _ExpiryTile({
    required this.product,
    required this.symbol,
    required this.tone,
  });

  final AppProduct product;
  final String symbol;
  final _ExpiryTone tone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final color = tone == _ExpiryTone.expired
        ? theme.colorScheme.error
        : theme.colorScheme.tertiary;

    final expiry = product.expiryDate!;
    final label = tone == _ExpiryTone.expired
        ? l10n.expiredOn(_formatDate(expiry))
        : '${l10n.daysUntilExpiry(product.daysUntilExpiry ?? 0)}'
              ' • ${_formatDate(expiry)}';

    return ListTile(
      leading: Icon(
        tone == _ExpiryTone.expired ? Icons.error_outline : Icons.schedule,
        color: color,
      ),
      title: Text(
        product.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text('${product.sku} • $label', style: TextStyle(color: color)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${l10n.stock}: ${product.stockQuantity}'),
          const SizedBox(width: 16),
          SizedBox(
            width: 110,
            child: Text(
              formatMoney(
                product.costPrice * product.stockQuantity,
                symbol: symbol,
              ),
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
