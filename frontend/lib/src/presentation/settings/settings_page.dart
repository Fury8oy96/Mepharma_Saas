import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models/store_settings.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/language_switcher.dart';
import '../common/theme_mode_switcher.dart';
import 'hardware_devices_section.dart';
import 'server_settings_section.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _formKey = GlobalKey<FormState>();

  final _storeNameController = TextEditingController();
  final _storeAddressController = TextEditingController();
  final _storePhoneController = TextEditingController();
  final _taxIdController = TextEditingController();
  final _taxRateController = TextEditingController();
  final _currencyController = TextEditingController();
  final _receiptFooterController = TextEditingController();
  final _lowStockThresholdController = TextEditingController();
  final _profitMarginController = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  int _branchNumber = 1;
  int _seatNumber = 1;
  String _receiptStyle = 'modern';
  String _receiptFormat = '80mm';
  String _receiptFont = 'Tajawal';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _storeAddressController.dispose();
    _storePhoneController.dispose();
    _taxIdController.dispose();
    _taxRateController.dispose();
    _currencyController.dispose();
    _receiptFooterController.dispose();
    _lowStockThresholdController.dispose();
    _profitMarginController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    StoreSettings settings;
    try {
      settings = await ref.read(settingsRepositoryProvider).getStoreSettings();
    } catch (_) {
      settings = const StoreSettings();
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(l10n.errorOccurred)));
      }
    }
    if (!mounted) {
      return;
    }
    final apiConfig = ref.read(apiConfigProvider);
    setState(() {
      _storeNameController.text = settings.storeName.isNotEmpty
          ? settings.storeName
          : (apiConfig.pharmacyName ?? '');
      _storeAddressController.text = settings.storeAddress.isNotEmpty
          ? settings.storeAddress
          : (apiConfig.pharmacyAddress ?? '');
      _storePhoneController.text = settings.storePhone.isNotEmpty
          ? settings.storePhone
          : (apiConfig.pharmacyPhone ?? '');
      _storeTaxIdControllerText(settings.storeTaxId);
      _taxRateController.text = settings.taxRate != '0'
          ? settings.taxRate
          : (apiConfig.taxRate?.toString() ?? '0');
      _currencyController.text = settings.currencySymbol.isNotEmpty
          ? settings.currencySymbol
          : (apiConfig.currencySymbol ?? r'$');
      _receiptFooterController.text = settings.receiptFooter.isNotEmpty
          ? settings.receiptFooter
          : (apiConfig.receiptFooter ?? '');
      _lowStockThresholdController.text = settings.defaultLowStockThreshold;
      _profitMarginController.text = settings.profitMargin;

      _branchNumber = settings.branchNumber > 0
          ? settings.branchNumber
          : (apiConfig.seatNumber ?? 1);
      _seatNumber = settings.seatNumber > 0
          ? settings.seatNumber
          : (apiConfig.seatNumber ?? 1);
      _receiptStyle = settings.receiptStyle;
      _receiptFormat = settings.receiptFormat;
      _receiptFont = settings.receiptFont;
      _loading = false;
    });
  }

  void _storeTaxIdControllerText(String val) {
    _taxIdController.text = val;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      final oldSettings = await ref.read(settingsRepositoryProvider).getStoreSettings();
      final oldMargin = double.tryParse(oldSettings.profitMargin) ?? 0.3;

      final newMarginStr = _profitMarginController.text.trim().isEmpty
          ? '0.3'
          : _profitMarginController.text.trim();
      final newMargin = double.tryParse(newMarginStr) ?? 0.3;

      await ref
          .read(settingsRepositoryProvider)
          .saveStoreSettings(
            StoreSettings(
              storeName: _storeNameController.text.trim(),
              storeAddress: _storeAddressController.text.trim(),
              storePhone: _storePhoneController.text.trim(),
              storeTaxId: _taxIdController.text.trim(),
              taxRate: _taxRateController.text.trim().isEmpty
                  ? '0'
                  : _taxRateController.text.trim(),
              currencySymbol: _currencyController.text.trim().isEmpty
                  ? r'$'
                  : _currencyController.text.trim(),
              receiptFooter: _receiptFooterController.text.trim(),
              defaultLowStockThreshold:
                  _lowStockThresholdController.text.trim().isEmpty
                  ? '10'
                  : _lowStockThresholdController.text.trim(),
              profitMargin: newMarginStr,
              branchNumber: _branchNumber,
              seatNumber: _seatNumber,
              receiptStyle: _receiptStyle,
              receiptFormat: _receiptFormat,
              receiptFont: _receiptFont,
            ),
          );

      if (newMargin != oldMargin) {
        final productRepo = ref.read(productRepositoryProvider);
        final products = await productRepo.getAll();
        for (final product in products) {
          if (product.costPrice > 0) {
            final newSellingPrice = (product.costPrice * (1 + newMargin)).round();
            await productRepo.update(
              product.id,
              name: product.name,
              barcode: product.barcode,
              categoryId: product.categoryId,
              supplierId: product.supplierId,
              costPrice: product.costPrice,
              sellingPrice: newSellingPrice,
              lowStockThreshold: product.lowStockThreshold,
              expiryDate: product.expiryDate,
              description: product.description,
            );
          }
        }
      }

      ref.invalidate(currencySymbolProvider);
      ref.invalidate(defaultLowStockThresholdProvider);
      ref.invalidate(storeSettingsProvider);
      ref.invalidate(productListProvider);

      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(l10n.saved)));
      }
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(l10n.errorOccurred)));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.storefront_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.storeSettings,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _loading ? null : _load,
                        icon: const Icon(Icons.sync, size: 16),
                        label: Text(
                          Localizations.localeOf(context).languageCode == 'ar'
                              ? 'تحديث من السحابة'
                              : 'Sync from Cloud',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Branch & Terminal Seat Allocation Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.point_of_sale, color: theme.colorScheme.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    Localizations.localeOf(context).languageCode == 'ar'
                                        ? 'رقم الفرع / نقطة البيع: مقعد #$_branchNumber'
                                        : 'Branch & Counter: Seat #$_branchNumber',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.cloud_done, size: 13, color: Colors.green),
                                        const SizedBox(width: 4),
                                        Text(
                                          Localizations.localeOf(context).languageCode == 'ar'
                                              ? 'متزامن مع سحابة الصيدلية'
                                              : 'Tenant Cloud Synced',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                Localizations.localeOf(context).languageCode == 'ar'
                                    ? 'تم جلب البيانات تلقائياً، ورقم الفرع محسوب حسب ترتيب تثبيت المقاعد (المقعد $_seatNumber)'
                                    : 'Data auto-grabbed from tenant settings; seat order calculated by install sequence (Seat #$_seatNumber)',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Receipt style & format preview indicator
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: Localizations.localeOf(context).languageCode == 'ar'
                              ? 'الفرع #$_branchNumber (المقعد $_seatNumber)'
                              : 'Branch #$_branchNumber (Seat $_seatNumber)',
                          key: ValueKey('branch_$_branchNumber'),
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: Localizations.localeOf(context).languageCode == 'ar'
                                ? 'رقم الفرع / الكاونتر'
                                : 'Branch / Counter',
                            prefixIcon: const Icon(Icons.pin_outlined),
                            helperText: Localizations.localeOf(context).languageCode == 'ar'
                                ? 'محسوب حسب ترتيب تثبيت الجهاز'
                                : 'Calculated by seat install order',
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          initialValue: '$_receiptFormat / $_receiptStyle ($_receiptFont)',
                          key: ValueKey('rcpt_$_receiptFormat$_receiptStyle'),
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: Localizations.localeOf(context).languageCode == 'ar'
                                ? 'تنسيق الإيصال المعتمد'
                                : 'Thermal Receipt Format',
                            prefixIcon: const Icon(Icons.receipt_outlined),
                            helperText: Localizations.localeOf(context).languageCode == 'ar'
                                ? 'مُعد في لوحة الإدارة السحابية'
                                : 'Configured via Admin Dashboard',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _storeNameController,
                    decoration: InputDecoration(
                      labelText: l10n.storeName,
                      prefixIcon: const Icon(Icons.storefront_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _storeAddressController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: l10n.storeAddress,
                      prefixIcon: const Icon(Icons.place_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _storePhoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: l10n.storePhone,
                            prefixIcon: const Icon(Icons.phone_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _taxIdController,
                          decoration: InputDecoration(
                            labelText: l10n.storeTaxId,
                            prefixIcon: const Icon(Icons.badge_outlined),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _taxRateController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: l10n.taxRate,
                            suffixText: '%',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return null;
                            }
                            final parsed = double.tryParse(value.trim());
                            if (parsed == null || parsed < 0) {
                              return l10n.invalidNumber;
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _currencyController,
                          decoration: InputDecoration(
                            labelText: l10n.currencySymbol,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _lowStockThresholdController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: l10n.defaultLowStockThreshold,
                            helperText: l10n.defaultLowStockHint,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return null;
                            }
                            final parsed = int.tryParse(value.trim());
                            if (parsed == null || parsed < 0) {
                              return l10n.invalidNumber;
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _profitMarginController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: l10n.profitMargin,
                            prefixIcon: const Icon(Icons.trending_up_outlined),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return null;
                            }
                            final parsed = double.tryParse(value.trim());
                            if (parsed == null || parsed < 0) {
                              return l10n.invalidNumber;
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _receiptFooterController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: l10n.receiptFooter,
                      helperText: l10n.receiptFooterHint,
                      prefixIcon: const Icon(Icons.receipt_long_outlined),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(l10n.save),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Icon(
                        Icons.palette_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        Localizations.localeOf(context).languageCode == 'ar' ? 'العرض والمظهر' : 'Display & Appearance',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    Localizations.localeOf(context).languageCode == 'ar' ? 'نمط المظهر' : 'Theme Mode',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    Localizations.localeOf(context).languageCode == 'ar' ? 'اختر المظهر الفاتح أو الداكن أو المتوافق مع النظام' : 'Choose light, dark, or system synchronized theme',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              const ThemeModeSwitcher(showLabels: true),
                            ],
                          ),
                          const Divider(height: 32),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.language,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    Localizations.localeOf(context).languageCode == 'ar' ? 'التبديل بين اللغتين العربية والإنجليزية' : 'Choose between English and Arabic (RTL)',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              const LanguageSwitcher(),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 24),
                  const HardwareDevicesSection(),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 24),
                  const ServerSettingsSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
