import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../core/utils/money.dart';
import '../../domain/models/app_sales_hold.dart';
import '../../l10n/generated/app_localizations.dart';

/// Lists held sales and returns the selected one via `Navigator.pop`.
class HoldsDialog extends ConsumerWidget {
  const HoldsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final holds = ref.watch(salesHoldListProvider).valueOrNull ?? const [];
    final currency = ref.watch(currencySymbolProvider).valueOrNull ?? r'$';

    return AlertDialog(
      title: Text(l10n.resumeHold),
      content: SizedBox(
        width: 420,
        height: 420,
        child: holds.isEmpty
            ? Center(
                child: Text(
                  l10n.noHolds,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            : ListView.builder(
                itemCount: holds.length,
                itemBuilder: (context, index) {
                  final hold = holds[index];
                  return _HoldTile(
                    hold: hold,
                    currency: currency,
                    dateFormatter: DateFormat.yMd(l10n.localeName).add_Hm(),
                    onTap: () => Navigator.of(context).pop(hold),
                    onDelete: () => _deleteHold(context, ref, hold),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }

  Future<void> _deleteHold(
    BuildContext context,
    WidgetRef ref,
    AppSalesHold hold,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteHold),
        content: Text(l10n.confirmDeleteHold(hold.holdNumber)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(salesHoldRepositoryProvider).deleteHold(hold.id);
    }
  }
}

class _HoldTile extends StatelessWidget {
  const _HoldTile({
    required this.hold,
    required this.currency,
    required this.dateFormatter,
    required this.onTap,
    required this.onDelete,
  });

  final AppSalesHold hold;
  final String currency;
  final DateFormat dateFormatter;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          child: const Icon(Icons.pause_circle_outline),
        ),
        title: Text(hold.holdNumber),
        subtitle: Text(dateFormatter.format(hold.createdAt)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatMoney(hold.totalAmount, symbol: currency),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            IconButton(
              tooltip: l10n.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
