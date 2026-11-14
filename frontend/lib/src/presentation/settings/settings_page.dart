import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/services/windows_startup_service.dart';
import '../../domain/models/app_user.dart';
import '../../domain/models/store_settings.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/language_switcher.dart';
import '../common/theme_mode_switcher.dart';
import '../session/session_controller.dart';
import 'printer_settings_section.dart';
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

  final _adminUsernameController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  final _adminConfirmPasswordController = TextEditingController();
  bool _obscureAdminPassword = true;
  bool _obscureAdminConfirm = true;
  bool _savingAdminCredentials = false;
  bool _wipingData = false;
  bool _autoStartEnabled = false;
  bool _creatingBackup = false;
  bool _restoringBackup = false;
  String _backupFolderPath = r'D:\MePharma Backups';

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
    _adminUsernameController.dispose();
    _adminPasswordController.dispose();
    _adminConfirmPasswordController.dispose();
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
          : (apiConfig.currencySymbol ?? 'ج.س');
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
      final currentUser = ref.read(sessionProvider);
      _adminUsernameController.text = currentUser?.username ?? 'admin';
      _loading = false;
    });

    WindowsStartupService.isAutoStartEnabled().then((v) {
      if (mounted) setState(() => _autoStartEnabled = v);
    });
    ref.read(backupServiceProvider).getBackupsDirectory().then((dir) {
      if (mounted) setState(() => _backupFolderPath = dir.path);
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
      final oldMargin = double.tryParse(oldSettings.profitMargin) ?? 0.0;

      final newMarginStr = _profitMarginController.text.trim().isEmpty
          ? '0'
          : _profitMarginController.text.trim();
      final newMargin = double.tryParse(newMarginStr) ?? 0.0;

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
                  ? 'ج.س'
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

  Future<void> _saveAdminCredentials() async {
    final l10n = AppLocalizations.of(context);
    final isArabic = l10n.localeName.startsWith('ar');
    final newUsername = _adminUsernameController.text.trim();
    final newPassword = _adminPasswordController.text.trim();
    final confirmPassword = _adminConfirmPasswordController.text.trim();

    if (newUsername.isEmpty) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              isArabic
                  ? 'يرجى إدخال اسم مستخدم صحيح للمدير'
                  : 'Please enter a valid admin username',
            ),
            backgroundColor: Colors.red.shade800,
          ),
        );
      return;
    }

    if (newPassword.isNotEmpty && newPassword.length < 4) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              isArabic
                  ? 'كلمة المرور يجب أن لا تقل عن 4 أحرف أو أرقام'
                  : 'Password must be at least 4 characters',
            ),
            backgroundColor: Colors.red.shade800,
          ),
        );
      return;
    }

    if (newPassword.isNotEmpty && newPassword != confirmPassword) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              isArabic
                  ? 'كلمة المرور وتأكيدها غير متطابقين'
                  : 'Passwords do not match',
            ),
            backgroundColor: Colors.red.shade800,
          ),
        );
      return;
    }

    setState(() => _savingAdminCredentials = true);
    try {
      final userRepo = ref.read(userRepositoryProvider);
      final currentSessionUser = ref.read(sessionProvider);

      AppUser? adminUser = currentSessionUser;
      if (adminUser == null || !adminUser.isAdmin) {
        final allUsers = await userRepo.watchUsers().first;
        adminUser = allUsers.firstWhere(
          (u) => u.isAdmin,
          orElse: () => allUsers.first,
        );
      }

      final updatedUser = await userRepo.updateUser(
        adminUser.id,
        username: newUsername,
        password: newPassword.isNotEmpty ? newPassword : null,
      );

      ref.read(sessionProvider.notifier).updateUser(updatedUser);

      if (mounted) {
        _adminPasswordController.clear();
        _adminConfirmPasswordController.clear();
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(
                isArabic
                    ? 'تم حفظ وتحديث بيانات حساب المدير بنجاح في قاعدة البيانات بشكل دائم. استخدم البيانات الجديدة لتسجيل الدخول.'
                    : 'Admin credentials successfully updated and permanently saved in database.',
              ),
              backgroundColor: const Color(0xFF28C76F),
            ),
          );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(l10n.errorOccurred),
              backgroundColor: Colors.red.shade800,
            ),
          );
      }
    } finally {
      if (mounted) {
        setState(() => _savingAdminCredentials = false);
      }
    }
  }

  Future<void> _toggleAutoStart(bool enabled) async {
    final success = await WindowsStartupService.setAutoStartEnabled(enabled);
    if (!mounted) return;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    if (success) {
      setState(() => _autoStartEnabled = enabled);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              enabled
                  ? (isArabic ? 'تم تفعيل التشغيل التلقائي مع إقلاع ويندوز بنجاح' : 'Windows auto-start enabled')
                  : (isArabic ? 'تم إلغاء التشغيل التلقائي مع إقلاع ويندوز' : 'Windows auto-start disabled'),
            ),
            backgroundColor: const Color(0xFF28C76F),
          ),
        );
    } else {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              isArabic ? 'تعذر تغيير حالة التشغيل التلقائي' : 'Could not change auto-start status',
            ),
            backgroundColor: Colors.red.shade800,
          ),
        );
    }
  }

  Future<void> _createManualBackup() async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    setState(() => _creatingBackup = true);
    try {
      final backupService = ref.read(backupServiceProvider);
      final record = await backupService.createBackup();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              isArabic
                  ? 'تم إنشاء النسخة الاحتياطية بنجاح في: ${record.filePath}'
                  : 'Backup created successfully at: ${record.filePath}',
            ),
            backgroundColor: const Color(0xFF28C76F),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              isArabic ? 'حدث خطأ أثناء إنشاء النسخة الاحتياطية: $e' : 'Backup error: $e',
            ),
            backgroundColor: Colors.red.shade800,
          ),
        );
    } finally {
      if (mounted) setState(() => _creatingBackup = false);
    }
  }

  Future<void> _restoreBackupFromFile() async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final l10n = AppLocalizations.of(context);

    const typeGroup = XTypeGroup(
      label: 'MePharma Database Backup (*.db)',
      extensions: ['db', 'sqlite'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.settings_backup_restore, color: Colors.amber, size: 28),
            const SizedBox(width: 10),
            Text(
              isArabic ? 'تأكيد استعادة النسخة الاحتياطية' : 'Confirm Backup Restoration',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          isArabic
              ? 'هل أنت متأكد من استعادة هذه النسخة الاحتياطية (${file.name})؟\n\nسيتم استبدال البيانات الحالية بالكامل بمحتويات ملف النسخ الاحتياطي.'
              : 'Are you sure you want to restore (${file.name})? All current data will be overwritten by this backup.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(isArabic ? 'استعادة وتحديث البيانات' : 'Restore Now'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _restoringBackup = true);
    try {
      final backupService = ref.read(backupServiceProvider);
      await backupService.restoreFromFile(File(file.path));

      // Refresh all core repositories and providers
      await ref.read(productRepositoryProvider).refresh();
      ref.invalidate(productListProvider);
      ref.invalidate(categoryListProvider);
      ref.invalidate(supplierListProvider);
      ref.invalidate(customerListProvider);
      ref.invalidate(purchaseListProvider);
      ref.invalidate(todaySalesProvider);
      ref.invalidate(stockValuationProvider);
      ref.invalidate(posControllerProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              isArabic
                  ? 'تمت استعادة النسخة الاحتياطية بنجاح وتحديث كافة البيانات في النظام!'
                  : 'Backup restored successfully and all data updated!',
            ),
            backgroundColor: const Color(0xFF28C76F),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              isArabic ? 'تعذر استعادة النسخة الاحتياطية: $e' : 'Restoration failed: $e',
            ),
            backgroundColor: Colors.red.shade800,
          ),
        );
    } finally {
      if (mounted) setState(() => _restoringBackup = false);
    }
  }

  Future<void> _wipeDemoData() async {
    final l10n = AppLocalizations.of(context);
    final isArabic = l10n.localeName.startsWith('ar');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 10),
            Text(
              isArabic ? 'تأكيد تنظيف ومسح البيانات' : 'Confirm Data Wipe',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          isArabic
              ? 'هل أنت متأكد من مسح جميع المنتجات والأدوية والمبيعات والمشتريات والعملاء والموردين نهائياً، والإبقاء فقط على حساب المدير الرئيسي؟\n\nهذا الإجراء دائم ولا يمكن التراجع عنه.'
              : 'Are you sure you want to permanently wipe all products, medicines, sales, purchases, customers, and suppliers, retaining ONLY the Admin account?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              isArabic ? 'نعم، مسح وتنظيف الداتا الآن' : 'Yes, Wipe Data Now',
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _wipingData = true);
    try {
      final db = ref.read(databaseProvider);
      final userRepo = ref.read(userRepositoryProvider);
      final allUsers = await userRepo.watchUsers().first;
      final adminUser = allUsers.firstWhere(
        (u) => u.isAdmin,
        orElse: () => allUsers.first,
      );

      await db.transaction(() async {
        await db.delete(db.saleItems).go();
        await db.delete(db.sales).go();
        await db.delete(db.salesHolds).go();
        await db.delete(db.purchaseItems).go();
        await db.delete(db.purchases).go();
        await db.delete(db.stockAdjustments).go();
        await db.delete(db.returnItems).go();
        await db.delete(db.returns).go();
        await db.delete(db.staffProductFeedbacks).go();
        await db.delete(db.customerPayments).go();
        await db.delete(db.customers).go();
        await db.delete(db.products).go();
        await db.delete(db.categories).go();
        await db.delete(db.suppliers).go();
        await db.delete(db.syncQueueEntries).go();
        await (db.delete(db.users)..where((u) => u.id.isNotIn([adminUser.id]))).go();
      });

      await ref.read(productRepositoryProvider).refresh();
      ref.invalidate(productListProvider);
      ref.invalidate(categoryListProvider);
      ref.invalidate(supplierListProvider);
      ref.invalidate(customerListProvider);
      ref.invalidate(purchaseListProvider);
      ref.invalidate(todaySalesProvider);
      ref.invalidate(stockValuationProvider);
      ref.invalidate(posControllerProvider);

      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(
                isArabic
                    ? 'تم مسح وتنظيف جميع البيانات والأدوية بنجاح والإبقاء على حساب المدير فقط!'
                    : 'All dummy data and medicines wiped successfully. Only Admin retained!',
              ),
              backgroundColor: const Color(0xFF28C76F),
            ),
          );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(l10n.errorOccurred),
              backgroundColor: Colors.red.shade800,
            ),
          );
      }
    } finally {
      if (mounted) {
        setState(() => _wipingData = false);
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
                  const PrinterSettingsSection(),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 24),
                  const ServerSettingsSection(),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 24),

                  // Admin Credentials Management Section
                  Row(
                    children: [
                      Icon(
                        Icons.admin_panel_settings_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        Localizations.localeOf(context).languageCode == 'ar'
                            ? 'إعدادات وتخصيص حساب المدير'
                            : 'Admin Account & Security Settings',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            Localizations.localeOf(context).languageCode == 'ar'
                                ? 'تعديل اسم المستخدم وكلمة المرور لحساب المدير الرئيسي بشكل دائم'
                                : 'Update primary administrator username and password permanently',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _adminUsernameController,
                            decoration: InputDecoration(
                              labelText: Localizations.localeOf(context).languageCode == 'ar'
                                  ? 'اسم مستخدم المدير'
                                  : 'Admin Username',
                              prefixIcon: const Icon(Icons.person_outline),
                              helperText: Localizations.localeOf(context).languageCode == 'ar'
                                  ? 'يُستخدم لتسجيل الدخول للنظام وإدارة الصيدلية'
                                  : 'Used to log in to the pharmacy administration system',
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _adminPasswordController,
                                  obscureText: _obscureAdminPassword,
                                  decoration: InputDecoration(
                                    labelText: Localizations.localeOf(context).languageCode == 'ar'
                                        ? 'كلمة المرور الجديدة'
                                        : 'New Password',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    helperText: Localizations.localeOf(context).languageCode == 'ar'
                                        ? 'اتركها فارغة إذا كنت لا ترغب بتغيير كلمة المرور'
                                        : 'Leave blank to keep existing password',
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureAdminPassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscureAdminPassword = !_obscureAdminPassword;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _adminConfirmPasswordController,
                                  obscureText: _obscureAdminConfirm,
                                  decoration: InputDecoration(
                                    labelText: Localizations.localeOf(context).languageCode == 'ar'
                                        ? 'تأكيد كلمة المرور'
                                        : 'Confirm Password',
                                    prefixIcon: const Icon(Icons.lock_reset_outlined),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureAdminConfirm
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscureAdminConfirm = !_obscureAdminConfirm;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: FilledButton.icon(
                              onPressed: _savingAdminCredentials ? null : _saveAdminCredentials,
                              icon: _savingAdminCredentials
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.verified_user_outlined),
                              label: Text(
                                Localizations.localeOf(context).languageCode == 'ar'
                                    ? 'حفظ وتحديث بيانات المدير'
                                    : 'Save Admin Credentials',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 24),

                  // Windows Startup Configuration Section
                  Row(
                    children: [
                      Icon(
                        Icons.power_settings_new_rounded,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        Localizations.localeOf(context).languageCode == 'ar'
                            ? 'إعدادات بدء تشغيل ويندوز (Windows Startup)'
                            : 'Windows Startup Configuration',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: SwitchListTile(
                      value: _autoStartEnabled,
                      onChanged: _toggleAutoStart,
                      secondary: Icon(
                        Icons.desktop_windows_outlined,
                        color: _autoStartEnabled ? theme.colorScheme.primary : null,
                      ),
                      title: Text(
                        Localizations.localeOf(context).languageCode == 'ar'
                            ? 'تشغيل التطبيق تلقائياً عند أول إقلاع ويندوز'
                            : 'Launch MePharma automatically on Windows startup',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        Localizations.localeOf(context).languageCode == 'ar'
                            ? 'عند التفعيل، يبدأ البرنامج بالعمل تلقائياً في الخلفية مع إقلاع النظام ويقوم بإجراء النسخ الاحتياطي اليومي.'
                            : 'When enabled, the app automatically starts on system boot and performs daily backup routine.',
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 24),

                  // Database Backup & Restore Section
                  Row(
                    children: [
                      Icon(
                        Icons.backup_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        Localizations.localeOf(context).languageCode == 'ar'
                            ? 'النسخ الاحتياطي واستعادة البيانات (Backup & Restore)'
                            : 'Database Backup & Restore',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.folder_special_outlined, color: theme.colorScheme.primary, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      Localizations.localeOf(context).languageCode == 'ar'
                                          ? 'مسار حفظ النسخ الاحتياطية المحلية:'
                                          : 'Local Backup Directory Path:',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    SelectableText(
                                      _backupFolderPath,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'monospace',
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, size: 18, color: theme.colorScheme.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    Localizations.localeOf(context).languageCode == 'ar'
                                        ? 'يتم إنشاء نسخة احتياطية محلية تلقائية يومياً في تاريخ اليوم عند بدء تشغيل البرنامج باسم backupYYYYMMDD.db ولا تتكرر في نفس اليوم.'
                                        : 'A local backup is automatically created once a day on launch as backupYYYYMMDD.db in the directory above.',
                                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              FilledButton.icon(
                                onPressed: _creatingBackup ? null : _createManualBackup,
                                icon: _creatingBackup
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.save_outlined),
                                label: Text(
                                  Localizations.localeOf(context).languageCode == 'ar'
                                      ? 'إنشاء نسخة احتياطية الآن (Backup Now)'
                                      : 'Create Backup Now',
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: _restoringBackup ? null : _restoreBackupFromFile,
                                icon: _restoringBackup
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.settings_backup_restore),
                                label: Text(
                                  Localizations.localeOf(context).languageCode == 'ar'
                                      ? 'استعادة نسخة احتياطية من ملف (Restore Backup)'
                                      : 'Restore Backup from File',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 24),

                  // Data Wipe & Cleanup Section
                  Row(
                    children: [
                      const Icon(
                        Icons.cleaning_services_outlined,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        Localizations.localeOf(context).languageCode == 'ar'
                            ? 'إدارة وتنظيف بيانات الصيدلية'
                            : 'Database Cleanup & Maintenance',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Card(
                    color: Colors.red.withValues(alpha: 0.04),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: Colors.red.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  Localizations.localeOf(context).languageCode == 'ar'
                                      ? 'مسح وتنظيف جميع البيانات وقوائم الأدوية (الإبقاء على حساب المدير فقط)'
                                      : 'Wipe all dummy products, sales & data (Retain Admin account only)',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            Localizations.localeOf(context).languageCode == 'ar'
                                ? 'يقوم هذا الخيار بحذف جميع أصناف الأدوية، فواتير المبيعات، أوامر الشراء، العملاء، والموردين نهائياً، مع الاحتفاظ بحساب المدير وإعدادات الصيدلية.'
                                : 'Permanently clears all medicines, sales, purchases, customers, and suppliers while preserving the Admin account and store configuration.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.red.shade700,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _wipingData ? null : _wipeDemoData,
                            icon: _wipingData
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.delete_forever_outlined),
                            label: Text(
                              Localizations.localeOf(context).languageCode == 'ar'
                                  ? 'مسح وتنظيف جميع البيانات والأدوية الآن'
                                  : 'Wipe All Data & Medicines Now',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
