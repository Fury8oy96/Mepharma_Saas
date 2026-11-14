// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Pharmacy Management System';

  @override
  String get signIn => 'Sign in';

  @override
  String get signingIn => 'Signing in...';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get invalidCredentials => 'Invalid username or password';

  @override
  String get errorLogin => 'Something went wrong. Please try again.';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get arabic => 'Arabic';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get pos => 'Point of Sale';

  @override
  String get salesHistory => 'Sales History';

  @override
  String get products => 'Products';

  @override
  String get categories => 'Categories';

  @override
  String get suppliers => 'Suppliers';

  @override
  String get purchases => 'Purchases';

  @override
  String get users => 'Users';

  @override
  String get reports => 'Reports';

  @override
  String get settings => 'Settings';

  @override
  String get backup => 'Backup';

  @override
  String get logout => 'Log out';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String welcomeBack(String name) {
    return 'Welcome back, $name';
  }

  @override
  String welcomeBackMessage(String role) {
    return 'You are signed in as $role';
  }

  @override
  String get roleAdmin => 'Administrator';

  @override
  String get roleStaff => 'Staff';

  @override
  String get quickSale => 'New sale';

  @override
  String get todaySales => 'Today\'s sales';

  @override
  String get lowStockItems => 'Low stock items';

  @override
  String get actions => 'Actions';

  @override
  String get save => 'Save';

  @override
  String get saving => 'Saving...';

  @override
  String get saved => 'Saved';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get searchProducts => 'Search by name, SKU, or barcode';

  @override
  String get fieldRequired => 'This field is required';

  @override
  String get invalidNumber => 'Invalid number';

  @override
  String alreadyInUse(String field) {
    return '$field is already in use';
  }

  @override
  String get errorOccurred => 'Something went wrong. Please try again.';

  @override
  String get sku => 'SKU';

  @override
  String get barcode => 'Barcode';

  @override
  String get productName => 'Product name';

  @override
  String get category => 'Category';

  @override
  String get supplier => 'Supplier';

  @override
  String get costPrice => 'Cost price';

  @override
  String get sellingPrice => 'Selling price';

  @override
  String get stock => 'Stock';

  @override
  String get lowStockThreshold => 'Low stock alert at';

  @override
  String get expiryDate => 'Expiry date';

  @override
  String get description => 'Description';

  @override
  String get noCategory => 'No category';

  @override
  String get noSupplier => 'No supplier';

  @override
  String get noProducts => 'No products found';

  @override
  String get addProduct => 'Add product';

  @override
  String get editProduct => 'Edit product';

  @override
  String get deleteProduct => 'Delete product';

  @override
  String get productAdded => 'Product added';

  @override
  String get productSaved => 'Product saved';

  @override
  String get productDeleted => 'Product deleted';

  @override
  String confirmDeleteProduct(String name) {
    return 'Delete $name?';
  }

  @override
  String get confirmDeleteProductMessage =>
      'This will remove the product from inventory. This action cannot be undone.';

  @override
  String get adjustStock => 'Adjust Stock';

  @override
  String get stockAdjustment => 'Stock Adjustment';

  @override
  String get adjustmentQuantity => 'Adjustment Quantity (+/-)';

  @override
  String get adjustmentReason => 'Reason (Optional)';

  @override
  String get adjustmentReasonHint =>
      'e.g. Inventory audit, damaged items, return to supplier';

  @override
  String get positiveAddsNegativeRemoves =>
      'Positive number adds stock, negative removes stock.';

  @override
  String get currentStock => 'Current stock';

  @override
  String get addCategory => 'Add category';

  @override
  String get editCategory => 'Edit category';

  @override
  String get categoryName => 'Category name';

  @override
  String get deleteCategory => 'Delete category';

  @override
  String get categoryAdded => 'Category added';

  @override
  String get categorySaved => 'Category saved';

  @override
  String confirmDeleteCategory(String name) {
    return 'Delete category $name?';
  }

  @override
  String get noCategories => 'No categories yet';

  @override
  String get addSupplier => 'Add supplier';

  @override
  String get editSupplier => 'Edit supplier';

  @override
  String get supplierName => 'Supplier name';

  @override
  String get contactPerson => 'Contact person';

  @override
  String get phone => 'Phone';

  @override
  String get email => 'Email';

  @override
  String get address => 'Address';

  @override
  String get deleteSupplier => 'Delete supplier';

  @override
  String get supplierAdded => 'Supplier added';

  @override
  String get supplierSaved => 'Supplier saved';

  @override
  String confirmDeleteSupplier(String name) {
    return 'Delete supplier $name?';
  }

  @override
  String get noSuppliers => 'No suppliers yet';

  @override
  String get storeSettings => 'Store settings';

  @override
  String get storeName => 'Store name';

  @override
  String get storeAddress => 'Store address';

  @override
  String get storePhone => 'Store phone';

  @override
  String get storeTaxId => 'Tax ID';

  @override
  String get taxRate => 'Tax rate (%)';

  @override
  String get currencySymbol => 'Currency symbol';

  @override
  String get scanBarcode => 'Scan barcode, SKU, name, or generic name...';

  @override
  String get productNotFound => 'Product not found';

  @override
  String outOfStock(String name) {
    return 'Out of stock: $name';
  }

  @override
  String get emptyCart => 'The cart is empty';

  @override
  String get insufficientStock => 'Insufficient stock';

  @override
  String get insufficientReceived => 'Amount received is less than the total';

  @override
  String get cart => 'Cart';

  @override
  String get clearCart => 'Clear cart';

  @override
  String get confirmClearCartMessage =>
      'All items will be removed from the cart.';

  @override
  String get newSale => 'New sale';

  @override
  String get holdSale => 'Hold sale';

  @override
  String get resumeHold => 'Resume hold';

  @override
  String get saleHeld => 'Sale held';

  @override
  String saleCompleted(String invoice) {
    return 'Sale completed: $invoice';
  }

  @override
  String get noHolds => 'No held sales';

  @override
  String get deleteHold => 'Delete hold';

  @override
  String confirmDeleteHold(String number) {
    return 'Delete hold $number?';
  }

  @override
  String holdPartiallyRestored(String missing) {
    return 'Some products are no longer available and were skipped: $missing';
  }

  @override
  String get subtotal => 'Subtotal';

  @override
  String get discount => 'Discount';

  @override
  String get discountNone => 'No discount';

  @override
  String get discountPercentage => 'Percentage';

  @override
  String get discountFixed => 'Fixed amount';

  @override
  String get tax => 'Tax';

  @override
  String get total => 'Total';

  @override
  String get pay => 'Pay';

  @override
  String get payment => 'Payment';

  @override
  String get paymentCash => 'Cash';

  @override
  String get paymentCard => 'Card';

  @override
  String get paymentMobileMoney => 'Mobile money';

  @override
  String get amountReceived => 'Amount received';

  @override
  String get changeDue => 'Change';

  @override
  String get confirmPayment => 'Confirm payment';

  @override
  String get receiptInvoice => 'Invoice:';

  @override
  String get receiptCashier => 'Cashier:';

  @override
  String get receiptCustomer => 'Customer:';

  @override
  String get receiptOnAccount => 'On account';

  @override
  String get receiptThanks => 'Thank you for your purchase!';

  @override
  String get printFailed => 'Print failed';

  @override
  String get printFailedMessage =>
      'The receipt could not be printed. Check the printer settings and try again, or print it later from Sales History.';

  @override
  String get retry => 'Retry';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get hintScan => 'F1 Scan';

  @override
  String get hintPay => 'F2 Pay';

  @override
  String get hintHold => 'F4 Hold';

  @override
  String get hintClear => 'Esc Clear';

  @override
  String get printerSettings => 'Printer settings';

  @override
  String get printerType => 'Printer type';

  @override
  String get printerNone => 'None';

  @override
  String get printerWindows => 'Windows printer (USB / driver)';

  @override
  String get printerNetwork => 'Network printer (TCP / 9100)';

  @override
  String get printerAddress => 'Printer name or address';

  @override
  String get printerAddressHintWindows => 'Name of the installed printer';

  @override
  String get printerAddressHintNetwork => 'e.g. 192.168.1.50';

  @override
  String get printerPort => 'Port';

  @override
  String get paperSize => 'Paper size';

  @override
  String get testPrint => 'Test print';

  @override
  String get testReceiptSent => 'Test receipt sent to printer';

  @override
  String get from => 'From';

  @override
  String get to => 'To';

  @override
  String get searchInvoice => 'Search by invoice number or customer';

  @override
  String get dateRange => 'Date range';

  @override
  String get paymentAll => 'All payments';

  @override
  String get status => 'Status';

  @override
  String get statusAll => 'All statuses';

  @override
  String get resetFilters => 'Reset filters';

  @override
  String get noSales => 'No sales match the current filters';

  @override
  String get saleStatusCompleted => 'Completed';

  @override
  String get saleStatusReturned => 'Returned';

  @override
  String get saleStatusVoided => 'Voided';

  @override
  String get saleDetail => 'Sale detail';

  @override
  String get printReceipt => 'Print receipt';

  @override
  String get returnItems => 'Return items';

  @override
  String get close => 'Close';

  @override
  String get cashier => 'Cashier';

  @override
  String get customer => 'Customer';

  @override
  String get date => 'Date';

  @override
  String get returns => 'Returns';

  @override
  String get returnProcessed => 'Return processed';

  @override
  String get nothingToReturn => 'Select at least one item to return';

  @override
  String get processReturn => 'Process return';

  @override
  String get returnReason => 'Return Reason';

  @override
  String get returnReasonHint => 'e.g. wrong item, damaged';

  @override
  String get sold => 'Sold';

  @override
  String get alreadyReturned => 'Already returned';

  @override
  String get newPurchase => 'New purchase';

  @override
  String get purchaseSaved => 'Purchase saved';

  @override
  String get noPurchases => 'No purchases yet';

  @override
  String get purchaseDetail => 'Purchase detail';

  @override
  String get selectSupplier => 'Select Supplier';

  @override
  String get noPurchaseLines => 'No purchase lines yet';

  @override
  String get purchaseDate => 'Purchase date';

  @override
  String get purchaseTotal => 'Purchase total';

  @override
  String get addLine => 'Add line';

  @override
  String get decrease => 'Decrease';

  @override
  String get increase => 'Increase';

  @override
  String get remove => 'Remove';

  @override
  String get selectProduct => 'Select product';

  @override
  String get searchProduct => 'Search products';

  @override
  String get noResults => 'No results';

  @override
  String get quantity => 'Quantity';

  @override
  String get unitCost => 'Unit cost';

  @override
  String get add => 'Add';

  @override
  String get invalidLineValues => 'Enter a valid quantity and unit cost';

  @override
  String get productAlreadyAdded => 'Product is already in the purchase lines';

  @override
  String get addUser => 'Add user';

  @override
  String get editUser => 'Edit user';

  @override
  String get userAdded => 'User added';

  @override
  String get userSaved => 'User saved';

  @override
  String get role => 'Role';

  @override
  String get active => 'Active';

  @override
  String get inactive => 'Inactive';

  @override
  String get cannotDeactivateSelf => 'You cannot deactivate your own account';

  @override
  String get needOneActiveAdmin =>
      'At least one active administrator is required';

  @override
  String get newPassword => 'New password';

  @override
  String get leaveEmptyToKeep => 'Leave empty to keep the current password';

  @override
  String get salesCount => 'Sales';

  @override
  String get revenue => 'Revenue';

  @override
  String get netRevenue => 'Net revenue';

  @override
  String get refunds => 'Refunds';

  @override
  String get purchasesCost => 'Purchases cost';

  @override
  String get estimatedProfit => 'Estimated profit';

  @override
  String get totalSales => 'Total sales';

  @override
  String get salesByPayment => 'Sales by payment method';

  @override
  String get topProducts => 'Top products';

  @override
  String get exportCsv => 'Export CSV';

  @override
  String exportedTo(String path) {
    return 'Report exported to $path';
  }

  @override
  String get noData => 'No data for this period';

  @override
  String get createBackup => 'Create backup';

  @override
  String backupCreated(String path) {
    return 'Backup created: $path';
  }

  @override
  String get backupFailed => 'Backup failed';

  @override
  String get restoreBackup => 'Restore';

  @override
  String confirmRestore(String name) {
    return 'Restore backup $name? This will replace all current data with the backup.';
  }

  @override
  String get restoreComplete => 'Backup restored. Please sign in again.';

  @override
  String get restoreFailed => 'Restore failed';

  @override
  String get backupsLocation =>
      'Backups are stored in your Documents folder (MePharmaBackups).';

  @override
  String get noBackups => 'No backups yet';

  @override
  String confirmDeleteBackup(String fileName) {
    return 'Delete backup $fileName? This cannot be undone.';
  }

  @override
  String get backupDeleted => 'Backup deleted';

  @override
  String get customers => 'Customers';

  @override
  String get expiry => 'Expiry';

  @override
  String get paymentCredit => 'On account';

  @override
  String get creditChargedToAccount =>
      'This amount will be added to the customer\'s account balance.';

  @override
  String get creditNeedsCustomer =>
      'Select a customer to charge this sale to their account.';

  @override
  String get creditLimitExceeded =>
      'This sale exceeds the customer\'s credit limit.';

  @override
  String get outstandingBalance => 'Outstanding balance';

  @override
  String get walkInCustomer => 'Walk-in customer';

  @override
  String get productExpired => 'This product has expired and cannot be sold.';

  @override
  String get addCustomer => 'Add customer';

  @override
  String get editCustomer => 'Edit customer';

  @override
  String get customerName => 'Customer name';

  @override
  String get creditLimit => 'Credit limit';

  @override
  String get notes => 'Notes';

  @override
  String get customerAdded => 'Customer added';

  @override
  String get customerSaved => 'Customer saved';

  @override
  String get recordPayment => 'Record payment';

  @override
  String recordPaymentFor(String name) {
    return 'Record payment for $name';
  }

  @override
  String get amount => 'Amount';

  @override
  String get note => 'Note';

  @override
  String get paymentRecorded => 'Payment recorded';

  @override
  String get balance => 'Balance';

  @override
  String get paymentHistory => 'Payment history';

  @override
  String get noPayments => 'No payments recorded yet';

  @override
  String confirmDeleteCustomer(String name) {
    return 'Delete customer $name?';
  }

  @override
  String get deleteCustomerHint =>
      'The customer\'s payment history will be deleted and their sales will remain without a customer. This action cannot be undone.';

  @override
  String customerHasOutstandingBalance(String amount) {
    return 'This customer has an outstanding balance of $amount.';
  }

  @override
  String get customerNameTaken => 'A customer with this name already exists';

  @override
  String get creditLimitNegative => 'Credit limit cannot be negative';

  @override
  String get overLimit => 'Over limit';

  @override
  String get searchCustomers => 'Search customers';

  @override
  String get noCustomers => 'No customers yet';

  @override
  String get payments => 'Payments';

  @override
  String get todayLabel => 'Today';

  @override
  String get yesterdayLabel => 'Yesterday';

  @override
  String nextDays(int days) {
    return 'Next $days days';
  }

  @override
  String get expiryHint =>
      'Products are flagged as expired on their expiry date.';

  @override
  String get noExpiringProducts =>
      'No products expire within the selected period';

  @override
  String get expiredProducts => 'Expired';

  @override
  String get expiringSoon => 'Expiring soon';

  @override
  String expiredOn(String date) {
    return 'Expired on $date';
  }

  @override
  String daysUntilExpiry(int days) {
    return 'in $days days';
  }

  @override
  String get expiredLabel => 'Expired';

  @override
  String get defaultLowStockThreshold => 'Default low-stock alert';

  @override
  String get defaultLowStockHint => 'Used when adding new products';

  @override
  String get receiptFooter => 'Receipt footer';

  @override
  String get receiptFooterHint =>
      'Shown at the bottom of printed receipts, e.g. thank-you message';

  @override
  String get import => 'Import';

  @override
  String get export => 'Export';

  @override
  String exportComplete(String path) {
    return 'Exported to $path';
  }

  @override
  String get noProductsImported => 'No products found in the selected file';

  @override
  String importComplete(int created, int updated, int errors) {
    return 'Imported: $created added, $updated updated, $errors failed';
  }

  @override
  String get monthlyComparison => 'Monthly comparison';

  @override
  String get month => 'Month';

  @override
  String get profitByCategory => 'Profit by category';

  @override
  String get stockValuation => 'Stock valuation';

  @override
  String get stockValueAtCost => 'Value at cost';

  @override
  String get stockValueAtRetail => 'Value at retail';

  @override
  String get potentialProfit => 'Potential profit';

  @override
  String get totalItems => 'Products in stock';

  @override
  String get brandName => 'Brand name';

  @override
  String get genericName => 'Generic name';

  @override
  String get dose => 'Dose / Dosage';

  @override
  String get profitMargin => 'Profit Margin';

  @override
  String get supplierCompany => 'Company';

  @override
  String get supplierCompanyContact => 'Company contact number';

  @override
  String get serverSettings => 'Server Configuration';

  @override
  String get apiUrl => 'API Server Base URL';

  @override
  String get branchId => 'Branch ID';

  @override
  String get testConnection => 'Test Connection';

  @override
  String get apiConnected => 'Successfully connected to Laravel API!';

  @override
  String get apiConnectionFailed =>
      'Failed to connect to API server. Check URL and server status.';

  @override
  String get invalidUrl => 'Please enter a valid URL';

  @override
  String get superAdminRole => 'Super Admin (HQ)';

  @override
  String get branchAdminRole => 'Branch Admin';

  @override
  String get viewAll => 'View all';

  @override
  String get pendingPurchases => 'Pending Purchases';

  @override
  String get estStockValuation => 'Est. Stock Valuation';

  @override
  String get grossMarginCogs => 'Gross Margin (COGS)';

  @override
  String get inventoryValuation => 'Inventory Valuation';

  @override
  String get totalCostValue => 'Total Cost Value';

  @override
  String get totalRetailValue => 'Total Retail Value';

  @override
  String get noRecentSales => 'No recent sales recorded.';

  @override
  String get quickActions => 'Quick Actions';

  @override
  String get hqSettings => 'HQ Settings';

  @override
  String get backups => 'Backups';

  @override
  String ordersCount(int count) {
    return '$count Orders';
  }

  @override
  String txCount(int count) {
    return '$count tx';
  }

  @override
  String itemsLeft(int count) {
    return '$count left';
  }

  @override
  String get requestUnlistedDrug => 'Add / Request Unlisted Drug';

  @override
  String get customDrugName => 'Drug / Product Name';

  @override
  String get customDrugCategory => 'Category (Optional)';

  @override
  String get unassignedSupplierNotice =>
      'Supplier and prices can be assigned later by admin.';

  @override
  String get purchaseApproval => 'Purchase Approval';

  @override
  String get approveAndRestock => 'Approve & Restock';

  @override
  String get pendingApproval => 'Pending Approval';

  @override
  String get approved => 'Approved';

  @override
  String get branchStaffManagement => 'Branch Staff Management';

  @override
  String get addStaffMember => 'Add Staff Member';

  @override
  String get managedBySuperAdmin => 'Managed by Super Admin';

  @override
  String get outOfStockRequest => 'Out of Stock Drug Request';

  @override
  String get requestDrugForCustomer => 'Request Drug for Customer';

  @override
  String get requestedDrugName => 'Requested Drug Name';

  @override
  String get customerWishlistSaved => 'Customer drug request saved';

  @override
  String get requestNewStock => 'Request Restock';

  @override
  String get restockAllLowStock => 'Restock All Low Stock';

  @override
  String get lowStockFilter => 'Low Stock';

  @override
  String get allProductsFilter => 'All Products';

  @override
  String get expired => 'Expired';

  @override
  String get stockAdjusted => 'Stock adjusted successfully';

  @override
  String get cogs => 'Cost of Goods (COGS)';

  @override
  String get averageOrderValue => 'Avg Order Value';

  @override
  String get grossRevenue => 'Gross Revenue';

  @override
  String get totalDiscounts => 'Discounts';

  @override
  String get totalTax => 'Tax';

  @override
  String get totalPurchasesCount => 'Purchase Orders';

  @override
  String get today => 'Today';

  @override
  String get last7Days => 'Last 7 Days';

  @override
  String get last30Days => 'Last 30 Days';

  @override
  String get thisMonth => 'This Month';

  @override
  String get customRange => 'Custom Range';

  @override
  String get paymentBreakdownSubtitle =>
      'Revenue share and volume across payment channels';

  @override
  String get topProductsSubtitle => 'Highest grossing products in this period';

  @override
  String get margin => 'Margin';

  @override
  String get salesTrends => 'Daily Sales Trends';

  @override
  String get salesTrendsSubtitle =>
      'Daily transaction volume and revenue curve';

  @override
  String get stockValuationTitle => 'Stock Inventory Valuation';

  @override
  String get stockCostBasis => 'Wholesale Cost Basis';

  @override
  String get potentialStockProfit => 'Unrealized Stock Profit';

  @override
  String get annualLedger => '12-Month Financial Ledger';

  @override
  String get annualLedgerSubtitle =>
      'Historical performance and monthly margins';

  @override
  String get printReport => 'Print Report';

  @override
  String get printPreview => 'Report Preview';

  @override
  String get unitsSold => 'Units Sold';

  @override
  String get rankMedal => 'Rank';

  @override
  String get financialLedgerSummary => 'Financial Summary';

  @override
  String get invoicesCount => 'Invoices';

  @override
  String get potentialMargin => 'Potential Margin';

  @override
  String get staffFeedback => 'Staff Restock Feedback';

  @override
  String get sendRestockFeedback => 'Restock Request / Feedback';

  @override
  String get feedbackSubmitted => 'Restock feedback submitted to branch admin';

  @override
  String get branchRestockRequests => 'Staff Restock Recommendations';

  @override
  String get urgencyHighDemand => 'High Demand';

  @override
  String get urgencyLowStock => 'Low Stock / Out of Stock';

  @override
  String get urgencyNormal => 'Regular Restock';

  @override
  String get suggestedQty => 'Suggested Quantity';

  @override
  String get staffNotes => 'Staff Notes (optional)';

  @override
  String get createPurchaseOrderForDrug => 'Create Purchase Order';

  @override
  String get markOrdered => 'Mark Ordered';

  @override
  String get dismissFeedback => 'Dismiss';

  @override
  String get noStaffFeedback =>
      'No pending staff restock recommendations for this branch';

  @override
  String get cashierFeedbackSubtitle =>
      'Frontline cashier insights and restock requests';

  @override
  String reportedBy(String name) {
    return 'Reported by $name';
  }

  @override
  String get offlineModeBannerTitle =>
      'Operating in Offline Mode — Local Storage Active';

  @override
  String get offlineModeBannerSubtitle =>
      'All changes are saved locally to SQLite.';

  @override
  String offlinePendingTransactions(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions queued for sync.',
      one: '1 transaction queued for sync.',
    );
    return '$_temp0';
  }

  @override
  String get syncFailedBannerTitle =>
      'Sync Failed — Retries When Connection Is Stable';

  @override
  String get networkRestoredBannerTitle =>
      'Network Restored — Synchronizing with Server...';

  @override
  String get pendingSyncBannerTitle => 'Pending Local Changes Ready to Sync';

  @override
  String get reconcilingRecordsSubtitle =>
      'Reconciling pending records and updating stock...';

  @override
  String pendingServerReconciliation(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count offline transactions pending server reconciliation.',
      one: '1 offline transaction pending server reconciliation.',
    );
    return '$_temp0';
  }

  @override
  String get checkConnection => 'Check Connection';

  @override
  String get syncNow => 'Sync Now';

  @override
  String get supervisorAuthorization => 'Supervisor Authorization';

  @override
  String get supervisorUsernameOptional => 'Supervisor Username (optional)';

  @override
  String get supervisorPasswordPin => 'Supervisor Password / PIN *';

  @override
  String get authorize => 'Authorize';

  @override
  String get invalidSupervisorPassword =>
      'Invalid local supervisor password or PIN.';

  @override
  String get checkForUpdates => 'Check for Updates';

  @override
  String get checkingForUpdates => 'Checking for updates...';

  @override
  String get upToDate => 'MePharma is up to date';

  @override
  String get updateAvailable => 'Update Available';

  @override
  String get paymentBankTransfer => 'Bank transfer';

  @override
  String get transactionReference => 'Transaction reference';

  @override
  String get transactionRefHint => 'Enter bank transfer reference number';

  @override
  String get transactionRefRequired =>
      'Transaction reference is required for bank transfer';

  @override
  String get refresh => 'Refresh';

  @override
  String get refreshing => 'Refreshing...';

  @override
  String localOfflineTransactions(int count) {
    return 'Local Offline Transactions ($count)';
  }

  @override
  String serverSyncedTransactions(int count) {
    return 'Server Synced Transactions ($count)';
  }

  @override
  String localSavedTransactions(int count) {
    return 'Local Sales Ledger ($count)';
  }

  @override
  String get offlineQueueNotice =>
      'These transactions were saved locally while offline and will sync automatically when online.';

  @override
  String get syncingTransactions =>
      'Synchronizing local transactions with server...';

  @override
  String get superAdminShort => 'Super Admin';

  @override
  String get branchAdminShort => 'Branch Admin';

  @override
  String get staffShort => 'Staff';

  @override
  String get localModeActive => 'Local Mode';

  @override
  String purchaseApprovedNotice(String invoice) {
    return 'Purchase request $invoice has been approved and inventory is updated.';
  }

  @override
  String printedOn(String date) {
    return 'Printed on $date';
  }

  @override
  String get stockOut => 'Out of stock';

  @override
  String get confirmApprovePurchase =>
      'Are you sure you want to approve this purchase order and add its inventory to branch stock?';

  @override
  String get supervisorApprovePurchaseReason =>
      'Approving purchase orders and updating stock requires Branch Administrator or Supervisor authorization.';

  @override
  String get supervisorReturnReason =>
      'Processing refunds and returns requires supervisor override.';

  @override
  String get terminalQuotaTitle => 'Terminal Seat Limit Reached';

  @override
  String get terminalQuotaInfo =>
      'To add more cash counters or desktop terminals, please request a license seat upgrade on the Provider Platform.';

  @override
  String get understood => 'Understood';

  @override
  String get supervisorAuthTitle => 'Supervisor Authorization';

  @override
  String get supervisorPasswordRequired => 'Supervisor Password / PIN *';

  @override
  String get requestOutOfStockDrug => 'Request Out-of-Stock Drug';

  @override
  String get diagnosticsCopied => 'Diagnostics copied to clipboard';

  @override
  String get copyErrorDiagnostics => 'Copy Error Diagnostics';

  @override
  String get purchasesExpenditure => 'Purchases & Procurement Expenditure';

  @override
  String get netOperatingCashFlow =>
      'Net Operating Cash Flow (Sales - Purchases)';

  @override
  String get purchasesBySupplier => 'Purchases by Supplier';

  @override
  String get purchasesBySupplierSubtitle =>
      'Procurement and supply spend distribution by supplier';

  @override
  String get topPurchasedItems => 'Top Purchased Medicines';

  @override
  String get topPurchasedItemsSubtitle =>
      'Medicines with the highest procurement spend during this period';

  @override
  String get unitsPurchased => 'units purchased';

  @override
  String get pendingSpend => 'Pending PO';

  @override
  String get fulfilledSpend => 'Fulfilled & Stocked';

  @override
  String get salesReturns => 'Sales Returns';

  @override
  String get returnsSubtitle =>
      'Customer sales refunds and product return history';

  @override
  String get newReturn => 'New Return';

  @override
  String get refundAmount => 'Refund Amount';

  @override
  String get noReturns => 'No returns recorded yet';

  @override
  String get selectSaleToReturn => 'Select Invoice to Return';

  @override
  String get searchByInvoiceOrReason => 'Search by invoice number or reason...';
}
