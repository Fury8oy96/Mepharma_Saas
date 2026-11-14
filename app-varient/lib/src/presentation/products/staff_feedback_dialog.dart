import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models/app_product.dart';
import '../../l10n/generated/app_localizations.dart';
import '../session/session_controller.dart';

class StaffFeedbackDialog extends ConsumerStatefulWidget {
  const StaffFeedbackDialog({
    super.key,
    this.product,
  });

  final AppProduct? product;

  static Future<bool?> show(
    BuildContext context, {
    AppProduct? product,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => StaffFeedbackDialog(product: product),
    );
  }

  @override
  ConsumerState<StaffFeedbackDialog> createState() => _StaffFeedbackDialogState();
}

class _StaffFeedbackDialogState extends ConsumerState<StaffFeedbackDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _productNameController;
  late final TextEditingController _qtyController;
  late final TextEditingController _notesController;

  String _urgency = 'normal'; // 'urgent', 'high_demand', 'normal'
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _productNameController =
        TextEditingController(text: widget.product?.name ?? '');

    final initialQty = widget.product != null
        ? (widget.product!.lowStockThreshold > widget.product!.stockQuantity
            ? widget.product!.lowStockThreshold - widget.product!.stockQuantity
            : 10)
        : 10;
    _qtyController = TextEditingController(text: initialQty.toString());
    _notesController = TextEditingController();

    if (widget.product != null && widget.product!.stockQuantity <= 0) {
      _urgency = 'urgent';
    }
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _qtyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final l10n = AppLocalizations.of(context);

    try {
      final user = ref.read(sessionProvider);
      final qty = int.tryParse(_qtyController.text.trim()) ?? 10;
      final notes = _notesController.text.trim();

      await ref.read(staffFeedbackRepositoryProvider).submitFeedback(
            productId: widget.product?.id,
            productName: widget.product?.name ?? _productNameController.text.trim(),
            currentStock: widget.product?.stockQuantity ?? 0,
            staffUserId: user?.id,
            staffUsername: user?.username ?? 'Staff',
            branchId: user?.branchId ?? 1,
            urgency: _urgency,
            suggestedQuantity: qty,
            notes: notes.isEmpty ? null : notes,
          );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.feedbackSubmitted,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit feedback: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final product = widget.product;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      elevation: 16,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.add_shopping_cart_rounded,
                        color: Color(0xFF0EA5E9),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.sendRestockFeedback,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.cashierFeedbackSubtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Drug Card
                if (product != null)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              if (product.barcode != null &&
                                  product.barcode!.isNotEmpty)
                                Text(
                                  'SKU / Barcode: ${product.barcode}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: product.stockQuantity <= 0
                                ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                                : (product.isLowStock
                                    ? const Color(0xFFF59E0B).withValues(alpha: 0.12)
                                    : const Color(0xFF10B981).withValues(alpha: 0.12)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Stock: ${product.stockQuantity}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: product.stockQuantity <= 0
                                  ? const Color(0xFFEF4444)
                                  : (product.isLowStock
                                      ? const Color(0xFFD97706)
                                      : const Color(0xFF10B981)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  TextFormField(
                    controller: _productNameController,
                    decoration: InputDecoration(
                      labelText: l10n.productName,
                      prefixIcon: const Icon(Icons.medication_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Product name is required'
                        : null,
                  ),

                const SizedBox(height: 18),

                // Urgency Selector
                Text(
                  'Reason / Urgency',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildUrgencyChip(
                      value: 'urgent',
                      label: l10n.urgencyLowStock,
                      icon: Icons.error_outline_rounded,
                      color: const Color(0xFFEF4444),
                    ),
                    _buildUrgencyChip(
                      value: 'high_demand',
                      label: l10n.urgencyHighDemand,
                      icon: Icons.trending_up_rounded,
                      color: const Color(0xFF8B5CF6),
                    ),
                    _buildUrgencyChip(
                      value: 'normal',
                      label: l10n.urgencyNormal,
                      icon: Icons.inventory_2_outlined,
                      color: const Color(0xFF0EA5E9),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Suggested Quantity
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _qtyController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: l10n.suggestedQty,
                          prefixIcon: const Icon(Icons.format_list_numbered_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          if (n == null || n <= 0) return 'Enter valid quantity';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      icon: const Icon(Icons.remove_rounded),
                      onPressed: () {
                        final current = int.tryParse(_qtyController.text) ?? 10;
                        if (current > 1) {
                          _qtyController.text = (current - 5).clamp(1, 9999).toString();
                        }
                      },
                    ),
                    IconButton.outlined(
                      icon: const Icon(Icons.add_rounded),
                      onPressed: () {
                        final current = int.tryParse(_qtyController.text) ?? 10;
                        _qtyController.text = (current + 5).toString();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Staff Notes
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: l10n.staffNotes,
                    hintText: 'e.g., 5 patients requested today, fast-selling batch',
                    prefixIcon: const Icon(Icons.chat_bubble_outline_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(l10n.cancel),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(l10n.sendRestockFeedback),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0EA5E9),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUrgencyChip({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _urgency == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ChoiceChip(
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _urgency = value);
      },
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected ? Colors.white : color,
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected
              ? Colors.white
              : (isDark ? Colors.white70 : Colors.black87),
        ),
      ),
      selectedColor: color,
      backgroundColor: color.withValues(alpha: 0.08),
      side: BorderSide(
        color: isSelected ? color : color.withValues(alpha: 0.3),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      showCheckmark: false,
    );
  }
}
