import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../core/utils/money.dart';
import '../../domain/models/app_purchase.dart';
import '../../l10n/generated/app_localizations.dart';
import '../pos/supervisor_approval_dialog.dart';
import '../session/session_controller.dart';

class PurchaseDetailDialog extends ConsumerStatefulWidget {
  const PurchaseDetailDialog({super.key, required this.purchaseId});

  final int purchaseId;

  @override
  ConsumerState<PurchaseDetailDialog> createState() => _PurchaseDetailDialogState();
}

class _PurchaseDetailDialogState extends ConsumerState<PurchaseDetailDialog> {
  bool _isApproving = false;

  Future<void> _handleApprove(int purchaseId) async {
    final l10n = AppLocalizations.of(context);
    final currentUser = ref.read(sessionProvider);
    final canApproveDirectly = currentUser?.canApprovePurchases == true;

    if (canApproveDirectly) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.inventory_2_outlined, color: Theme.of(ctx).colorScheme.primary),
              const SizedBox(width: 8),
              Text(l10n.approveAndRestock),
            ],
          ),
          content: const Text(
            'Are you sure you want to approve this purchase order and ingest its inventory into the branch stock?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.approveAndRestock),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    } else {
      final authorized = await SupervisorApprovalDialog.requestApproval(
        context,
        reason: 'Approving purchase orders and ingesting stock requires Branch Administrator or Supervisor authorization.',
      );
      if (!authorized) return;
    }

    setState(() => _isApproving = true);

    try {
      await ref.read(purchaseRepositoryProvider).approvePurchase(purchaseId);
      ref.read(productRepositoryProvider).refresh();
      ref.invalidate(purchaseDetailProvider(purchaseId));

      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text('${l10n.purchaseApproval}: ${l10n.stockAdjusted}'),
              backgroundColor: Colors.green,
            ),
          );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isApproving = false);
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text('Failed to approve purchase order: $e'),
              backgroundColor: Colors.red,
            ),
          );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final detailAsync = ref.watch(purchaseDetailProvider(widget.purchaseId));
    final suppliers = ref.watch(supplierListProvider).valueOrNull ?? const [];
    final symbol = ref.watch(currencySymbolProvider).valueOrNull ?? r'$';

    return AlertDialog(
      title: Text(l10n.purchaseDetail),
      content: SizedBox(
        width: 580,
        child: detailAsync.when(
          loading: () => const SizedBox(
            height: 300,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => SizedBox(
            height: 200,
            child: Center(child: Text(l10n.errorOccurred)),
          ),
          data: (detail) {
            final isPending = detail.purchase.status == PurchaseStatus.pending;
            final supplier = suppliers
                .where((s) => s.id == detail.purchase.supplierId)
                .firstOrNull;
            final supplierLabel = supplier != null
                ? supplier.name
                : (detail.purchase.supplierId != null
                    ? '${l10n.supplier} #${detail.purchase.supplierId}'
                    : l10n.noSupplier);

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          detail.purchase.invoiceNumber,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isPending
                              ? Colors.amber.shade100
                              : Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isPending
                                ? Colors.amber.shade400
                                : Colors.green.shade400,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPending
                                  ? Icons.pending_actions
                                  : Icons.check_circle,
                              size: 14,
                              color: isPending
                                  ? Colors.amber.shade900
                                  : Colors.green.shade800,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isPending
                                  ? l10n.pendingApproval
                                  : l10n.approved,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isPending
                                    ? Colors.amber.shade900
                                    : Colors.green.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    [
                      supplierLabel,
                      DateFormat.yMd(
                        l10n.localeName,
                      ).format(detail.purchase.purchaseDate),
                    ].join(' · '),
                    style: theme.textTheme.bodySmall,
                  ),
                  const Divider(height: 24),
                  for (final item in detail.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${item.productName}\n'
                              '${item.quantity} x ${formatCents(item.costPrice)}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                          Text(
                            formatMoney(item.totalCost, symbol: symbol),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Text(
                        l10n.purchaseTotal,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        formatMoney(
                          detail.purchase.totalAmount,
                          symbol: symbol,
                        ),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
        if (detailAsync.valueOrNull?.purchase.status == PurchaseStatus.pending)
          FilledButton.icon(
            onPressed: _isApproving ? null : () => _handleApprove(widget.purchaseId),
            icon: _isApproving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_circle_outline, size: 18),
            label: Text(_isApproving ? '...' : l10n.approveAndRestock),
          ),
      ],
    );
  }
}
