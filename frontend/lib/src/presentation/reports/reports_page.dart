import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../app/providers.dart';
import '../../core/utils/csv_export.dart';
import '../../core/utils/labels.dart';
import '../../core/utils/money.dart';
import '../../domain/models/report_depth.dart';
import '../../domain/models/report_summary.dart';
import '../../l10n/generated/app_localizations.dart';

enum _DateFilterPreset {
  today,
  last7Days,
  last30Days,
  thisMonth,
  custom,
}

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  late DateTime _from;
  late DateTime _to;
  _DateFilterPreset _preset = _DateFilterPreset.thisMonth;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _applyPreset(_DateFilterPreset.thisMonth);
  }

  void _applyPreset(_DateFilterPreset preset) {
    final now = DateTime.now();
    setState(() {
      _preset = preset;
      switch (preset) {
        case _DateFilterPreset.today:
          _from = DateTime(now.year, now.month, now.day);
          _to = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case _DateFilterPreset.last7Days:
          final start = now.subtract(const Duration(days: 6));
          _from = DateTime(start.year, start.month, start.day);
          _to = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case _DateFilterPreset.last30Days:
          final start = now.subtract(const Duration(days: 29));
          _from = DateTime(start.year, start.month, start.day);
          _to = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case _DateFilterPreset.thisMonth:
          _from = DateTime(now.year, now.month, 1);
          _to = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case _DateFilterPreset.custom:
          break;
      }
    });
  }

  Future<void> _pickRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (range == null) {
      return;
    }
    setState(() {
      _preset = _DateFilterPreset.custom;
      _from = DateTime(range.start.year, range.start.month, range.start.day);
      _to = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59);
    });
  }

  Future<void> _export(ReportSummary summary) async {
    final l10n = AppLocalizations.of(context);
    final symbol = ref.read(currencySymbolProvider).valueOrNull ?? r'$';
    setState(() => _exporting = true);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final exportsDir = Directory(p.join(dir.path, 'MePharmaExports'));
      await exportsDir.create(recursive: true);
      final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File(p.join(exportsDir.path, 'report_$stamp.csv'));
      await file.writeAsString(_buildCsv(l10n, summary, symbol));
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(l10n.exportedTo(file.path))));
    } on Exception {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(l10n.errorOccurred)));
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  String _buildCsv(
    AppLocalizations l10n,
    ReportSummary summary,
    String symbol,
  ) {
    final buffer = StringBuffer();
    buffer.writeln(
      csvLine([
        l10n.reports,
        '${DateFormat.yMd(l10n.localeName).format(summary.from)} - '
            '${DateFormat.yMd(l10n.localeName).format(summary.to)}',
      ]),
    );
    buffer.writeln();
    buffer.writeln(csvLine([l10n.salesCount, '${summary.salesCount}']));
    buffer.writeln(csvLine([l10n.grossRevenue, formatMoney(summary.grossRevenue ?? summary.revenue, symbol: symbol)]));
    buffer.writeln(csvLine([l10n.totalDiscounts, formatMoney(summary.totalDiscount, symbol: symbol)]));
    buffer.writeln(csvLine([l10n.totalTax, formatMoney(summary.totalTax, symbol: symbol)]));
    buffer.writeln(csvLine([l10n.revenue, formatMoney(summary.revenue, symbol: symbol)]));
    buffer.writeln(csvLine([l10n.refunds, formatMoney(summary.refunds, symbol: symbol)]));
    buffer.writeln(csvLine([l10n.netRevenue, formatMoney(summary.netRevenue, symbol: symbol)]));
    buffer.writeln(csvLine([l10n.cogs, formatMoney(summary.costOfGoods, symbol: symbol)]));
    buffer.writeln(csvLine([l10n.estimatedProfit, formatMoney(summary.estimatedProfit, symbol: symbol)]));
    buffer.writeln(csvLine([l10n.profitMargin, '${summary.profitMarginPct.toStringAsFixed(1)}%']));
    buffer.writeln(csvLine([l10n.averageOrderValue, formatMoney(summary.averageOrderValue, symbol: symbol)]));
    buffer.writeln(csvLine([l10n.purchasesCost, formatMoney(summary.purchasesCost, symbol: symbol)]));
    buffer.writeln(csvLine([l10n.lowStockItems, '${summary.lowStockCount}']));
    buffer.writeln();
    buffer.writeln(csvLine([l10n.salesByPayment]));
    buffer.writeln(csvLine([l10n.payment, l10n.salesCount, l10n.total, '%']));
    for (final row in summary.salesByPayment) {
      buffer.writeln(
        csvLine([
          paymentMethodLabel(row.method, l10n),
          '${row.count}',
          formatMoney(row.total, symbol: symbol),
          '${row.percentage.toStringAsFixed(1)}%',
        ]),
      );
    }
    buffer.writeln();
    buffer.writeln(csvLine([l10n.topProducts]));
    buffer.writeln(csvLine([l10n.productName, l10n.quantity, l10n.revenue, l10n.margin]));
    for (final row in summary.topProducts) {
      buffer.writeln(
        csvLine([
          row.name,
          '${row.quantity}',
          formatMoney(row.revenue, symbol: symbol),
          '${row.marginPct.toStringAsFixed(1)}%',
        ]),
      );
    }
    return buffer.toString();
  }

  void _showPrintDialog(ReportSummary summary, StockValuation? valuation) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _PrintReportDialog(
        summary: summary,
        valuation: valuation,
        from: _from,
        to: _to,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final symbol = ref.watch(currencySymbolProvider).valueOrNull ?? r'$';
    final summaryAsync = ref.watch(reportSummaryProvider((from: _from, to: _to)));
    final valuation = ref.watch(stockValuationProvider).valueOrNull;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Executive Header Bar
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
                      child: Icon(Icons.analytics_outlined, color: theme.colorScheme.primary, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.reports,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${DateFormat.yMMMd(l10n.localeName).format(_from)} — ${DateFormat.yMMMd(l10n.localeName).format(_to)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Wrap(
                  spacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickRange,
                      icon: const Icon(Icons.calendar_today_outlined, size: 16),
                      label: Text(
                        '${DateFormat.MMMd(l10n.localeName).format(_from)} - ${DateFormat.MMMd(l10n.localeName).format(_to)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: summaryAsync.hasValue ? () => _showPrintDialog(summaryAsync.value!, valuation) : null,
                      icon: const Icon(Icons.print_outlined, size: 18),
                      label: Text(l10n.printReport),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: summaryAsync.hasValue && !_exporting
                          ? () => _export(summaryAsync.value!)
                          : null,
                      icon: _exporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.file_download_outlined, size: 18),
                      label: Text(l10n.exportCsv),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    IconButton(
                      tooltip: 'تحديث / Refresh',
                      icon: const Icon(Icons.refresh, size: 20),
                      onPressed: () {
                        ref.invalidate(reportSummaryProvider);
                        ref.invalidate(categoryReportProvider);
                        ref.invalidate(monthlyReportProvider);
                        ref.invalidate(stockValuationProvider);
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Date Range Preset Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _presetChip(_DateFilterPreset.today, l10n.today, theme),
                  const SizedBox(width: 8),
                  _presetChip(_DateFilterPreset.last7Days, l10n.last7Days, theme),
                  const SizedBox(width: 8),
                  _presetChip(_DateFilterPreset.last30Days, l10n.last30Days, theme),
                  const SizedBox(width: 8),
                  _presetChip(_DateFilterPreset.thisMonth, l10n.thisMonth, theme),
                  const SizedBox(width: 8),
                  _presetChip(_DateFilterPreset.custom, l10n.customRange, theme, onTapOverride: _pickRange),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Main Content Area
            Expanded(
              child: summaryAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => Center(child: Text(l10n.errorOccurred)),
                data: (summary) => SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 4 Executive Financial Pillars
                      _buildExecutiveKpiCards(theme, l10n, summary, valuation, symbol),
                      const SizedBox(height: 16),

                      // Secondary Deductions & Operational Strip
                      _buildSecondaryTelemetryStrip(theme, l10n, summary, symbol),
                      const SizedBox(height: 24),

                      // Interactive Daily Sales & Revenue Trend Chart
                      if (summary.trends.isNotEmpty) ...[
                        _DailyTrendsChartCard(trends: summary.trends, symbol: symbol),
                        const SizedBox(height: 24),
                      ],

                      // Two Column Row: Payment Methods & Top Earners
                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth > 900) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: _PaymentCard(summary: summary, symbol: symbol),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 6,
                                  child: _TopProductsCard(summary: summary, symbol: symbol),
                                ),
                              ],
                            );
                          }
                          return Column(
                            children: [
                              _PaymentCard(summary: summary, symbol: symbol),
                              const SizedBox(height: 16),
                              _TopProductsCard(summary: summary, symbol: symbol),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      // Category Profitability Matrix & 12-Month Ledger
                      _DepthSection(from: _from, to: _to),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _presetChip(
    _DateFilterPreset preset,
    String label,
    ThemeData theme, {
    VoidCallback? onTapOverride,
  }) {
    final selected = _preset == preset;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        if (onTapOverride != null) {
          onTapOverride();
        } else {
          _applyPreset(preset);
        }
      },
      selectedColor: theme.colorScheme.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
        ),
      ),
    );
  }

  Widget _buildExecutiveKpiCards(
    ThemeData theme,
    AppLocalizations l10n,
    ReportSummary summary,
    StockValuation? valuation,
    String symbol,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int columns = 4;
        if (width < 600) {
          columns = 1;
        } else if (width < 1000) {
          columns = 2;
        }

        final cards = [
          _ExecutiveCardData(
            title: l10n.netRevenue,
            value: formatMoney(summary.netRevenue, symbol: symbol),
            subtitle: '${l10n.grossRevenue}: ${formatMoney(summary.grossRevenue ?? summary.revenue, symbol: symbol)}',
            icon: Icons.account_balance_wallet_outlined,
            color: const Color(0xFF7367F0), // Primary Indigo
            badgeText: '${summary.salesCount} ${l10n.invoicesCount}',
          ),
          _ExecutiveCardData(
            title: l10n.estimatedProfit,
            value: formatMoney(summary.estimatedProfit, symbol: symbol),
            subtitle: '${l10n.profitMargin}: ${summary.profitMarginPct.toStringAsFixed(1)}%',
            icon: Icons.trending_up,
            color: summary.estimatedProfit >= 0 ? const Color(0xFF28C76F) : const Color(0xFFEA5455), // Emerald / Red
            badgeText: '${summary.profitMarginPct >= 0 ? '+' : ''}${summary.profitMarginPct.toStringAsFixed(1)}%',
            badgeColor: summary.estimatedProfit >= 0 ? const Color(0xFF28C76F) : const Color(0xFFEA5455),
          ),
          _ExecutiveCardData(
            title: l10n.cogs,
            value: formatMoney(summary.costOfGoods, symbol: symbol),
            subtitle: '${l10n.purchasesCost}: ${formatMoney(summary.purchasesCost, symbol: symbol)}',
            icon: Icons.inventory_2_outlined,
            color: const Color(0xFFFF9F43), // Amber
            badgeText: '${l10n.averageOrderValue}: ${formatMoney(summary.averageOrderValue, symbol: symbol)}',
            badgeColor: const Color(0xFFFF9F43),
          ),
          _ExecutiveCardData(
            title: l10n.stockValuationTitle,
            value: formatMoney(valuation?.retailValue ?? 0, symbol: symbol),
            subtitle: '${l10n.stockCostBasis}: ${formatMoney(valuation?.costValue ?? 0, symbol: symbol)}',
            icon: Icons.storefront_outlined,
            color: const Color(0xFF00CFE8), // Info Cyan
            badgeText: '${valuation?.potentialMarginPct.toStringAsFixed(1) ?? '0.0'}% ${l10n.margin}',
            badgeColor: const Color(0xFF00CFE8),
          ),
        ];

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            mainAxisExtent: 140,
          ),
          itemCount: cards.length,
          itemBuilder: (context, i) {
            final c = cards[i];
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          c.title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: c.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(c.icon, size: 20, color: c.color),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            c.value,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: c.color,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (c.badgeText != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (c.badgeColor ?? c.color).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              c.badgeText!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: c.badgeColor ?? c.color,
                              ),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      c.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSecondaryTelemetryStrip(
    ThemeData theme,
    AppLocalizations l10n,
    ReportSummary summary,
    String symbol,
  ) {
    final items = [
      (Icons.discount_outlined, l10n.totalDiscounts, formatMoney(summary.totalDiscount, symbol: symbol), theme.colorScheme.onSurface),
      (Icons.receipt_outlined, l10n.totalTax, formatMoney(summary.totalTax, symbol: symbol), theme.colorScheme.onSurface),
      (Icons.assignment_return_outlined, l10n.refunds, formatMoney(summary.refunds, symbol: symbol), const Color(0xFFEA5455)),
      (Icons.local_shipping_outlined, l10n.totalPurchasesCount, '${summary.totalPurchases}', theme.colorScheme.onSurface),
      (Icons.warning_amber_outlined, l10n.lowStockItems, '${summary.lowStockCount}', summary.lowStockCount > 0 ? const Color(0xFFFF9F43) : theme.colorScheme.onSurface),
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 700;
            if (isNarrow) {
              return Wrap(
                spacing: 16,
                runSpacing: 12,
                children: [
                  for (final it in items)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(it.$1, size: 16, color: it.$4),
                        const SizedBox(width: 6),
                        Text('${it.$2}: ', style: theme.textTheme.bodySmall),
                        Text(it.$3, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: it.$4)),
                      ],
                    ),
                ],
              );
            }

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(items[i].$1, size: 16, color: items[i].$4),
                      const SizedBox(width: 6),
                      Text('${items[i].$2}: ', style: theme.textTheme.bodySmall),
                      Text(items[i].$3, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: items[i].$4)),
                    ],
                  ),
                  if (i < items.length - 1)
                    Container(height: 16, width: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ExecutiveCardData {
  const _ExecutiveCardData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.badgeText,
    this.badgeColor,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? badgeText;
  final Color? badgeColor;
}

class _DailyTrendsChartCard extends StatelessWidget {
  const _DailyTrendsChartCard({required this.trends, required this.symbol});

  final List<DailyTrend> trends;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    if (trends.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxRevenue = trends.map((t) => t.revenue).fold(1, (a, b) => a > b ? a : b);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.show_chart_outlined, size: 22, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  l10n.salesTrends,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l10n.salesTrendsSubtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 160,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final t in trends)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Tooltip(
                              message: '${t.date}\n${formatMoney(t.revenue, symbol: symbol)} (${t.count} ${l10n.invoicesCount})',
                              child: Container(
                                height: ((t.revenue / maxRevenue) * 110).clamp(6.0, 110.0),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      theme.colorScheme.primary,
                                      theme.colorScheme.primary.withValues(alpha: 0.6),
                                    ],
                                  ),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              t.date.length >= 5 ? t.date.substring(t.date.length - 5) : t.date,
                              style: TextStyle(
                                fontSize: 10,
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.summary, required this.symbol});

  final ReportSummary summary;
  final String symbol;

  Color _getMethodColor(String? method) {
    switch (method?.toLowerCase()) {
      case 'cash':
        return const Color(0xFF28C76F); // Emerald
      case 'card':
        return const Color(0xFF7367F0); // Indigo
      case 'mobilemoney':
      case 'mobile_money':
        return const Color(0xFF00CFE8); // Cyan
      case 'credit':
        return const Color(0xFFFF9F43); // Orange
      default:
        return const Color(0xFFA8AAAE); // Grey
    }
  }

  IconData _getMethodIcon(String? method) {
    switch (method?.toLowerCase()) {
      case 'cash':
        return Icons.payments_outlined;
      case 'card':
        return Icons.credit_card_outlined;
      case 'mobilemoney':
      case 'mobile_money':
        return Icons.phone_android_outlined;
      case 'credit':
        return Icons.receipt_long_outlined;
      default:
        return Icons.monetization_on_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pie_chart_outline, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  l10n.salesByPayment,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l10n.paymentBreakdownSubtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (summary.salesByPayment.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text(l10n.noData, style: theme.textTheme.bodySmall)),
              )
            else
              for (final row in summary.salesByPayment) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(_getMethodIcon(row.method), size: 16, color: _getMethodColor(row.method)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              paymentMethodLabel(row.method, l10n),
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${row.count}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            formatMoney(row.total, symbol: symbol),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 48,
                            child: Text(
                              '${row.percentage.toStringAsFixed(1)}%',
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _getMethodColor(row.method),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (row.percentage / 100).clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          valueColor: AlwaysStoppedAnimation<Color>(_getMethodColor(row.method)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
          ],
        ),
      ),
    );
  }
}

class _TopProductsCard extends StatelessWidget {
  const _TopProductsCard({required this.summary, required this.symbol});

  final ReportSummary summary;
  final String symbol;

  Color _rankColor(int index) {
    if (index == 0) return const Color(0xFFFFD700); // Gold
    if (index == 1) return const Color(0xFFC0C0C0); // Silver
    if (index == 2) return const Color(0xFFCD7F32); // Bronze
    return const Color(0xFF7367F0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.emoji_events_outlined, size: 20, color: const Color(0xFFFF9F43)),
                const SizedBox(width: 8),
                Text(
                  l10n.topProducts,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l10n.topProductsSubtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (summary.topProducts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text(l10n.noData, style: theme.textTheme.bodySmall)),
              )
            else
              for (int i = 0; i < summary.topProducts.length; i++) ...[
                () {
                  final prod = summary.topProducts[i];
                  final rColor = _rankColor(i);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: rColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '#${i + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: rColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            prod.name,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${prod.quantity} ${l10n.unitsSold}',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF28C76F).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${prod.marginPct.toStringAsFixed(1)}% ${l10n.margin}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF28C76F),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          formatMoney(prod.revenue, symbol: symbol),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  );
                }(),
                if (i < summary.topProducts.length - 1)
                  Divider(height: 12, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
              ],
          ],
        ),
      ),
    );
  }
}

class _DepthSection extends ConsumerWidget {
  const _DepthSection({required this.from, required this.to});

  final DateTime from;
  final DateTime to;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final symbol = ref.watch(currencySymbolProvider).valueOrNull ?? r'$';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Profitability Matrix
        Row(
          children: [
            Icon(Icons.category_outlined, color: theme.colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              l10n.profitByCategory,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ref.watch(categoryReportProvider((from: from, to: to))).when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
              error: (_, _) => Center(child: Text(l10n.errorOccurred)),
              data: (categories) => categories.isEmpty
                  ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(l10n.noData, style: theme.textTheme.bodySmall)))
                  : Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Text(
                                l10n.category,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                l10n.unitsSold,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                l10n.revenue,
                                textAlign: TextAlign.end,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                l10n.estimatedProfit,
                                textAlign: TextAlign.end,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                l10n.margin,
                                textAlign: TextAlign.end,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        for (final row in categories)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: Text(
                                    row.categoryName,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '${row.salesCount}',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    formatMoney(row.revenue, symbol: symbol),
                                    textAlign: TextAlign.end,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    formatMoney(row.profit, symbol: symbol),
                                    textAlign: TextAlign.end,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: row.profit < 0
                                          ? const Color(0xFFEA5455)
                                          : const Color(0xFF28C76F),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '${row.calculatedMarginPct.toStringAsFixed(1)}%',
                                    textAlign: TextAlign.end,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: row.calculatedMarginPct >= 20
                                          ? const Color(0xFF28C76F)
                                          : const Color(0xFFFF9F43),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // 12-Month Historical Financial Ledger
        Row(
          children: [
            Icon(Icons.calendar_month_outlined, color: theme.colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              l10n.annualLedger,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          l10n.annualLedgerSubtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ref.watch(monthlyReportProvider).when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
              error: (_, _) => Center(child: Text(l10n.errorOccurred)),
              data: (months) => months.isEmpty
                  ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(l10n.noData, style: theme.textTheme.bodySmall)))
                  : Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                l10n.month,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                l10n.invoicesCount,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                l10n.grossRevenue,
                                textAlign: TextAlign.end,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                l10n.netRevenue,
                                textAlign: TextAlign.end,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                l10n.margin,
                                textAlign: TextAlign.end,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        for (final month in months)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    '${_monthName(month.month, l10n)} ${month.year}',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '${month.salesCount}',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    formatMoney(month.revenue, symbol: symbol),
                                    textAlign: TextAlign.end,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    formatMoney(month.netRevenue, symbol: symbol),
                                    textAlign: TextAlign.end,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: month.netRevenue < 0
                                          ? const Color(0xFFEA5455)
                                          : const Color(0xFF7367F0),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '${month.calculatedMarginPct.toStringAsFixed(1)}%',
                                    textAlign: TextAlign.end,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: month.calculatedMarginPct >= 20
                                          ? const Color(0xFF28C76F)
                                          : const Color(0xFFFF9F43),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  static String _monthName(int month, AppLocalizations l10n) {
    return DateFormat('MMM', l10n.localeName).format(
      DateTime(2020, month),
    );
  }
}

class _PrintReportDialog extends ConsumerWidget {
  const _PrintReportDialog({
    required this.summary,
    required this.valuation,
    required this.from,
    required this.to,
  });

  final ReportSummary summary;
  final StockValuation? valuation;
  final DateTime from;
  final DateTime to;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final symbol = ref.watch(currencySymbolProvider).valueOrNull ?? r'$';
    final storeName = ref.watch(storeSettingsProvider).valueOrNull?.storeName ?? 'MePharma';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dialog Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.print_outlined, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        l10n.printPreview,
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(height: 20),

              // Printable Invoice / Report Body
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Column(
                            children: [
                              Text(
                                storeName,
                                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.financialLedgerSummary,
                                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${DateFormat.yMMMd(l10n.localeName).format(from)} — ${DateFormat.yMMMd(l10n.localeName).format(to)}',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),

                        _rowMetric(l10n.grossRevenue, formatMoney(summary.grossRevenue ?? summary.revenue, symbol: symbol)),
                        _rowMetric(l10n.totalDiscounts, '- ${formatMoney(summary.totalDiscount, symbol: symbol)}'),
                        _rowMetric(l10n.totalTax, '+ ${formatMoney(summary.totalTax, symbol: symbol)}'),
                        _rowMetric(l10n.refunds, '- ${formatMoney(summary.refunds, symbol: symbol)}'),
                        const Divider(height: 16),
                        _rowMetric(l10n.netRevenue, formatMoney(summary.netRevenue, symbol: symbol), isBold: true, color: const Color(0xFF7367F0)),
                        _rowMetric(l10n.cogs, formatMoney(summary.costOfGoods, symbol: symbol)),
                        _rowMetric(l10n.estimatedProfit, formatMoney(summary.estimatedProfit, symbol: symbol), isBold: true, color: const Color(0xFF28C76F)),
                        _rowMetric(l10n.profitMargin, '${summary.profitMarginPct.toStringAsFixed(1)}%', isBold: true),
                        _rowMetric(l10n.averageOrderValue, formatMoney(summary.averageOrderValue, symbol: symbol)),
                        _rowMetric(l10n.salesCount, '${summary.salesCount} ${l10n.invoicesCount}'),
                        if (valuation != null) ...[
                          const Divider(height: 16),
                          _rowMetric(l10n.stockValuationTitle, formatMoney(valuation!.retailValue, symbol: symbol), isBold: true),
                          _rowMetric(l10n.stockCostBasis, formatMoney(valuation!.costValue, symbol: symbol)),
                          _rowMetric(l10n.potentialStockProfit, formatMoney(valuation!.potentialProfit, symbol: symbol), color: const Color(0xFF28C76F)),
                        ],
                        const SizedBox(height: 16),
                        const Divider(),
                        Center(
                          child: Text(
                            'Printed on ${DateFormat.yMd().add_jm().format(DateTime.now())}',
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.cancel),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.printReport)),
                      );
                    },
                    icon: const Icon(Icons.print, size: 18),
                    label: Text(l10n.printReport),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rowMetric(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              fontSize: 13,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
