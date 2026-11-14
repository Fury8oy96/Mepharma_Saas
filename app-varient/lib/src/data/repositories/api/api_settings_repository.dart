import 'dart:convert';

import '../../../domain/models/printer_config.dart';
import '../../../domain/models/store_settings.dart';
import '../../../domain/repositories/settings_repository.dart';
import '../../../core/services/api_client.dart';

class ApiSettingsRepository implements SettingsRepository {
  ApiSettingsRepository(this._client, this._localSettings);

  final ApiClient _client;
  final SettingsRepository _localSettings;

  @override
  Future<String?> getValue(String key) async {
    // Local-only settings remain local
    if (key == 'printer.config' || key == 'app.locale') {
      return _localSettings.getValue(key);
    }
    try {
      final response = await _client.get('/settings/$key');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['value'] as String?;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> setValue(String key, String? value) async {
    if (key == 'printer.config' || key == 'app.locale') {
      await _localSettings.setValue(key, value);
      return;
    }
    await _client.post('/settings', body: {
      'key': key,
      'value': value,
    });
  }

  @override
  Future<StoreSettings> getStoreSettings() async {
    try {
      final response = await _client.get('/settings/store');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      
      final settings = StoreSettings(
        storeName: (data['name'] ?? data['store_name'] ?? data['store.name'] ?? '') as String,
        storeAddress: (data['address'] ?? data['store_address'] ?? data['store.address'] ?? '') as String,
        storePhone: (data['phone'] ?? data['store_phone'] ?? data['store.phone'] ?? '') as String,
        storeTaxId: (data['taxNumber'] ?? data['tax_number'] ?? data['store_tax_id'] ?? data['store.tax_id'] ?? '') as String,
        taxRate: (data['taxRate'] ?? data['tax_rate'] ?? data['store.tax_rate'] ?? '0').toString(),
        currencySymbol: (data['currency'] ?? data['currencySymbol'] ?? data['currency_symbol'] ?? data['store.currency_symbol'] ?? r'$') as String,
        receiptFooter: (data['receiptFooter'] ?? data['receipt_footer'] ?? data['store.receipt_footer'] ?? '') as String,
        defaultLowStockThreshold: (data['lowStockThreshold'] ?? data['low_stock_threshold'] ?? data['store.low_stock_threshold'] ?? '10').toString(),
        profitMargin: (data['profitMargin'] ?? data['profit_margin'] ?? data['store.profit_margin'] ?? '0.3').toString(),
        branchNumber: int.tryParse((data['branchNumber'] ?? data['branch_number'] ?? data['store.branch_number'] ?? data['seatNumber'] ?? 1).toString()) ?? 1,
        seatNumber: int.tryParse((data['seatNumber'] ?? data['seat_number'] ?? data['store.seat_number'] ?? data['branchNumber'] ?? 1).toString()) ?? 1,
        receiptStyle: (data['receiptStyle'] ?? data['receipt_style'] ?? data['store.receipt_style'] ?? 'modern') as String,
        receiptFormat: (data['receiptFormat'] ?? data['receipt_format'] ?? data['store.receipt_format'] ?? '80mm') as String,
        receiptFont: (data['receiptFont'] ?? data['receipt_font'] ?? data['store.receipt_font'] ?? 'Tajawal') as String,
      );

      // Save locally to SQLite so offline-first works seamlessly
      await _localSettings.saveStoreSettings(settings);

      return settings;
    } catch (_) {
      // Offline fallback: return existing local SQLite settings
      return _localSettings.getStoreSettings();
    }
  }

  @override
  Future<void> saveStoreSettings(StoreSettings settings) async {
    try {
      await _client.post('/settings/store', body: {
        'store.name': settings.storeName,
        'name': settings.storeName,
        'store_name': settings.storeName,
        'store.address': settings.storeAddress,
        'address': settings.storeAddress,
        'store_address': settings.storeAddress,
        'store.phone': settings.storePhone,
        'phone': settings.storePhone,
        'store_phone': settings.storePhone,
        'store.tax_id': settings.storeTaxId,
        'taxNumber': settings.storeTaxId,
        'store_tax_id': settings.storeTaxId,
        'store.tax_rate': settings.taxRate,
        'taxRate': settings.taxRate,
        'tax_rate': settings.taxRate,
        'store.currency_symbol': settings.currencySymbol,
        'currency': settings.currencySymbol,
        'currency_symbol': settings.currencySymbol,
        'store.receipt_footer': settings.receiptFooter,
        'receiptFooter': settings.receiptFooter,
        'receipt_footer': settings.receiptFooter,
        'store.low_stock_threshold': settings.defaultLowStockThreshold,
        'lowStockThreshold': settings.defaultLowStockThreshold,
        'store.profit_margin': settings.profitMargin,
        'profitMargin': settings.profitMargin,
        'profit_margin': settings.profitMargin,
        'store.branch_number': settings.branchNumber.toString(),
        'store.seat_number': settings.seatNumber.toString(),
        'receiptStyle': settings.receiptStyle,
        'receiptFormat': settings.receiptFormat,
        'receiptFont': settings.receiptFont,
      });
    } finally {
      await _localSettings.saveStoreSettings(settings);
    }
  }

  @override
  Future<String> getCurrencySymbol() async {
    final value = await getValue('store.currency_symbol');
    return (value == null || value.isEmpty) ? r'$' : value;
  }

  @override
  Future<PrinterConfig> getPrinterConfig() {
    return _localSettings.getPrinterConfig();
  }

  @override
  Future<void> savePrinterConfig(PrinterConfig config) {
    return _localSettings.savePrinterConfig(config);
  }

  @override
  Future<int> getDefaultLowStockThreshold() async {
    final value = await getValue('store.low_stock_threshold');
    return int.tryParse(value ?? '10') ?? 10;
  }
}
