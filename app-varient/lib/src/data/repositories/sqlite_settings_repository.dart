import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/models/printer_config.dart';
import '../../domain/models/store_settings.dart';
import '../../domain/repositories/settings_repository.dart';
import '../db/app_database.dart';

class SqliteSettingsRepository implements SettingsRepository {
  SqliteSettingsRepository(this._db);

  final AppDatabase _db;

  @override
  Future<String?> getValue(String key) async {
    final row = await (_db.select(
      _db.settings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  @override
  Future<void> setValue(String key, String? value) async {
    await _db
        .into(_db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion.insert(key: key, value: Value(value)),
        );
  }

  @override
  Future<StoreSettings> getStoreSettings() async {
    final branchStr = await _string(AppConstants.settingBranchNumber, '1');
    final seatStr = await _string(AppConstants.settingSeatNumber, '1');
    return StoreSettings(
      storeName: await _string(AppConstants.settingStoreName, ''),
      storeAddress: await _string(AppConstants.settingStoreAddress, ''),
      storePhone: await _string(AppConstants.settingStorePhone, ''),
      storeTaxId: await _string(AppConstants.settingStoreTaxId, ''),
      taxRate: await _string(AppConstants.settingTaxRate, '0'),
      currencySymbol: await getCurrencySymbol(),
      receiptFooter: await _string(AppConstants.settingReceiptFooter, ''),
      defaultLowStockThreshold: await _string(
        AppConstants.settingLowStockThreshold,
        '10',
      ),
      profitMargin: await _string(AppConstants.settingProfitMargin, '0.3'),
      branchNumber: int.tryParse(branchStr) ?? 1,
      seatNumber: int.tryParse(seatStr) ?? 1,
      receiptStyle: await _string(AppConstants.settingReceiptStyle, 'modern'),
      receiptFormat: await _string(AppConstants.settingReceiptFormat, '80mm'),
      receiptFont: await _string(AppConstants.settingReceiptFont, 'Tajawal'),
    );
  }

  @override
  Future<void> saveStoreSettings(StoreSettings settings) async {
    await _db.transaction(() async {
      await setValue(AppConstants.settingStoreName, settings.storeName);
      await setValue(AppConstants.settingStoreAddress, settings.storeAddress);
      await setValue(AppConstants.settingStorePhone, settings.storePhone);
      await setValue(AppConstants.settingStoreTaxId, settings.storeTaxId);
      await setValue(AppConstants.settingTaxRate, settings.taxRate);
      await setValue(
        AppConstants.settingCurrencySymbol,
        settings.currencySymbol,
      );
      await setValue(AppConstants.settingReceiptFooter, settings.receiptFooter);
      await setValue(
        AppConstants.settingLowStockThreshold,
        settings.defaultLowStockThreshold,
      );
      await setValue(AppConstants.settingProfitMargin, settings.profitMargin);
      await setValue(AppConstants.settingBranchNumber, settings.branchNumber.toString());
      await setValue(AppConstants.settingSeatNumber, settings.seatNumber.toString());
      await setValue(AppConstants.settingReceiptStyle, settings.receiptStyle);
      await setValue(AppConstants.settingReceiptFormat, settings.receiptFormat);
      await setValue(AppConstants.settingReceiptFont, settings.receiptFont);
    });
  }

  @override
  Future<int> getDefaultLowStockThreshold() async {
    final value = await _string(AppConstants.settingLowStockThreshold, '10');
    return int.tryParse(value) ?? 10;
  }

  @override
  Future<String> getCurrencySymbol() async {
    final value = await getValue(AppConstants.settingCurrencySymbol);
    return (value == null || value.isEmpty) ? r'$' : value;
  }

  @override
  Future<PrinterConfig> getPrinterConfig() async {
    final raw = await getValue(AppConstants.settingPrinter);
    if (raw == null || raw.isEmpty) {
      return const PrinterConfig();
    }
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) {
        return const PrinterConfig();
      }
      return PrinterConfig.fromJson(json);
    } on FormatException {
      return const PrinterConfig();
    } on TypeError {
      // Malformed values (e.g. wrong JSON types) must never crash the app.
      return const PrinterConfig();
    }
  }

  @override
  Future<void> savePrinterConfig(PrinterConfig config) async {
    await setValue(AppConstants.settingPrinter, jsonEncode(config.toJson()));
  }

  Future<String> _string(String key, String fallback) async {
    return (await getValue(key)) ?? fallback;
  }
}
