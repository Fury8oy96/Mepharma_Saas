/// Store information used on receipts, invoices and reports.
///
/// All fields are stored as raw strings in the settings table; numeric
/// fields are parsed when consumed (e.g. tax rate during POS).
class StoreSettings {
  const StoreSettings({
    this.storeName = '',
    this.storeAddress = '',
    this.storePhone = '',
    this.storeTaxId = '',
    this.taxRate = '0',
    this.currencySymbol = r'$',
    this.receiptFooter = '',
    this.defaultLowStockThreshold = '10',
    this.profitMargin = '0.3',
    this.branchNumber = 1,
    this.seatNumber = 1,
    this.receiptStyle = 'modern',
    this.receiptFormat = '80mm',
    this.receiptFont = 'Tajawal',
  });

  final String storeName;
  final String storeAddress;
  final String storePhone;
  final String storeTaxId;

  /// Percentage, e.g. '5' means 5%.
  final String taxRate;
  final String currencySymbol;

  /// Extra text printed at the bottom of receipts (thanks note, returns policy).
  final String receiptFooter;

  /// Default low-stock threshold applied when adding new products.
  final String defaultLowStockThreshold;

  /// Default profit margin factor (e.g. '0.3' for 30% markup).
  final String profitMargin;

  /// Counter and branch seat index automatically allocated from tenant license
  final int branchNumber;
  final int seatNumber;

  /// Receipt styling configuration
  final String receiptStyle;
  final String receiptFormat;
  final String receiptFont;
}
