import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../core/utils/labels.dart';
import '../../core/utils/money.dart';
import '../../data/db/enums.dart';
import '../../domain/models/app_sale.dart';
import '../../l10n/generated/app_localizations.dart';
import 'sale_detail_dialog.dart';

class SalesHistoryPage extends ConsumerStatefulWidget {
  const SalesHistoryPage({super.key});

  @override
  ConsumerState<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends ConsumerState<SalesHistoryPage> {
  final _searchController = TextEditingController();
  DateTime? _from;
  DateTime? _to;
  String? _payment;
  SaleStatus? _status;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  SaleFilter get _filter => (
        from: _from,
        to: _to,
        paymentMethod: _payment,
        status: _status,
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
      );

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _from == null || _to == null
          ? null
          : DateTimeRange(start: _from!, end: _to!),
      helpText: '${AppLocalizations.of(context).from} - ${AppLocalizations.of(context).to}',
    );
    if (range == null) {
      return;
    }
    setState(() {
      _from = DateTime(range.start.year, range.start.month, range.start.day);
      _to = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59);
    });
  }

  void _resetFilters() {
    setState(() {
      _from = null;
      _to = null;
      _payment = null;
      _status = null;
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final salesAsync = ref.watch(salesHistoryListProvider(_filter));

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _filterBar(l10n, theme),
            const SizedBox(height: 16),
            Expanded(
              child: salesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, _) => Center(child: Text(l10n.errorOccurred)),
                data: (sales) {
                  if (sales.isEmpty) {
                    return Card(
                      child: Center(
                        child: Text(
                          l10n.noSales,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  }

                  final pendingInvoices = ref.watch(pendingSyncInvoicesProvider).value ?? <String>{};
                  final localSales = sales
                      .where((s) => pendingInvoices.contains(s.invoiceNumber))
                      .toList();
                  final serverSales = sales
                      .where((s) => !pendingInvoices.contains(s.invoiceNumber))
                      .toList();

                  return ListView(
                    children: [
                      if (localSales.isNotEmpty) ...[
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: theme.colorScheme.error.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          color: theme.colorScheme.errorContainer.withValues(alpha: 0.15),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.cloud_off_rounded,
                                      color: theme.colorScheme.error,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Local Offline Transactions (${localSales.length})',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.error,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton.tonalIcon(
                                      onPressed: () {
                                        ref.read(syncEngineProvider).triggerSync();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Synchronizing local transactions with server...'),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.sync, size: 16),
                                      label: const Text('Sync Now'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'These transactions were saved to local SQLite while offline. They will automatically sync with the server once connected.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: localSales.length,
                                  separatorBuilder: (_, _) => const Divider(height: 1),
                                  itemBuilder: (context, index) =>
                                      _SaleTile(sale: localSales[index], isLocal: true),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.cloud_done_rounded,
                                    color: theme.colorScheme.primary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Server Synced Master Stream (${serverSales.length})',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            serverSales.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Center(
                                      child: Text(
                                        'No server-synced records matching filter.',
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: serverSales.length,
                                    separatorBuilder: (_, _) => const Divider(height: 1),
                                    itemBuilder: (context, index) =>
                                        _SaleTile(sale: serverSales[index], isLocal: false),
                                  ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterBar(AppLocalizations l10n, ThemeData theme) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 260,
          child: TextField(
            controller: _searchController,
            onSubmitted: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: l10n.searchInvoice,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(_searchController.clear),
                    ),
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: _pickDateRange,
          icon: const Icon(Icons.date_range),
          label: Text(
            _from == null || _to == null
                ? l10n.dateRange
                : '${DateFormat.yMd(l10n.localeName).format(_from!)} - '
                    '${DateFormat.yMd(l10n.localeName).format(_to!)}',
          ),
        ),
        DropdownButton<String?>(
          value: _payment,
          hint: Text(l10n.payment),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(l10n.paymentAll),
            ),
            for (final method in const ['cash', 'card', 'mobileMoney'])
              DropdownMenuItem<String?>(
                value: method,
                child: Text(paymentMethodLabel(method, l10n)),
              ),
          ],
          onChanged: (value) => setState(() => _payment = value),
        ),
        DropdownButton<SaleStatus?>(
          value: _status,
          hint: Text(l10n.status),
          items: [
            DropdownMenuItem<SaleStatus?>(
              value: null,
              child: Text(l10n.statusAll),
            ),
            DropdownMenuItem<SaleStatus?>(
              value: SaleStatus.completed,
              child: Text(saleStatusLabel(SaleStatus.completed, l10n)),
            ),
            DropdownMenuItem<SaleStatus?>(
              value: SaleStatus.returned,
              child: Text(saleStatusLabel(SaleStatus.returned, l10n)),
            ),
          ],
          onChanged: (value) => setState(() => _status = value),
        ),
        if (_from != null || _to != null || _payment != null || _status != null)
          IconButton(
            tooltip: l10n.resetFilters,
            icon: const Icon(Icons.filter_alt_off_outlined),
            onPressed: _resetFilters,
          ),
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
          onPressed: () {
            ref.read(saleRepositoryProvider).refresh();
            ScaffoldMessenger.of(context)
              ..clearSnackBars()
              ..showSnackBar(
                const SnackBar(
                  content: Text('Refreshing sales history...'),
                  duration: Duration(seconds: 1),
                ),
              );
          },
        ),
      ],
    );
  }
}

class _SaleTile extends ConsumerWidget {
  const _SaleTile({
    required this.sale,
    this.isLocal = false,
  });

  final AppSale sale;
  final bool isLocal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final currency = ref.watch(currencySymbolProvider).valueOrNull ?? r'$';

    final icon = switch (sale.paymentMethod) {
      'card' => Icons.credit_card,
      'mobileMoney' => Icons.phone_android,
      _ => Icons.payments_outlined,
    };

    final statusColor = switch (sale.status) {
      SaleStatus.completed => theme.colorScheme.tertiaryContainer,
      SaleStatus.returned => theme.colorScheme.errorContainer,
      SaleStatus.voided => theme.colorScheme.errorContainer,
    };

    return ListTile(
      onTap: () {
        showDialog<void>(
          context: context,
          builder: (context) =>
              SaleDetailDialog(saleId: sale.id, invoiceNumber: sale.invoiceNumber),
        );
      },
      leading: CircleAvatar(
        backgroundColor: isLocal ? theme.colorScheme.errorContainer : null,
        child: Icon(
          isLocal ? Icons.cloud_off_rounded : icon,
          color: isLocal ? theme.colorScheme.error : null,
        ),
      ),
      title: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            sale.invoiceNumber,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (isLocal)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule, size: 12, color: theme.colorScheme.error),
                  const SizedBox(width: 4),
                  Text(
                    'LOCAL (PENDING SYNC)',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              saleStatusLabel(sale.status, l10n),
              style: theme.textTheme.labelSmall,
            ),
          ),
        ],
      ),
      subtitle: Text(
        [
          DateFormat.yMd(l10n.localeName)
              .add_Hm()
              .format(sale.createdAt),
          paymentMethodLabel(sale.paymentMethod, l10n),
          if (sale.customerName?.isNotEmpty ?? false) sale.customerName!,
          if (isLocal) 'Queued in SQLite',
        ].join(' · '),
      ),
      trailing: Text(
        formatMoney(sale.totalAmount, symbol: currency),
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
