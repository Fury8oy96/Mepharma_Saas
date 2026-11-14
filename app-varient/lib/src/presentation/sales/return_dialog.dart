import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/utils/money.dart';
import '../../domain/models/app_sale.dart';
import '../../domain/repositories/return_repository.dart';
import '../../l10n/generated/app_localizations.dart';

/// Lets the user choose how much of each sold line to return and the reason,
/// then records the return (restocking handled by the repository).
class ReturnDialog extends ConsumerStatefulWidget {
  const ReturnDialog({
    super.key,
    required this.detail,
    required this.currentUserId,
  });

  final SaleDetail detail;
  final int currentUserId;

  @override
  ConsumerState<ReturnDialog> createState() => _ReturnDialogState();
}

class _ReturnDialogState extends ConsumerState<ReturnDialog> {
  final _reasonController = TextEditingController();
  final Map<int, int> _maxQty = {};
  final Map<int, int> _qty = {};
  bool _loaded = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReturned();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadReturned() async {
    final returnedItems = await ref
        .read(returnRepositoryProvider)
        .getReturnItemsForSale(widget.detail.sale.id);
    final returnedByItem = <int, int>{};
    for (final item in returnedItems) {
      final saleItemId = item.saleItemId;
      if (saleItemId != null) {
        returnedByItem[saleItemId] =
            (returnedByItem[saleItemId] ?? 0) + item.quantity;
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      for (final line in widget.detail.items) {
        final max = line.quantity - (returnedByItem[line.id] ?? 0);
        _maxQty[line.id] = max < 0 ? 0 : max;
        _qty[line.id] = 0;
      }
      _loaded = true;
    });
  }

  int get _refundTotal {
    var total = 0;
    for (final line in widget.detail.items) {
      total += (_qty[line.id] ?? 0) * line.unitPrice;
    }
    return total;
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final inputs = [
      for (final line in widget.detail.items)
        if ((_qty[line.id] ?? 0) > 0)
          ReturnLineInput(
            saleItemId: line.id,
            productId: line.productId,
            productName: line.productName,
            unitPrice: line.unitPrice,
            quantity: _qty[line.id]!,
          ),
    ];
    if (inputs.isEmpty) {
      setState(() => _error = l10n.nothingToReturn);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(returnRepositoryProvider).createReturn(
            saleId: widget.detail.sale.id,
            userId: widget.currentUserId,
            reason: _reasonController.text.trim().isEmpty
                ? null
                : _reasonController.text.trim(),
            items: inputs,
          );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on StateError catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = e.message;
      });
    } on Exception {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = l10n.errorOccurred;
      });
    }
  }

  void _bump(int saleItemId, int delta) {
    final max = _maxQty[saleItemId] ?? 0;
    final current = _qty[saleItemId] ?? 0;
    final next = (current + delta).clamp(0, max);
    setState(() => _qty[saleItemId] = next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final symbol = ref.watch(currencySymbolProvider).valueOrNull ?? r'$';

    return AlertDialog(
      title: Text(l10n.returnItems),
      content: SizedBox(
        width: 520,
        child: _loaded
            ? SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.detail.sale.invoiceNumber,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (final line in widget.detail.items) ...[
                      _returnLine(theme, l10n, line, symbol),
                      const SizedBox(height: 8),
                    ],
                    const Divider(height: 24),
                    TextField(
                      controller: _reasonController,
                      decoration: InputDecoration(
                        labelText: l10n.returnReason,
                        hintText: l10n.returnReasonHint,
                        prefixIcon: const Icon(Icons.notes),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                  ],
                ),
              )
            : const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton.icon(
          onPressed: _loaded && !_saving ? _submit : null,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: Text(
            '${l10n.processReturn} (${formatMoney(_refundTotal, symbol: symbol)})',
          ),
        ),
      ],
    );
  }

  Widget _returnLine(
    ThemeData theme,
    AppLocalizations l10n,
    AppSaleItem line,
    String symbol,
  ) {
    final max = _maxQty[line.id] ?? 0;
    final qty = _qty[line.id] ?? 0;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line.productName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '${l10n.sold}: ${line.quantity} · ${formatCents(line.unitPrice)}'
                '${max < line.quantity ? ' · ${l10n.alreadyReturned}: ${line.quantity - max}' : ''}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: '-',
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: qty > 0 ? () => _bump(line.id, -1) : null,
        ),
        SizedBox(
          width: 32,
          child: Text(
            '$qty',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        IconButton(
          tooltip: '+',
          icon: const Icon(Icons.add_circle_outline),
          onPressed: qty < max ? () => _bump(line.id, 1) : null,
        ),
        SizedBox(
          width: 90,
          child: Text(
            formatMoney(qty * line.unitPrice, symbol: symbol),
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
