import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../core/utils/money.dart';
import '../../data/db/enums.dart';
import '../../domain/models/app_return.dart';
import '../../l10n/generated/app_localizations.dart';
import '../sales/return_dialog.dart';
import '../sales/sale_detail_dialog.dart';
import '../session/session_controller.dart';

class ReturnsPage extends ConsumerStatefulWidget {
  const ReturnsPage({super.key});

  @override
  ConsumerState<ReturnsPage> createState() => _ReturnsPageState();
}

class _ReturnsPageState extends ConsumerState<ReturnsPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openNewReturnFlow(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => const _NewReturnInvoicePickerDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final symbol = ref.watch(currencySymbolProvider).valueOrNull ?? r'$';
    final returnsAsync = ref.watch(allReturnsProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Executive Header
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.assignment_return_outlined,
                        color: theme.colorScheme.primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.salesReturns,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          l10n.returnsSubtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                FilledButton.icon(
                  onPressed: () => _openNewReturnFlow(context),
                  icon: const Icon(Icons.add_shopping_cart, size: 18),
                  label: Text(l10n.newReturn),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Search Bar & Telemetry Row
            returnsAsync.when(
              data: (List<AppReturn> allReturns) {
                final query = _searchController.text.trim().toLowerCase();
                final filtered = query.isEmpty
                    ? allReturns
                    : allReturns.where((r) {
                        return r.invoiceNumber.toLowerCase().contains(query) ||
                            (r.reason?.toLowerCase().contains(query) ?? false);
                      }).toList();

                final totalRefunds = allReturns.fold<int>(
                  0,
                  (sum, r) => sum + r.totalRefund,
                );

                return Expanded(
                  child: Column(
                    children: [
                      // KPI Strip
                      Row(
                        children: [
                          Expanded(
                            child: Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: theme.colorScheme.outlineVariant
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.replay_circle_filled_outlined,
                                      color: const Color(0xFFEA5455),
                                      size: 28,
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${allReturns.length}',
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          l10n.salesReturns,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: theme.colorScheme
                                                .onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: theme.colorScheme.outlineVariant
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.money_off_outlined,
                                      color: const Color(0xFFFF9F43),
                                      size: 28,
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          formatMoney(totalRefunds,
                                              symbol: symbol),
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFFEA5455),
                                          ),
                                        ),
                                        Text(
                                          l10n.refundAmount,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: theme.colorScheme
                                                .onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Search Input
                      TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: l10n.searchByInvoiceOrReason,
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          isDense: true,
                          filled: true,
                          fillColor: theme.colorScheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Returns Table / List
                      Expanded(
                        child: filtered.isEmpty
                            ? Card(
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.assignment_return_outlined,
                                        size: 48,
                                        color: theme
                                            .colorScheme.onSurfaceVariant
                                            .withValues(alpha: 0.5),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        l10n.noReturns,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: theme.colorScheme.outlineVariant
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                                child: ListView.separated(
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, _) => Divider(
                                    height: 1,
                                    color: theme.colorScheme.outlineVariant
                                        .withValues(alpha: 0.3),
                                  ),
                                  itemBuilder: (context, index) {
                                    final item = filtered[index];
                                    final dateStr = DateFormat.yMd(
                                      l10n.localeName,
                                    ).add_Hm().format(item.createdAt);

                                    return ListTile(
                                      leading: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEA5455)
                                              .withValues(alpha: 0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.assignment_return_outlined,
                                          color: Color(0xFFEA5455),
                                          size: 20,
                                        ),
                                      ),
                                      title: Row(
                                        children: [
                                          Text(
                                            item.invoiceNumber,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            dateStr,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              color: theme.colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                      subtitle: item.reason != null &&
                                              item.reason!.isNotEmpty
                                          ? Text(
                                              '${l10n.returnReason}: ${item.reason}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: theme.colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                            )
                                          : null,
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            formatMoney(item.totalRefund,
                                                symbol: symbol),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: Color(0xFFEA5455),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            tooltip: l10n.saleDetail,
                                            icon: const Icon(
                                              Icons.visibility_outlined,
                                              size: 18,
                                            ),
                                            onPressed: () {
                                              showDialog<void>(
                                                context: context,
                                                builder: (context) =>
                                                    SaleDetailDialog(
                                                  saleId: item.saleId,
                                                  invoiceNumber:
                                                      item.invoiceNumber,
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                      ),
                    ],
                  ),
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(child: Text(l10n.errorOccurred)),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewReturnInvoicePickerDialog extends ConsumerStatefulWidget {
  const _NewReturnInvoicePickerDialog();

  @override
  ConsumerState<_NewReturnInvoicePickerDialog> createState() =>
      _NewReturnInvoicePickerDialogState();
}

class _NewReturnInvoicePickerDialogState
    extends ConsumerState<_NewReturnInvoicePickerDialog> {
  final _invoiceController = TextEditingController();
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _invoiceController.dispose();
    super.dispose();
  }

  Future<void> _findAndOpenReturn() async {
    final query = _invoiceController.text.trim();
    if (query.isEmpty) return;

    final l10n = AppLocalizations.of(context);
    final user = ref.read(sessionProvider);
    if (user == null) return;

    setState(() {
      _searching = true;
      _error = null;
    });

    try {
      final saleRepo = ref.read(saleRepositoryProvider);
      final sales = await saleRepo.watchSales(
        status: SaleStatus.completed,
        search: query,
      ).first;

      final match = sales.firstWhere(
        (s) => s.invoiceNumber.toLowerCase() == query.toLowerCase(),
        orElse: () => sales.isNotEmpty
            ? sales.first
            : throw StateError('Invoice not found'),
      );

      final detail = await saleRepo.getSaleDetail(match.id);

      if (!mounted) return;
      Navigator.of(context).pop();

      await showDialog<bool>(
        context: context,
        builder: (context) =>
            ReturnDialog(detail: detail, currentUserId: user.id),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _searching = false;
          _error = l10n.errorOccurred;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.assignment_return_outlined,
              color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(l10n.selectSaleToReturn),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _invoiceController,
              autofocus: true,
              onSubmitted: (_) => _findAndOpenReturn(),
              decoration: InputDecoration(
                hintText: l10n.searchInvoice,
                prefixIcon: const Icon(Icons.receipt_long),
                errorText: _error,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _searching ? null : _findAndOpenReturn,
          child: _searching
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.returnItems),
        ),
      ],
    );
  }
}
