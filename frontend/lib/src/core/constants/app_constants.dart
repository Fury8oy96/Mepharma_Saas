/// Application-wide constants.
abstract final class AppConstants {
  static const String appName = 'MePharma';
  static const String appVersion = '2.0.4';
  static const int buildNumber = 6;
  static const String updateCheckUrl = 'https://raw.githubusercontent.com/Fury8oy96/Mepharma_Saas/main/version.json';

  static const String databaseName = 'mepharma';

  static const int bcryptCost = 12;

  /// Seeded on first run when no users exist.
  static const String defaultAdminUsername = 'admin';

  static const String defaultAdminPassword = 'admin123';

  /// Settings keys.
  static const String settingStoreName = 'store.name';

  static const String settingStoreAddress = 'store.address';

  static const String settingStorePhone = 'store.phone';

  static const String settingStoreTaxId = 'store.tax_id';

  static const String settingTaxRate = 'store.tax_rate';

  static const String settingCurrency = 'store.currency';

  static const String settingCurrencySymbol = 'store.currency_symbol';

  static const String settingLocale = 'app.locale';

  static const String settingThemeMode = 'app.theme_mode';

  static const String settingPrinter = 'printer.config';

  /// Default low-stock threshold used when creating new products.
  static const String settingLowStockThreshold = 'store.low_stock_threshold';

  /// Extra text printed at the bottom of receipts.
  static const String settingReceiptFooter = 'store.receipt_footer';

  /// Default profit margin used to calculate selling price.
  static const String settingProfitMargin = 'store.profit_margin';

  /// Branch and counter seat identification.
  static const String settingBranchNumber = 'store.branch_number';
  static const String settingSeatNumber = 'store.seat_number';

  /// Receipt styling configuration.
  static const String settingReceiptStyle = 'store.receipt_style';
  static const String settingReceiptFormat = 'store.receipt_format';
  static const String settingReceiptFont = 'store.receipt_font';
}
