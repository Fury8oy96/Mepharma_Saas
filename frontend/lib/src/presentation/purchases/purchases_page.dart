import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../core/utils/money.dart';
import '../../domain/models/app_supplier.dart';
import '../../domain/models/app_purchase.dart';
import '../../l10n/generated/app_localizations.dart';
import 'purchase_detail_dialog.dart';
import 'purchase_form_dialog.dart';

class PurchasesPage extends ConsumerWidget {
  const PurchasesPage({super.key});

  Future<void> _openForm(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => const PurchaseFormDialog(),
    );
    if (saved == true) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(l10n.purchaseSaved)));
    }
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<AppPurchase> purchases,
    Map<int, String> supplierName,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    if (purchases.isEmpty) {
      return Center(
        child: Text(
          l10n.noPurchases,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: purchases.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final purchase = purchases[index];
        return ListTile(
          onTap: () => showDialog<void>(
            context: context,
            builder: (context) => PurchaseDetailDialog(
              purchaseId: purchase.id,
            ),
          ),
          leading: const CircleAvatar(
            child: Icon(Icons.inventory_2_outlined),
          ),
          title: Text(
            purchase.invoiceNumber,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            [
              supplierName[purchase.supplierId] ?? l10n.noSupplier,
              DateFormat.yMd(l10n.localeName).format(purchase.purchaseDate),
            ].join(' · '),
          ),
          trailing: Text(
            formatMoney(
              purchase.totalAmount,
              symbol: ref.watch(currencySymbolProvider).valueOrNull ?? r'$',
            ),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final purchasesAsync = ref.watch(purchaseListProvider);
    final suppliersAsync = ref.watch(supplierListProvider);
    final suppliers = suppliersAsync.valueOrNull ?? const <AppSupplier>[];
    final supplierName = {for (final s in suppliers) s.id: s.name};

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      indicatorColor: theme.colorScheme.primary,
                      labelColor: theme.colorScheme.primary,
                      unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                      tabs: const [
                        Tab(
                          icon: Icon(Icons.check_circle_outline, size: 18),
                          text: 'Approved',
                        ),
                        Tab(
                          icon: Icon(Icons.pending_actions, size: 18),
                          text: 'Pending Confirmation',
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                    onPressed: () {
                      ref.read(purchaseRepositoryProvider).refresh();
                      ScaffoldMessenger.of(context)
                        ..clearSnackBars()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text('Refreshing stock purchases list...'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                    },
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _openForm(context),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.newPurchase),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Card(
                  child: purchasesAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, _) => Center(child: Text(l10n.errorOccurred)),
                    data: (purchases) {
                      final approved = purchases
                          .where((p) => p.status == PurchaseStatus.approved)
                          .toList();
                      final pending = purchases
                          .where((p) => p.status == PurchaseStatus.pending)
                          .toList();

                      return TabBarView(
                        children: [
                          _buildList(context, ref, approved, supplierName, theme, l10n),
                          _buildList(context, ref, pending, supplierName, theme, l10n),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
