import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/utils/money.dart';
import '../../domain/models/app_product.dart';
import '../../domain/repositories/purchase_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../session/session_controller.dart';

class PurchaseFormDialog extends ConsumerStatefulWidget {
  const PurchaseFormDialog({
    super.key,
    this.initialProducts,
    this.initialSupplierId,
  });

  final List<AppProduct>? initialProducts;
  final int? initialSupplierId;

  @override
  ConsumerState<PurchaseFormDialog> createState() => _PurchaseFormDialogState();
}

class _PurchaseFormDialogState extends ConsumerState<PurchaseFormDialog> {
  int? _supplierId;
  DateTime? _purchaseDate;
  final _lines = <_PurchaseLine>[];
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _supplierId = widget.initialSupplierId;
    if (widget.initialProducts != null && widget.initialProducts!.isNotEmpty) {
      for (final p in widget.initialProducts!) {
        final restockQty = (p.lowStockThreshold * 2 > p.stockQuantity)
            ? (p.lowStockThreshold * 2 - p.stockQuantity)
            : (p.lowStockThreshold > 0 ? p.lowStockThreshold : 10);
        _lines.add(_PurchaseLine(
          productId: p.id,
          productName: p.name,
          quantity: restockQty > 0 ? restockQty : 10,
          costPrice: p.costPrice,
        ));
      }
      if (_supplierId == null && widget.initialProducts!.first.supplierId != null) {
        _supplierId = widget.initialProducts!.first.supplierId;
      }
    }
  }

  int get _total => _lines.fold<int>(0, (sum, line) => sum + line.totalCost);

  Future<void> _pickProduct() async {
    final products = ref.read(productListProvider).valueOrNull ?? const [];
    final l10n = AppLocalizations.of(context);
    if (products.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(l10n.noProducts)));
      return;
    }
    final selected = await showDialog<AppProduct>(
      context: context,
      builder: (context) => _ProductPicker(products: products),
    );
    if (selected == null || !mounted) {
      return;
    }
    final line = await showDialog<_PurchaseLine>(
      context: context,
      builder: (context) => _LineEditor(product: selected),
    );
    if (line != null && mounted) {
      setState(() {
        _error = null;
        final existingIndex = _lines.indexWhere(
          (l) => l.productId != 0 && l.productId == line.productId,
        );
        if (existingIndex >= 0) {
          final existing = _lines[existingIndex];
          _lines[existingIndex] = _PurchaseLine(
            productId: existing.productId,
            productName: existing.productName,
            quantity: existing.quantity + line.quantity,
            costPrice: line.costPrice,
          );
          return;
        }
        _lines.add(line);
      });
    }
  }

  Future<void> _addUnlistedDrug() async {
    final l10n = AppLocalizations.of(context);
    final nameController = TextEditingController();
    final qtyController = TextEditingController(text: '1');
    final costController = TextEditingController(text: '0');

    final res = await showDialog<_PurchaseLine>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.requestUnlistedDrug),
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: '${l10n.customDrugName} *',
                  hintText: 'e.g. Amoxicillin 500mg',
                  prefixIcon: const Icon(Icons.medication_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '${l10n.quantity} *',
                  prefixIcon: const Icon(Icons.numbers),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: costController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '${l10n.costPrice} (${l10n.leaveEmptyToKeep})',
                  prefixIcon: const Icon(Icons.payments_outlined),
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
            onPressed: () {
              final name = nameController.text.trim();
              final qty = int.tryParse(qtyController.text.trim()) ?? 1;
              final cost = parseCents(costController.text);
              if (name.isEmpty) return;
              Navigator.of(context).pop(
                _PurchaseLine(
                  productId: 0,
                  productName: name,
                  quantity: qty > 0 ? qty : 1,
                  costPrice: cost,
                ),
              );
            },
            child: Text(l10n.add),
          ),
        ],
      ),
    );

    if (res != null && mounted) {
      setState(() {
        _error = null;
        _lines.add(res);
      });
    }
  }

  Future<void> _pickSupplier() async {
    final suppliers = ref.read(supplierListProvider).valueOrNull ?? const [];
    final l10n = AppLocalizations.of(context);
    if (suppliers.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(l10n.noSuppliers)));
      return;
    }
    final selected = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.selectSupplier),
        children: [
          for (final s in suppliers)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(s.id),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(s.name),
                subtitle: s.phone == null ? null : Text(s.phone!),
              ),
            ),
        ],
      ),
    );
    if (selected != null && mounted) {
      setState(() => _supplierId = selected);
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (_lines.isEmpty) {
      setState(() => _error = l10n.noPurchaseLines);
      return;
    }
    final supplierId = _supplierId;
    final userId = ref.read(sessionProvider)?.id;
    if (userId == null) {
      setState(() => _error = l10n.errorOccurred);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(purchaseRepositoryProvider)
          .createPurchase(
            userId: userId,
            supplierId: supplierId,
            purchaseDate: _purchaseDate ?? DateTime.now(),
            items: [
              for (final line in _lines)
                PurchaseLineInput(
                  productId: line.productId == 0 ? null : line.productId,
                  productName: line.productName,
                  quantity: line.quantity,
                  costPrice: line.costPrice,
                ),
            ],
          );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _error = '${l10n.errorOccurred}: $e';
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final suppliers = ref.watch(supplierListProvider).valueOrNull ?? const [];
    final symbol = ref.watch(currencySymbolProvider).valueOrNull ?? r'$';
    final supplier = _supplierId == null
        ? null
        : suppliers.where((s) => s.id == _supplierId).firstOrNull;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.inventory_2_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(l10n.newPurchase),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickSupplier,
                      icon: const Icon(Icons.local_shipping_outlined),
                      label: Text(
                        supplier == null
                            ? l10n.selectSupplier
                            : '${l10n.supplier}: ${supplier.name}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (_supplierId != null) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: l10n.cancel,
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _supplierId = null),
                    ),
                  ],
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _purchaseDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null && mounted) {
                        setState(() => _purchaseDate = date);
                      }
                    },
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(
                      _purchaseDate == null
                          ? l10n.purchaseDate
                          : '${_purchaseDate!.year}-${_purchaseDate!.month.toString().padLeft(2, '0')}-${_purchaseDate!.day.toString().padLeft(2, '0')}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _pickProduct,
                    icon: const Icon(Icons.search),
                    label: Text(l10n.products),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: _addUnlistedDrug,
                    icon: const Icon(Icons.medication_outlined),
                    label: Text(l10n.requestUnlistedDrug),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_lines.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    l10n.noPurchaseLines,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                for (final (index, line) in _lines.indexed) ...[
                  _lineTile(theme, l10n, symbol, line, index),
                  const SizedBox(height: 4),
                ],
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
                    formatMoney(_total, symbol: symbol),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.save),
        ),
      ],
    );
  }

  Widget _lineTile(
    ThemeData theme,
    AppLocalizations l10n,
    String symbol,
    _PurchaseLine line,
    int index,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        line.productName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (line.productId == 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Request',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${l10n.quantity}: ${line.quantity} × ${formatMoney(line.costPrice, symbol: symbol)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Text(
              formatMoney(line.totalCost, symbol: symbol),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: l10n.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                setState(() => _lines.removeAt(index));
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseLine {
  const _PurchaseLine({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.costPrice,
  });

  final int productId;
  final String productName;
  final int quantity;
  final int costPrice;

  int get totalCost => quantity * costPrice;
}

class _ProductPicker extends StatefulWidget {
  const _ProductPicker({required this.products});

  final List<AppProduct> products;

  @override
  State<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends State<_ProductPicker> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final filtered = widget.products.where((p) {
      if (_filter.isEmpty) {
        return true;
      }
      final query = _filter.toLowerCase();
      return p.name.toLowerCase().contains(query) ||
          p.sku.toLowerCase().contains(query) ||
          (p.barcode?.toLowerCase().contains(query) ?? false);
    }).toList();

    return AlertDialog(
      title: Text(l10n.selectProduct),
      content: SizedBox(
        width: 480,
        height: 380,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              onChanged: (value) => setState(() => _filter = value.trim()),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.searchProduct,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? Center(child: Text(l10n.noProducts))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final product = filtered[index];
                        return ListTile(
                          title: Text(product.name),
                          subtitle: Text(product.sku),
                          onTap: () => Navigator.of(context).pop(product),
                        );
                      },
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
      ],
    );
  }
}

class _LineEditor extends ConsumerStatefulWidget {
  const _LineEditor({required this.product});

  final AppProduct product;

  @override
  ConsumerState<_LineEditor> createState() => _LineEditorState();
}

class _LineEditorState extends ConsumerState<_LineEditor> {
  late final TextEditingController _quantityController;
  late final TextEditingController _costController;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(text: '1');
    _costController = TextEditingController(
      text: formatCents(widget.product.costPrice),
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _costController.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final quantity = int.tryParse(_quantityController.text.trim());
    final cost = parseCents(_costController.text);
    if (quantity == null || quantity <= 0 || cost < 0) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(l10n.invalidLineValues)));
      return;
    }
    final product = widget.product;
    Navigator.of(context).pop(
      _PurchaseLine(
        productId: product.id,
        productName: product.name,
        quantity: quantity,
        costPrice: cost,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final symbol = ref.watch(currencySymbolProvider).valueOrNull ?? r'$';
    final title = widget.product.name;

    return AlertDialog(
      title: Text(title, overflow: TextOverflow.ellipsis, maxLines: 1),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.quantity,
                prefixIcon: const Icon(Icons.numbers),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _costController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '${l10n.unitCost} ($symbol)',
                prefixIcon: const Icon(Icons.payments_outlined),
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
        FilledButton(onPressed: _submit, child: Text(l10n.add)),
      ],
    );
  }
}
