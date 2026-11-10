import '../models/printer_config.dart';
import '../models/store_settings.dart';

abstract interface class SettingsRepository {
  Future<String?> getValue(String key);

  Future<void> setValue(String key, String? value);

  Future<StoreSettings> getStoreSettings();

  Future<void> saveStoreSettings(StoreSettings settings);

  Future<String> getCurrencySymbol();

  Future<PrinterConfig> getPrinterConfig();

  Future<void> savePrinterConfig(PrinterConfig config);

  /// Default low-stock threshold for new products.
  Future<int> getDefaultLowStockThreshold();
}
