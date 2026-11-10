import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../core/utils/barcode_symbologies.dart';
import '../../core/utils/money.dart';
import '../../core/utils/sku_generator.dart';
import '../../domain/models/app_category.dart';
import '../../domain/models/app_product.dart';
import '../../domain/models/app_supplier.dart';
import '../../l10n/generated/app_localizations.dart';

/// Add or edit a product. Returns `true` when the product was saved.
class ProductFormDialog extends ConsumerStatefulWidget {
  const ProductFormDialog({
    super.key,
    required this.categories,
    required this.suppliers,
    this.product,
  });

  final List<AppCategory> categories;
  final List<AppSupplier> suppliers;

  /// When null, a new product is created; otherwise the product is updated.
  final AppProduct? product;

  @override
  ConsumerState<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends ConsumerState<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _skuController;
  late final TextEditingController _brandNameController;
  late final TextEditingController _doseController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _costController;
  late final TextEditingController _priceController;
  late final TextEditingController _thresholdController;
  late final TextEditingController _expiryController;
  late final TextEditingController _descriptionController;

  int? _categoryId;
  int? _supplierId;
  DateTime? _expiryDate;
  BarcodeSymbologyType _selectedSymbology = BarcodeSymbologyType.ean13;
  bool _saving = false;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    final defaultThreshold =
        ref.read(defaultLowStockThresholdProvider).valueOrNull ?? 10;

    String brandName = '';
    String dose = '';
    if (p != null) {
      final name = p.name;
      final lastSpaceIndex = name.lastIndexOf(' ');
      if (lastSpaceIndex != -1) {
        final lastPart = name.substring(lastSpaceIndex + 1);
        if (RegExp(r'^\d+').hasMatch(lastPart)) {
          brandName = name.substring(0, lastSpaceIndex);
          dose = lastPart;
        } else {
          brandName = name;
        }
      } else {
        brandName = name;
      }
    }

    _skuController = TextEditingController(text: p?.sku ?? '');
    _brandNameController = TextEditingController(text: brandName);
    _doseController = TextEditingController(text: dose);
    _barcodeController = TextEditingController(text: p?.barcode ?? '');
    _costController = TextEditingController(
      text: formatCents(p?.costPrice ?? 0),
    );
    _priceController = TextEditingController(
      text: formatCents(p?.sellingPrice ?? 0),
    );
    _thresholdController = TextEditingController(
      text: (p?.lowStockThreshold ?? defaultThreshold).toString(),
    );
    _descriptionController = TextEditingController(text: p?.description ?? '');
    _categoryId = p?.categoryId;
    _supplierId = p?.supplierId;
    _expiryDate = p?.expiryDate;
    _expiryController = TextEditingController();
    _selectedSymbology = BarcodeSymbologyType.detect(p?.barcode ?? p?.sku);

    // Auto SKU generation listeners
    _brandNameController.addListener(_updateSku);
    _doseController.addListener(_updateSku);
    _descriptionController.addListener(_updateSku);

    // Auto margin calculation listener
    _costController.addListener(_updateSellingPrice);
  }

  void _updateSku() {
    if (_isEditing) return;
    final brandText = _brandNameController.text.trim();
    final genericText = _descriptionController.text.trim();
    final doseText = _doseController.text.trim();

    if (brandText.isEmpty) {
      _skuController.text = '';
      return;
    }

    _skuController.text = SkuGenerator.generate(
      brandName: brandText,
      genericName: genericText,
      dosage: doseText,
    );
  }

  void _updateSellingPrice() {
    final costText = _costController.text;
    final cost = parseCents(costText);
    if (cost > 0) {
      final marginStr = ref.read(storeSettingsProvider).valueOrNull?.profitMargin ?? '0.3';
      final margin = double.tryParse(marginStr) ?? 0.3;
      final sellingPrice = (cost * (1 + margin)).round();
      _priceController.text = formatCents(sellingPrice);
    }
  }

  void _generateSystemBarcode() {
    final barcode = _selectedSymbology.generateInternalCode();
    setState(() {
      _barcodeController.text = barcode;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _expiryController.text = _expiryDateText();
  }

  @override
  void dispose() {
    _skuController.dispose();
    _brandNameController.dispose();
    _doseController.dispose();
    _barcodeController.dispose();
    _costController.dispose();
    _priceController.dispose();
    _thresholdController.dispose();
    _expiryController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? now.add(const Duration(days: 365)),
      firstDate: now.subtract(const Duration(days: 3650)),
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() {
        _expiryDate = picked;
        _expiryController.text = _expiryDateText();
      });
    }
  }

  String _expiryDateText() {
    final date = _expiryDate;
    if (date == null) {
      return '';
    }
    return DateFormat.yMd(AppLocalizations.of(context).localeName).format(date);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _saving = true);

    final l10n = AppLocalizations.of(context);
    final repo = ref.read(productRepositoryProvider);
    final barcode = _barcodeController.text.trim();
    final sku = _skuController.text.trim();
    final fullName = '${_brandNameController.text.trim()} ${_doseController.text.trim()}'.trim();

    try {
      if (!_isEditing && await repo.isSkuTaken(sku)) {
        _showError(l10n.alreadyInUse(l10n.sku));
        return;
      }
      if (barcode.isNotEmpty &&
          await repo.isBarcodeTaken(barcode, excludeId: widget.product?.id)) {
        _showError(l10n.alreadyInUse(l10n.barcode));
        return;
      }

      final cost = parseCents(_costController.text);
      final price = parseCents(_priceController.text);
      final threshold = int.tryParse(_thresholdController.text.trim()) ?? 10;

      if (_isEditing) {
        await repo.update(
          widget.product!.id,
          name: fullName,
          barcode: barcode.isEmpty ? null : barcode,
          categoryId: _categoryId,
          supplierId: _supplierId,
          costPrice: cost,
          sellingPrice: price,
          lowStockThreshold: threshold,
          expiryDate: _expiryDate,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
        );
      } else {
        await repo.create(
          sku: sku,
          name: fullName,
          barcode: barcode.isEmpty ? null : barcode,
          categoryId: _categoryId,
          supplierId: _supplierId,
          costPrice: cost,
          sellingPrice: price,
          lowStockThreshold: threshold,
          expiryDate: _expiryDate,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on Exception {
      if (mounted) {
        _showError(l10n.errorOccurred);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currency = ref.watch(currencySymbolProvider).valueOrNull ?? r'$';

    return AlertDialog(
      title: Text(_isEditing ? l10n.editProduct : l10n.addProduct),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _brandNameController,
                        decoration: InputDecoration(labelText: l10n.brandName),
                        validator: (value) => (value == null || value.trim().isEmpty)
                            ? l10n.fieldRequired
                            : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _doseController,
                        decoration: InputDecoration(labelText: l10n.dose),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(labelText: l10n.genericName),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _skuController,
                        enabled: !_isEditing,
                        decoration: InputDecoration(
                          labelText: '${l10n.sku} (Brand-Generic-Dose)',
                          suffixIcon: !_isEditing
                              ? IconButton(
                                  icon: const Icon(Icons.sync, size: 20),
                                  tooltip: 'Regenerate SKU Formula',
                                  onPressed: _updateSku,
                                )
                              : null,
                        ),
                        validator: (value) => (value == null || value.trim().isEmpty)
                            ? l10n.fieldRequired
                            : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<BarcodeSymbologyType>(
                        initialValue: _selectedSymbology,
                        decoration: const InputDecoration(labelText: '1D Symbology'),
                        items: [
                          for (final s in BarcodeSymbologyType.values)
                            DropdownMenuItem<BarcodeSymbologyType>(
                              value: s,
                              child: Text(s.name, overflow: TextOverflow.ellipsis),
                            ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() {
                              _selectedSymbology = v;
                              if (_barcodeController.text.isEmpty) {
                                _generateSystemBarcode();
                              }
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _barcodeController,
                        decoration: InputDecoration(
                          labelText: l10n.barcode,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.auto_awesome, size: 20),
                            tooltip: 'Generate Barcode',
                            onPressed: _generateSystemBarcode,
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                if (_barcodeController.text.trim().isNotEmpty || _skuController.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '1D Barcode Preview (${_selectedSymbology.name})',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Builder(
                            builder: (context) {
                              final codeData = _barcodeController.text.trim().isNotEmpty
                                  ? _barcodeController.text.trim()
                                  : _skuController.text.trim();
                              return BarcodeWidget(
                                barcode: _selectedSymbology.toSafeBarcode(codeData),
                                data: codeData,
                                width: 240,
                                height: 48,
                                style: const TextStyle(fontSize: 10, color: Colors.black),
                                errorBuilder: (context, error) => Text(
                                  'Invalid format for ${_selectedSymbology.name}',
                                  style: const TextStyle(color: Colors.red, fontSize: 11),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        initialValue: _categoryId,
                        decoration: InputDecoration(labelText: l10n.category),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('-'),
                          ),
                          for (final c in widget.categories)
                            DropdownMenuItem<int?>(
                              value: c.id,
                              child: Text(c.name),
                            ),
                        ],
                        onChanged: (v) => setState(() => _categoryId = v),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        initialValue: _supplierId,
                        decoration: InputDecoration(labelText: l10n.supplier),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('-'),
                          ),
                          for (final s in widget.suppliers)
                            DropdownMenuItem<int?>(
                              value: s.id,
                              child: Text(s.name),
                            ),
                        ],
                        onChanged: (v) => setState(() => _supplierId = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _costController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: l10n.costPrice,
                          prefixText: currency,
                        ),
                        validator: (value) => _validateMoney(value, l10n),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: l10n.sellingPrice,
                          prefixText: currency,
                        ),
                        validator: (value) => _validateMoney(value, l10n),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _thresholdController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: l10n.lowStockThreshold,
                        ),
                        validator: (value) =>
                            _validateNonNegativeInt(value, l10n),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _expiryController,
                        readOnly: true,
                        onTap: _pickExpiryDate,
                        decoration: InputDecoration(
                          labelText: l10n.expiryDate,
                          suffixIcon: const Icon(Icons.calendar_today_outlined),
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
              : const Icon(Icons.save_outlined),
          label: Text(l10n.save),
        ),
      ],
    );
  }

  String? _validateMoney(String? value, AppLocalizations l10n) {
    if (value == null || value.trim().isEmpty) {
      return l10n.fieldRequired;
    }
    if (parseCents(value) < 0) {
      return l10n.invalidNumber;
    }
    return null;
  }

  String? _validateNonNegativeInt(String? value, AppLocalizations l10n) {
    if (value == null || value.trim().isEmpty) {
      return l10n.fieldRequired;
    }
    final parsed = int.tryParse(value.trim());
    if (parsed == null || parsed < 0) {
      return l10n.invalidNumber;
    }
    return null;
  }
}
