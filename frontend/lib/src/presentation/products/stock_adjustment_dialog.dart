import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models/app_product.dart';
import '../../l10n/generated/app_localizations.dart';
import '../session/session_controller.dart';

/// Records a manual stock adjustment for a product. Returns `true` when saved.
class StockAdjustmentDialog extends ConsumerStatefulWidget {
  const StockAdjustmentDialog({super.key, required this.product});

  final AppProduct product;

  @override
  ConsumerState<StockAdjustmentDialog> createState() => _StockAdjustmentDialogState();
}

class _StockAdjustmentDialogState extends ConsumerState<StockAdjustmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _reasonController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _saving = true);
    final l10n = AppLocalizations.of(context);
    try {
      final quantity = int.parse(_quantityController.text.trim());
      await ref.read(stockAdjustmentRepositoryProvider).adjustStock(
            productId: widget.product.id,
            adjustmentQuantity: quantity,
            reason: _reasonController.text.trim().isEmpty
                ? null
                : _reasonController.text.trim(),
            reference: 'manual',
            userId: ref.read(sessionProvider)?.id,
          );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        final msg = e.toString().contains('message:')
            ? e.toString()
            : l10n.errorOccurred;
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: Colors.red.shade800,
            ),
          );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final product = widget.product;

    return AlertDialog(
      title: Text(l10n.stockAdjustment),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '${l10n.sku}: ${product.sku}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            Text('${l10n.currentStock}: ${product.stockQuantity}'),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _quantityController,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(signed: true),
                    decoration: InputDecoration(
                      labelText: l10n.adjustmentQuantity,
                      helperText: l10n.positiveAddsNegativeRemoves,
                    ),
                    validator: (value) {
                      final parsed = int.tryParse(value?.trim() ?? '');
                      if (parsed == null || parsed == 0) {
                        return l10n.invalidNumber;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _reasonController,
                    decoration: InputDecoration(
                      labelText: l10n.adjustmentReason,
                      hintText: l10n.adjustmentReasonHint,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _submit,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.exposure),
          label: Text(l10n.adjustStock),
        ),
      ],
    );
  }
}
