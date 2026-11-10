import 'package:flutter/material.dart';

import '../../core/utils/money.dart';
import '../../domain/models/payment_method.dart';
import '../../l10n/generated/app_localizations.dart';

/// Collects the payment method and, for cash, the amount received.
class PaymentDialog extends StatefulWidget {
  const PaymentDialog({
    super.key,
    required this.subtotalCents,
    required this.discountCents,
    required this.taxCents,
    required this.totalCents,
    required this.currencySymbol,
    this.allowCredit = false,
    this.hasCustomer = false,
    this.outstandingCents = 0,
    this.creditLimitCents = 0,
  });

  final int subtotalCents;
  final int discountCents;
  final int taxCents;
  final int totalCents;
  final String currencySymbol;

  /// Whether the "on account" (credit) option is shown.
  final bool allowCredit;

  /// Whether a customer is attached to the current sale.
  final bool hasCustomer;

  /// The customer's outstanding balance in cents (0 when walk-in).
  final int outstandingCents;

  /// The customer's credit limit in cents (0 = no limit).
  final int creditLimitCents;

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  final _receivedController = TextEditingController();
  PaymentMethod _method = PaymentMethod.cash;

  @override
  void initState() {
    super.initState();
    _receivedController.text =
        formatCents(widget.totalCents, withSeparator: true);
  }

  @override
  void dispose() {
    _receivedController.dispose();
    super.dispose();
  }

  int get _received =>
      parseCents(_receivedController.text.replaceAll(',', ''));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final symbol = widget.currencySymbol;
    final isCash = _method == PaymentMethod.cash;
    final isCredit = _method == PaymentMethod.credit;
    final received = isCash ? _received : widget.totalCents;
    final change = received > widget.totalCents
        ? received - widget.totalCents
        : 0;
    // A limit of 0 means the customer has no credit limit.
    final overLimit = isCredit &&
        widget.creditLimitCents > 0 &&
        widget.outstandingCents + widget.totalCents > widget.creditLimitCents;
    final valid = isCredit
        ? widget.hasCustomer && !overLimit
        : isCash
            ? received >= widget.totalCents
            : true;

    return AlertDialog(
      title: Text(l10n.payment),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.discountCents > 0 || widget.taxCents > 0)
                Row(
                  children: [
                    Text(l10n.subtotal),
                    const Spacer(),
                    Text(formatMoney(widget.subtotalCents, symbol: symbol)),
                  ],
                ),
              if (widget.discountCents > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Text(l10n.discount),
                      const Spacer(),
                      Text(
                        '-${formatMoney(widget.discountCents, symbol: symbol)}',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                  ),
                ),
              if (widget.taxCents > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Text(l10n.tax),
                      const Spacer(),
                      Text(formatMoney(widget.taxCents, symbol: symbol)),
                    ],
                  ),
                ),
              const Divider(height: 24),
              Row(
                children: [
                  Text(
                    l10n.total,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formatMoney(widget.totalCents, symbol: symbol),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SegmentedButton<PaymentMethod>(
                segments: [
                  ButtonSegment(
                    value: PaymentMethod.cash,
                    label: Text(l10n.paymentCash),
                    icon: const Icon(Icons.payments_outlined),
                  ),
                  ButtonSegment(
                    value: PaymentMethod.card,
                    label: Text(l10n.paymentCard),
                    icon: const Icon(Icons.credit_card),
                  ),
                  ButtonSegment(
                    value: PaymentMethod.mobileMoney,
                    label: Text(l10n.paymentMobileMoney),
                    icon: const Icon(Icons.phone_android),
                  ),
                  if (widget.allowCredit)
                    ButtonSegment(
                      value: PaymentMethod.credit,
                      label: Text(l10n.paymentCredit),
                      icon: const Icon(Icons.book_outlined),
                    ),
                ],
                selected: {_method},
                onSelectionChanged: (selection) {
                  setState(() => _method = selection.first);
                },
              ),
              const SizedBox(height: 16),
              if (isCredit) ...[
                if (widget.hasCustomer && widget.creditLimitCents > 0) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(l10n.outstandingBalance),
                      const Spacer(),
                      Text(
                        formatMoney(widget.outstandingCents, symbol: symbol),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(l10n.creditLimit),
                      const Spacer(),
                      Text(
                        formatMoney(widget.creditLimitCents, symbol: symbol),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      overLimit
                          ? Icons.block
                          : Icons.info_outline,
                      size: 18,
                      color: overLimit
                          ? theme.colorScheme.error
                          : theme.colorScheme.tertiary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        !widget.hasCustomer
                            ? l10n.creditNeedsCustomer
                            : overLimit
                            ? l10n.creditLimitExceeded
                            : l10n.creditChargedToAccount,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: widget.hasCustomer && !overLimit
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (isCash) ...[
                TextField(
                  controller: _receivedController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: l10n.amountReceived,
                    prefixText: '$symbol ',
                    errorText: valid ? null : l10n.insufficientReceived,
                  ),
                ),
                if (valid) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(l10n.changeDue),
                      const Spacer(),
                      Text(
                        formatMoney(change, symbol: symbol),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: change > 0
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton.icon(
          onPressed: valid
              ? () => Navigator.of(context).pop(
                    PaymentInput(
                      method: _method,
                      receivedCents: received,
                    ),
                  )
              : null,
          icon: const Icon(Icons.check),
          label: Text(l10n.confirmPayment),
        ),
      ],
    );
  }
}
