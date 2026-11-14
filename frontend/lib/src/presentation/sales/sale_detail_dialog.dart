import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../core/services/thermal_printer_service.dart';
import '../../core/utils/labels.dart';
import '../../core/utils/money.dart';
import '../../data/db/enums.dart';
import '../../domain/models/app_sale.dart';
import '../../domain/models/receipt_data.dart';
import '../../l10n/generated/app_localizations.dart';
import '../session/session_controller.dart';
import 'return_dialog.dart';

class SaleDetailDialog extends ConsumerWidget {
  const SaleDetailDialog({
    super.key,
    required this.saleId,
    required this.invoiceNumber,
  });

  final int saleId;
  final String invoiceNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final detailAsync = ref.watch(saleDetailProvider(saleId));

    return AlertDialog(
      title: Text('$invoiceNumber · ${l10n.saleDetail}'),
      content: SizedBox(
        width: 620,
        child: detailAsync.when(
          loading: () => const SizedBox(
            height: 300,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => SizedBox(
            height: 200,
            child: Center(child: Text(l10n.errorOccurred)),
          ),
          data: (detail) => _DetailContent(detail: detail),
        ),
      ),
      actions: [
        if (detailAsync.valueOrNull != null) ...[
          TextButton.icon(
            onPressed: () => _print(context, ref),
            icon: const Icon(Icons.print_outlined),
            label: Text(l10n.printReceipt),
          ),
          TextButton.icon(
            onPressed: detailAsync.value!.sale.status == SaleStatus.returned
                ? null
                : () => _openReturn(context, ref),
            icon: const Icon(Icons.assignment_return_outlined),
            label: Text(l10n.returnItems),
          ),
        ],
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
      ],
    );
  }

  Future<void> _print(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final detail = ref.read(saleDetailProvider(saleId)).value;
    if (detail == null) {
      return;
    }
    final store = await ref.read(settingsRepositoryProvider).getStoreSettings();
    final cashier = await ref
        .read(userRepositoryProvider)
        .findById(detail.sale.userId);
    if (!context.mounted) {
      return;
    }
    final data = ReceiptData(
      store: store,
      invoiceNumber: detail.sale.invoiceNumber,
      dateTime: DateFormat.yMd(
        l10n.localeName,
      ).add_Hm().format(detail.sale.createdAt),
      cashierName: cashier?.displayName ?? '',
      customerName: detail.sale.customerName,
      paymentMethod: paymentMethodLabel(detail.sale.paymentMethod, l10n),
      lines: [
        for (final item in detail.items)
          ReceiptLine(
            name: item.productName,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            totalPrice: item.totalPrice,
          ),
      ],
      subtotal: detail.sale.subtotal,
      discount: detail.sale.discount,
      taxAmount: detail.sale.taxAmount,
      totalAmount: detail.sale.totalAmount,
      paidAmount: detail.sale.paidAmount,
      changeAmount: detail.sale.changeAmount,
    );
    try {
      await ref
          .read(thermalPrinterServiceProvider)
          .printReceipt(
            data,
            labels: ReceiptLabels(
              invoice: l10n.receiptInvoice,
              cashier: l10n.receiptCashier,
              customer: l10n.receiptCustomer,
              subtotal: l10n.subtotal,
              discount: l10n.discount,
              tax: l10n.tax,
              total: l10n.total,
              paid: l10n.amountReceived,
              change: l10n.changeDue,
              onAccount: l10n.receiptOnAccount,
              thanks: l10n.receiptThanks,
            ),
          );
    } on Exception {
      if (!context.mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.printFailed),
          content: Text(l10n.printFailedMessage),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.close),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _openReturn(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final detail = ref.read(saleDetailProvider(saleId)).value;
    final user = ref.read(sessionProvider);
    if (detail == null || user == null) {
      return;
    }
    final processed = await showDialog<bool>(
      context: context,
      builder: (context) =>
          ReturnDialog(detail: detail, currentUserId: user.id),
    );
    if (processed == true) {
      ref.invalidate(saleDetailProvider(saleId));
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(l10n.returnProcessed)));
    }
  }
}

class _DetailContent extends ConsumerWidget {
  const _DetailContent({required this.detail});

  final SaleDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final sale = detail.sale;
    final symbol = ref.watch(currencySymbolProvider).valueOrNull ?? r'$';
    final cashier = ref.watch(cashierNameProvider(sale.userId)).valueOrNull;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              _infoItem(theme, l10n.cashier, cashier ?? ''),
              _infoItem(
                theme,
                l10n.payment,
                paymentMethodLabel(sale.paymentMethod, l10n),
              ),
              if (sale.customerName?.isNotEmpty ?? false)
                _infoItem(theme, l10n.customer, sale.customerName!),
              _infoItem(
                theme,
                l10n.date,
                DateFormat.yMd(l10n.localeName).add_Hm().format(sale.createdAt),
              ),
            ],
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
                      '${item.quantity} x ${formatCents(item.unitPrice)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    formatMoney(item.totalPrice, symbol: symbol),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          const Divider(height: 24),
          _totalLine(theme, l10n.subtotal, sale.subtotal, symbol),
          if (sale.discount > 0)
            _totalLine(theme, l10n.discount, -sale.discount, symbol),
          if (sale.taxAmount > 0)
            _totalLine(theme, l10n.tax, sale.taxAmount, symbol),
          const Divider(height: 16),
          _totalLine(
            theme,
            l10n.total,
            sale.totalAmount,
            symbol,
            bold: true,
            highlight: true,
          ),
          _totalLine(theme, l10n.amountReceived, sale.paidAmount, symbol),
          _totalLine(theme, l10n.changeDue, sale.changeAmount, symbol),
          if (detail.returns.isNotEmpty) ...[
            const Divider(height: 24),
            Text(
              l10n.returns,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            for (final r in detail.returns)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${DateFormat.yMd(l10n.localeName).add_Hm().format(r.createdAt)}'
                        '${r.reason == null ? '' : ' · ${r.reason}'}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    Text(
                      '-${formatMoney(r.totalRefund, symbol: symbol)}',
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _infoItem(ThemeData theme, String label, String value) {
    return RichText(
      text: TextSpan(
        style: theme.textTheme.bodyMedium,
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }

  Widget _totalLine(
    ThemeData theme,
    String label,
    int cents,
    String symbol, {
    bool bold = false,
    bool highlight = false,
  }) {
    final textStyle = bold
        ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
        : theme.textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label, style: textStyle),
          const Spacer(),
          Text(
            formatMoney(cents, symbol: symbol),
            style: textStyle?.copyWith(
              color: highlight ? theme.colorScheme.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}
