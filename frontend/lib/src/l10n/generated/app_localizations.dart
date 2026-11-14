import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy Management System'**
  String get appTitle;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signingIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in...'**
  String get signingIn;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @invalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid username or password'**
  String get invalidCredentials;

  /// No description provided for @errorLogin.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorLogin;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @arabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get arabic;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @pos.
  ///
  /// In en, this message translates to:
  /// **'Point of Sale'**
  String get pos;

  /// No description provided for @salesHistory.
  ///
  /// In en, this message translates to:
  /// **'Sales History'**
  String get salesHistory;

  /// No description provided for @products.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get products;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @suppliers.
  ///
  /// In en, this message translates to:
  /// **'Suppliers'**
  String get suppliers;

  /// No description provided for @purchases.
  ///
  /// In en, this message translates to:
  /// **'Purchases'**
  String get purchases;

  /// No description provided for @users.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get users;

  /// No description provided for @reports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reports;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @backup.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get backup;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logout;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back, {name}'**
  String welcomeBack(String name);

  /// No description provided for @welcomeBackMessage.
  ///
  /// In en, this message translates to:
  /// **'You are signed in as {role}'**
  String welcomeBackMessage(String role);

  /// No description provided for @roleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Administrator'**
  String get roleAdmin;

  /// No description provided for @roleStaff.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get roleStaff;

  /// No description provided for @quickSale.
  ///
  /// In en, this message translates to:
  /// **'New sale'**
  String get quickSale;

  /// No description provided for @todaySales.
  ///
  /// In en, this message translates to:
  /// **'Today\'s sales'**
  String get todaySales;

  /// No description provided for @lowStockItems.
  ///
  /// In en, this message translates to:
  /// **'Low stock items'**
  String get lowStockItems;

  /// No description provided for @actions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get actions;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get saving;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @searchProducts.
  ///
  /// In en, this message translates to:
  /// **'Search by name, SKU, or barcode'**
  String get searchProducts;

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get fieldRequired;

  /// No description provided for @invalidNumber.
  ///
  /// In en, this message translates to:
  /// **'Invalid number'**
  String get invalidNumber;

  /// No description provided for @alreadyInUse.
  ///
  /// In en, this message translates to:
  /// **'{field} is already in use'**
  String alreadyInUse(String field);

  /// No description provided for @errorOccurred.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorOccurred;

  /// No description provided for @sku.
  ///
  /// In en, this message translates to:
  /// **'SKU'**
  String get sku;

  /// No description provided for @barcode.
  ///
  /// In en, this message translates to:
  /// **'Barcode'**
  String get barcode;

  /// No description provided for @productName.
  ///
  /// In en, this message translates to:
  /// **'Product name'**
  String get productName;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @supplier.
  ///
  /// In en, this message translates to:
  /// **'Supplier'**
  String get supplier;

  /// No description provided for @costPrice.
  ///
  /// In en, this message translates to:
  /// **'Cost price'**
  String get costPrice;

  /// No description provided for @sellingPrice.
  ///
  /// In en, this message translates to:
  /// **'Selling price'**
  String get sellingPrice;

  /// No description provided for @stock.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get stock;

  /// No description provided for @lowStockThreshold.
  ///
  /// In en, this message translates to:
  /// **'Low stock alert at'**
  String get lowStockThreshold;

  /// No description provided for @expiryDate.
  ///
  /// In en, this message translates to:
  /// **'Expiry date'**
  String get expiryDate;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @noCategory.
  ///
  /// In en, this message translates to:
  /// **'No category'**
  String get noCategory;

  /// No description provided for @noSupplier.
  ///
  /// In en, this message translates to:
  /// **'No supplier'**
  String get noSupplier;

  /// No description provided for @noProducts.
  ///
  /// In en, this message translates to:
  /// **'No products found'**
  String get noProducts;

  /// No description provided for @addProduct.
  ///
  /// In en, this message translates to:
  /// **'Add product'**
  String get addProduct;

  /// No description provided for @editProduct.
  ///
  /// In en, this message translates to:
  /// **'Edit product'**
  String get editProduct;

  /// No description provided for @deleteProduct.
  ///
  /// In en, this message translates to:
  /// **'Delete product'**
  String get deleteProduct;

  /// No description provided for @productAdded.
  ///
  /// In en, this message translates to:
  /// **'Product added'**
  String get productAdded;

  /// No description provided for @productSaved.
  ///
  /// In en, this message translates to:
  /// **'Product saved'**
  String get productSaved;

  /// No description provided for @productDeleted.
  ///
  /// In en, this message translates to:
  /// **'Product deleted'**
  String get productDeleted;

  /// No description provided for @confirmDeleteProduct.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String confirmDeleteProduct(String name);

  /// No description provided for @confirmDeleteProductMessage.
  ///
  /// In en, this message translates to:
  /// **'This will remove the product from inventory. This action cannot be undone.'**
  String get confirmDeleteProductMessage;

  /// No description provided for @adjustStock.
  ///
  /// In en, this message translates to:
  /// **'Adjust Stock'**
  String get adjustStock;

  /// No description provided for @stockAdjustment.
  ///
  /// In en, this message translates to:
  /// **'Stock Adjustment'**
  String get stockAdjustment;

  /// No description provided for @adjustmentQuantity.
  ///
  /// In en, this message translates to:
  /// **'Adjustment Quantity (+/-)'**
  String get adjustmentQuantity;

  /// No description provided for @adjustmentReason.
  ///
  /// In en, this message translates to:
  /// **'Reason (Optional)'**
  String get adjustmentReason;

  /// No description provided for @adjustmentReasonHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Inventory audit, damaged items, return to supplier'**
  String get adjustmentReasonHint;

  /// No description provided for @positiveAddsNegativeRemoves.
  ///
  /// In en, this message translates to:
  /// **'Positive number adds stock, negative removes stock.'**
  String get positiveAddsNegativeRemoves;

  /// No description provided for @currentStock.
  ///
  /// In en, this message translates to:
  /// **'Current stock'**
  String get currentStock;

  /// No description provided for @addCategory.
  ///
  /// In en, this message translates to:
  /// **'Add category'**
  String get addCategory;

  /// No description provided for @editCategory.
  ///
  /// In en, this message translates to:
  /// **'Edit category'**
  String get editCategory;

  /// No description provided for @categoryName.
  ///
  /// In en, this message translates to:
  /// **'Category name'**
  String get categoryName;

  /// No description provided for @deleteCategory.
  ///
  /// In en, this message translates to:
  /// **'Delete category'**
  String get deleteCategory;

  /// No description provided for @categoryAdded.
  ///
  /// In en, this message translates to:
  /// **'Category added'**
  String get categoryAdded;

  /// No description provided for @categorySaved.
  ///
  /// In en, this message translates to:
  /// **'Category saved'**
  String get categorySaved;

  /// No description provided for @confirmDeleteCategory.
  ///
  /// In en, this message translates to:
  /// **'Delete category {name}?'**
  String confirmDeleteCategory(String name);

  /// No description provided for @noCategories.
  ///
  /// In en, this message translates to:
  /// **'No categories yet'**
  String get noCategories;

  /// No description provided for @addSupplier.
  ///
  /// In en, this message translates to:
  /// **'Add supplier'**
  String get addSupplier;

  /// No description provided for @editSupplier.
  ///
  /// In en, this message translates to:
  /// **'Edit supplier'**
  String get editSupplier;

  /// No description provided for @supplierName.
  ///
  /// In en, this message translates to:
  /// **'Supplier name'**
  String get supplierName;

  /// No description provided for @contactPerson.
  ///
  /// In en, this message translates to:
  /// **'Contact person'**
  String get contactPerson;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @deleteSupplier.
  ///
  /// In en, this message translates to:
  /// **'Delete supplier'**
  String get deleteSupplier;

  /// No description provided for @supplierAdded.
  ///
  /// In en, this message translates to:
  /// **'Supplier added'**
  String get supplierAdded;

  /// No description provided for @supplierSaved.
  ///
  /// In en, this message translates to:
  /// **'Supplier saved'**
  String get supplierSaved;

  /// No description provided for @confirmDeleteSupplier.
  ///
  /// In en, this message translates to:
  /// **'Delete supplier {name}?'**
  String confirmDeleteSupplier(String name);

  /// No description provided for @noSuppliers.
  ///
  /// In en, this message translates to:
  /// **'No suppliers yet'**
  String get noSuppliers;

  /// No description provided for @storeSettings.
  ///
  /// In en, this message translates to:
  /// **'Store settings'**
  String get storeSettings;

  /// No description provided for @storeName.
  ///
  /// In en, this message translates to:
  /// **'Store name'**
  String get storeName;

  /// No description provided for @storeAddress.
  ///
  /// In en, this message translates to:
  /// **'Store address'**
  String get storeAddress;

  /// No description provided for @storePhone.
  ///
  /// In en, this message translates to:
  /// **'Store phone'**
  String get storePhone;

  /// No description provided for @storeTaxId.
  ///
  /// In en, this message translates to:
  /// **'Tax ID'**
  String get storeTaxId;

  /// No description provided for @taxRate.
  ///
  /// In en, this message translates to:
  /// **'Tax rate (%)'**
  String get taxRate;

  /// No description provided for @currencySymbol.
  ///
  /// In en, this message translates to:
  /// **'Currency symbol'**
  String get currencySymbol;

  /// No description provided for @scanBarcode.
  ///
  /// In en, this message translates to:
  /// **'Scan barcode, SKU, name, or generic name...'**
  String get scanBarcode;

  /// No description provided for @productNotFound.
  ///
  /// In en, this message translates to:
  /// **'Product not found'**
  String get productNotFound;

  /// No description provided for @outOfStock.
  ///
  /// In en, this message translates to:
  /// **'Out of stock: {name}'**
  String outOfStock(String name);

  /// No description provided for @emptyCart.
  ///
  /// In en, this message translates to:
  /// **'The cart is empty'**
  String get emptyCart;

  /// No description provided for @insufficientStock.
  ///
  /// In en, this message translates to:
  /// **'Insufficient stock'**
  String get insufficientStock;

  /// No description provided for @insufficientReceived.
  ///
  /// In en, this message translates to:
  /// **'Amount received is less than the total'**
  String get insufficientReceived;

  /// No description provided for @cart.
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get cart;

  /// No description provided for @clearCart.
  ///
  /// In en, this message translates to:
  /// **'Clear cart'**
  String get clearCart;

  /// No description provided for @confirmClearCartMessage.
  ///
  /// In en, this message translates to:
  /// **'All items will be removed from the cart.'**
  String get confirmClearCartMessage;

  /// No description provided for @newSale.
  ///
  /// In en, this message translates to:
  /// **'New sale'**
  String get newSale;

  /// No description provided for @holdSale.
  ///
  /// In en, this message translates to:
  /// **'Hold sale'**
  String get holdSale;

  /// No description provided for @resumeHold.
  ///
  /// In en, this message translates to:
  /// **'Resume hold'**
  String get resumeHold;

  /// No description provided for @saleHeld.
  ///
  /// In en, this message translates to:
  /// **'Sale held'**
  String get saleHeld;

  /// No description provided for @saleCompleted.
  ///
  /// In en, this message translates to:
  /// **'Sale completed: {invoice}'**
  String saleCompleted(String invoice);

  /// No description provided for @noHolds.
  ///
  /// In en, this message translates to:
  /// **'No held sales'**
  String get noHolds;

  /// No description provided for @deleteHold.
  ///
  /// In en, this message translates to:
  /// **'Delete hold'**
  String get deleteHold;

  /// No description provided for @confirmDeleteHold.
  ///
  /// In en, this message translates to:
  /// **'Delete hold {number}?'**
  String confirmDeleteHold(String number);

  /// No description provided for @holdPartiallyRestored.
  ///
  /// In en, this message translates to:
  /// **'Some products are no longer available and were skipped: {missing}'**
  String holdPartiallyRestored(String missing);

  /// No description provided for @subtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get subtotal;

  /// No description provided for @discount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get discount;

  /// No description provided for @discountNone.
  ///
  /// In en, this message translates to:
  /// **'No discount'**
  String get discountNone;

  /// No description provided for @discountPercentage.
  ///
  /// In en, this message translates to:
  /// **'Percentage'**
  String get discountPercentage;

  /// No description provided for @discountFixed.
  ///
  /// In en, this message translates to:
  /// **'Fixed amount'**
  String get discountFixed;

  /// No description provided for @tax.
  ///
  /// In en, this message translates to:
  /// **'Tax'**
  String get tax;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @pay.
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get pay;

  /// No description provided for @payment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get payment;

  /// No description provided for @paymentCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get paymentCash;

  /// No description provided for @paymentCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get paymentCard;

  /// No description provided for @paymentMobileMoney.
  ///
  /// In en, this message translates to:
  /// **'Mobile money'**
  String get paymentMobileMoney;

  /// No description provided for @amountReceived.
  ///
  /// In en, this message translates to:
  /// **'Amount received'**
  String get amountReceived;

  /// No description provided for @changeDue.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get changeDue;

  /// No description provided for @confirmPayment.
  ///
  /// In en, this message translates to:
  /// **'Confirm payment'**
  String get confirmPayment;

  /// No description provided for @receiptInvoice.
  ///
  /// In en, this message translates to:
  /// **'Invoice:'**
  String get receiptInvoice;

  /// No description provided for @receiptCashier.
  ///
  /// In en, this message translates to:
  /// **'Cashier:'**
  String get receiptCashier;

  /// No description provided for @receiptCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer:'**
  String get receiptCustomer;

  /// No description provided for @receiptOnAccount.
  ///
  /// In en, this message translates to:
  /// **'On account'**
  String get receiptOnAccount;

  /// No description provided for @receiptThanks.
  ///
  /// In en, this message translates to:
  /// **'Thank you for your purchase!'**
  String get receiptThanks;

  /// No description provided for @printFailed.
  ///
  /// In en, this message translates to:
  /// **'Print failed'**
  String get printFailed;

  /// No description provided for @printFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'The receipt could not be printed. Check the printer settings and try again, or print it later from Sales History.'**
  String get printFailedMessage;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @hintScan.
  ///
  /// In en, this message translates to:
  /// **'F1 Scan'**
  String get hintScan;

  /// No description provided for @hintPay.
  ///
  /// In en, this message translates to:
  /// **'F2 Pay'**
  String get hintPay;

  /// No description provided for @hintHold.
  ///
  /// In en, this message translates to:
  /// **'F4 Hold'**
  String get hintHold;

  /// No description provided for @hintClear.
  ///
  /// In en, this message translates to:
  /// **'Esc Clear'**
  String get hintClear;

  /// No description provided for @printerSettings.
  ///
  /// In en, this message translates to:
  /// **'Printer settings'**
  String get printerSettings;

  /// No description provided for @printerType.
  ///
  /// In en, this message translates to:
  /// **'Printer type'**
  String get printerType;

  /// No description provided for @printerNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get printerNone;

  /// No description provided for @printerWindows.
  ///
  /// In en, this message translates to:
  /// **'Windows printer (USB / driver)'**
  String get printerWindows;

  /// No description provided for @printerNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network printer (TCP / 9100)'**
  String get printerNetwork;

  /// No description provided for @printerAddress.
  ///
  /// In en, this message translates to:
  /// **'Printer name or address'**
  String get printerAddress;

  /// No description provided for @printerAddressHintWindows.
  ///
  /// In en, this message translates to:
  /// **'Name of the installed printer'**
  String get printerAddressHintWindows;

  /// No description provided for @printerAddressHintNetwork.
  ///
  /// In en, this message translates to:
  /// **'e.g. 192.168.1.50'**
  String get printerAddressHintNetwork;

  /// No description provided for @printerPort.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get printerPort;

  /// No description provided for @paperSize.
  ///
  /// In en, this message translates to:
  /// **'Paper size'**
  String get paperSize;

  /// No description provided for @testPrint.
  ///
  /// In en, this message translates to:
  /// **'Test print'**
  String get testPrint;

  /// No description provided for @testReceiptSent.
  ///
  /// In en, this message translates to:
  /// **'Test receipt sent to printer'**
  String get testReceiptSent;

  /// No description provided for @from.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get from;

  /// No description provided for @to.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get to;

  /// No description provided for @searchInvoice.
  ///
  /// In en, this message translates to:
  /// **'Search by invoice number or customer'**
  String get searchInvoice;

  /// No description provided for @dateRange.
  ///
  /// In en, this message translates to:
  /// **'Date range'**
  String get dateRange;

  /// No description provided for @paymentAll.
  ///
  /// In en, this message translates to:
  /// **'All payments'**
  String get paymentAll;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @statusAll.
  ///
  /// In en, this message translates to:
  /// **'All statuses'**
  String get statusAll;

  /// No description provided for @resetFilters.
  ///
  /// In en, this message translates to:
  /// **'Reset filters'**
  String get resetFilters;

  /// No description provided for @noSales.
  ///
  /// In en, this message translates to:
  /// **'No sales match the current filters'**
  String get noSales;

  /// No description provided for @saleStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get saleStatusCompleted;

  /// No description provided for @saleStatusReturned.
  ///
  /// In en, this message translates to:
  /// **'Returned'**
  String get saleStatusReturned;

  /// No description provided for @saleStatusVoided.
  ///
  /// In en, this message translates to:
  /// **'Voided'**
  String get saleStatusVoided;

  /// No description provided for @saleDetail.
  ///
  /// In en, this message translates to:
  /// **'Sale detail'**
  String get saleDetail;

  /// No description provided for @printReceipt.
  ///
  /// In en, this message translates to:
  /// **'Print receipt'**
  String get printReceipt;

  /// No description provided for @returnItems.
  ///
  /// In en, this message translates to:
  /// **'Return items'**
  String get returnItems;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @cashier.
  ///
  /// In en, this message translates to:
  /// **'Cashier'**
  String get cashier;

  /// No description provided for @customer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get customer;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @returns.
  ///
  /// In en, this message translates to:
  /// **'Returns'**
  String get returns;

  /// No description provided for @returnProcessed.
  ///
  /// In en, this message translates to:
  /// **'Return processed'**
  String get returnProcessed;

  /// No description provided for @nothingToReturn.
  ///
  /// In en, this message translates to:
  /// **'Select at least one item to return'**
  String get nothingToReturn;

  /// No description provided for @processReturn.
  ///
  /// In en, this message translates to:
  /// **'Process return'**
  String get processReturn;

  /// No description provided for @returnReason.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get returnReason;

  /// No description provided for @returnReasonHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. wrong item, damaged'**
  String get returnReasonHint;

  /// No description provided for @sold.
  ///
  /// In en, this message translates to:
  /// **'Sold'**
  String get sold;

  /// No description provided for @alreadyReturned.
  ///
  /// In en, this message translates to:
  /// **'Already returned'**
  String get alreadyReturned;

  /// No description provided for @newPurchase.
  ///
  /// In en, this message translates to:
  /// **'New purchase'**
  String get newPurchase;

  /// No description provided for @purchaseSaved.
  ///
  /// In en, this message translates to:
  /// **'Purchase saved'**
  String get purchaseSaved;

  /// No description provided for @noPurchases.
  ///
  /// In en, this message translates to:
  /// **'No purchases yet'**
  String get noPurchases;

  /// No description provided for @purchaseDetail.
  ///
  /// In en, this message translates to:
  /// **'Purchase detail'**
  String get purchaseDetail;

  /// No description provided for @selectSupplier.
  ///
  /// In en, this message translates to:
  /// **'Select Supplier'**
  String get selectSupplier;

  /// No description provided for @noPurchaseLines.
  ///
  /// In en, this message translates to:
  /// **'No purchase lines yet'**
  String get noPurchaseLines;

  /// No description provided for @purchaseDate.
  ///
  /// In en, this message translates to:
  /// **'Purchase date'**
  String get purchaseDate;

  /// No description provided for @purchaseTotal.
  ///
  /// In en, this message translates to:
  /// **'Purchase total'**
  String get purchaseTotal;

  /// No description provided for @addLine.
  ///
  /// In en, this message translates to:
  /// **'Add line'**
  String get addLine;

  /// No description provided for @decrease.
  ///
  /// In en, this message translates to:
  /// **'Decrease'**
  String get decrease;

  /// No description provided for @increase.
  ///
  /// In en, this message translates to:
  /// **'Increase'**
  String get increase;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @selectProduct.
  ///
  /// In en, this message translates to:
  /// **'Select product'**
  String get selectProduct;

  /// No description provided for @searchProduct.
  ///
  /// In en, this message translates to:
  /// **'Search products'**
  String get searchProduct;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get noResults;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @unitCost.
  ///
  /// In en, this message translates to:
  /// **'Unit cost'**
  String get unitCost;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @invalidLineValues.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid quantity and unit cost'**
  String get invalidLineValues;

  /// No description provided for @productAlreadyAdded.
  ///
  /// In en, this message translates to:
  /// **'Product is already in the purchase lines'**
  String get productAlreadyAdded;

  /// No description provided for @addUser.
  ///
  /// In en, this message translates to:
  /// **'Add user'**
  String get addUser;

  /// No description provided for @editUser.
  ///
  /// In en, this message translates to:
  /// **'Edit user'**
  String get editUser;

  /// No description provided for @userAdded.
  ///
  /// In en, this message translates to:
  /// **'User added'**
  String get userAdded;

  /// No description provided for @userSaved.
  ///
  /// In en, this message translates to:
  /// **'User saved'**
  String get userSaved;

  /// No description provided for @role.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get role;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @inactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get inactive;

  /// No description provided for @cannotDeactivateSelf.
  ///
  /// In en, this message translates to:
  /// **'You cannot deactivate your own account'**
  String get cannotDeactivateSelf;

  /// No description provided for @needOneActiveAdmin.
  ///
  /// In en, this message translates to:
  /// **'At least one active administrator is required'**
  String get needOneActiveAdmin;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @leaveEmptyToKeep.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to keep the current password'**
  String get leaveEmptyToKeep;

  /// No description provided for @salesCount.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get salesCount;

  /// No description provided for @revenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get revenue;

  /// No description provided for @netRevenue.
  ///
  /// In en, this message translates to:
  /// **'Net revenue'**
  String get netRevenue;

  /// No description provided for @refunds.
  ///
  /// In en, this message translates to:
  /// **'Refunds'**
  String get refunds;

  /// No description provided for @purchasesCost.
  ///
  /// In en, this message translates to:
  /// **'Purchases cost'**
  String get purchasesCost;

  /// No description provided for @estimatedProfit.
  ///
  /// In en, this message translates to:
  /// **'Estimated profit'**
  String get estimatedProfit;

  /// No description provided for @totalSales.
  ///
  /// In en, this message translates to:
  /// **'Total sales'**
  String get totalSales;

  /// No description provided for @salesByPayment.
  ///
  /// In en, this message translates to:
  /// **'Sales by payment method'**
  String get salesByPayment;

  /// No description provided for @topProducts.
  ///
  /// In en, this message translates to:
  /// **'Top products'**
  String get topProducts;

  /// No description provided for @exportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export CSV'**
  String get exportCsv;

  /// No description provided for @exportedTo.
  ///
  /// In en, this message translates to:
  /// **'Report exported to {path}'**
  String exportedTo(String path);

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No data for this period'**
  String get noData;

  /// No description provided for @createBackup.
  ///
  /// In en, this message translates to:
  /// **'Create backup'**
  String get createBackup;

  /// No description provided for @backupCreated.
  ///
  /// In en, this message translates to:
  /// **'Backup created: {path}'**
  String backupCreated(String path);

  /// No description provided for @backupFailed.
  ///
  /// In en, this message translates to:
  /// **'Backup failed'**
  String get backupFailed;

  /// No description provided for @restoreBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restoreBackup;

  /// No description provided for @confirmRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore backup {name}? This will replace all current data with the backup.'**
  String confirmRestore(String name);

  /// No description provided for @restoreComplete.
  ///
  /// In en, this message translates to:
  /// **'Backup restored. Please sign in again.'**
  String get restoreComplete;

  /// No description provided for @restoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Restore failed'**
  String get restoreFailed;

  /// No description provided for @backupsLocation.
  ///
  /// In en, this message translates to:
  /// **'Backups are stored in your Documents folder (MePharmaBackups).'**
  String get backupsLocation;

  /// No description provided for @noBackups.
  ///
  /// In en, this message translates to:
  /// **'No backups yet'**
  String get noBackups;

  /// No description provided for @confirmDeleteBackup.
  ///
  /// In en, this message translates to:
  /// **'Delete backup {fileName}? This cannot be undone.'**
  String confirmDeleteBackup(String fileName);

  /// No description provided for @backupDeleted.
  ///
  /// In en, this message translates to:
  /// **'Backup deleted'**
  String get backupDeleted;

  /// No description provided for @customers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get customers;

  /// No description provided for @expiry.
  ///
  /// In en, this message translates to:
  /// **'Expiry'**
  String get expiry;

  /// No description provided for @paymentCredit.
  ///
  /// In en, this message translates to:
  /// **'On account'**
  String get paymentCredit;

  /// No description provided for @creditChargedToAccount.
  ///
  /// In en, this message translates to:
  /// **'This amount will be added to the customer\'s account balance.'**
  String get creditChargedToAccount;

  /// No description provided for @creditNeedsCustomer.
  ///
  /// In en, this message translates to:
  /// **'Select a customer to charge this sale to their account.'**
  String get creditNeedsCustomer;

  /// No description provided for @creditLimitExceeded.
  ///
  /// In en, this message translates to:
  /// **'This sale exceeds the customer\'s credit limit.'**
  String get creditLimitExceeded;

  /// No description provided for @outstandingBalance.
  ///
  /// In en, this message translates to:
  /// **'Outstanding balance'**
  String get outstandingBalance;

  /// No description provided for @walkInCustomer.
  ///
  /// In en, this message translates to:
  /// **'Walk-in customer'**
  String get walkInCustomer;

  /// No description provided for @productExpired.
  ///
  /// In en, this message translates to:
  /// **'This product has expired and cannot be sold.'**
  String get productExpired;

  /// No description provided for @addCustomer.
  ///
  /// In en, this message translates to:
  /// **'Add customer'**
  String get addCustomer;

  /// No description provided for @editCustomer.
  ///
  /// In en, this message translates to:
  /// **'Edit customer'**
  String get editCustomer;

  /// No description provided for @customerName.
  ///
  /// In en, this message translates to:
  /// **'Customer name'**
  String get customerName;

  /// No description provided for @creditLimit.
  ///
  /// In en, this message translates to:
  /// **'Credit limit'**
  String get creditLimit;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @customerAdded.
  ///
  /// In en, this message translates to:
  /// **'Customer added'**
  String get customerAdded;

  /// No description provided for @customerSaved.
  ///
  /// In en, this message translates to:
  /// **'Customer saved'**
  String get customerSaved;

  /// No description provided for @recordPayment.
  ///
  /// In en, this message translates to:
  /// **'Record payment'**
  String get recordPayment;

  /// No description provided for @recordPaymentFor.
  ///
  /// In en, this message translates to:
  /// **'Record payment for {name}'**
  String recordPaymentFor(String name);

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get note;

  /// No description provided for @paymentRecorded.
  ///
  /// In en, this message translates to:
  /// **'Payment recorded'**
  String get paymentRecorded;

  /// No description provided for @balance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get balance;

  /// No description provided for @paymentHistory.
  ///
  /// In en, this message translates to:
  /// **'Payment history'**
  String get paymentHistory;

  /// No description provided for @noPayments.
  ///
  /// In en, this message translates to:
  /// **'No payments recorded yet'**
  String get noPayments;

  /// No description provided for @confirmDeleteCustomer.
  ///
  /// In en, this message translates to:
  /// **'Delete customer {name}?'**
  String confirmDeleteCustomer(String name);

  /// No description provided for @deleteCustomerHint.
  ///
  /// In en, this message translates to:
  /// **'The customer\'s payment history will be deleted and their sales will remain without a customer. This action cannot be undone.'**
  String get deleteCustomerHint;

  /// No description provided for @customerHasOutstandingBalance.
  ///
  /// In en, this message translates to:
  /// **'This customer has an outstanding balance of {amount}.'**
  String customerHasOutstandingBalance(String amount);

  /// No description provided for @customerNameTaken.
  ///
  /// In en, this message translates to:
  /// **'A customer with this name already exists'**
  String get customerNameTaken;

  /// No description provided for @creditLimitNegative.
  ///
  /// In en, this message translates to:
  /// **'Credit limit cannot be negative'**
  String get creditLimitNegative;

  /// No description provided for @overLimit.
  ///
  /// In en, this message translates to:
  /// **'Over limit'**
  String get overLimit;

  /// No description provided for @searchCustomers.
  ///
  /// In en, this message translates to:
  /// **'Search customers'**
  String get searchCustomers;

  /// No description provided for @noCustomers.
  ///
  /// In en, this message translates to:
  /// **'No customers yet'**
  String get noCustomers;

  /// No description provided for @payments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get payments;

  /// No description provided for @todayLabel.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayLabel;

  /// No description provided for @yesterdayLabel.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterdayLabel;

  /// No description provided for @nextDays.
  ///
  /// In en, this message translates to:
  /// **'Next {days} days'**
  String nextDays(int days);

  /// No description provided for @expiryHint.
  ///
  /// In en, this message translates to:
  /// **'Products are flagged as expired on their expiry date.'**
  String get expiryHint;

  /// No description provided for @noExpiringProducts.
  ///
  /// In en, this message translates to:
  /// **'No products expire within the selected period'**
  String get noExpiringProducts;

  /// No description provided for @expiredProducts.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get expiredProducts;

  /// No description provided for @expiringSoon.
  ///
  /// In en, this message translates to:
  /// **'Expiring soon'**
  String get expiringSoon;

  /// No description provided for @expiredOn.
  ///
  /// In en, this message translates to:
  /// **'Expired on {date}'**
  String expiredOn(String date);

  /// No description provided for @daysUntilExpiry.
  ///
  /// In en, this message translates to:
  /// **'in {days} days'**
  String daysUntilExpiry(int days);

  /// No description provided for @expiredLabel.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get expiredLabel;

  /// No description provided for @defaultLowStockThreshold.
  ///
  /// In en, this message translates to:
  /// **'Default low-stock alert'**
  String get defaultLowStockThreshold;

  /// No description provided for @defaultLowStockHint.
  ///
  /// In en, this message translates to:
  /// **'Used when adding new products'**
  String get defaultLowStockHint;

  /// No description provided for @receiptFooter.
  ///
  /// In en, this message translates to:
  /// **'Receipt footer'**
  String get receiptFooter;

  /// No description provided for @receiptFooterHint.
  ///
  /// In en, this message translates to:
  /// **'Shown at the bottom of printed receipts, e.g. thank-you message'**
  String get receiptFooterHint;

  /// No description provided for @import.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get import;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @exportComplete.
  ///
  /// In en, this message translates to:
  /// **'Exported to {path}'**
  String exportComplete(String path);

  /// No description provided for @noProductsImported.
  ///
  /// In en, this message translates to:
  /// **'No products found in the selected file'**
  String get noProductsImported;

  /// No description provided for @importComplete.
  ///
  /// In en, this message translates to:
  /// **'Imported: {created} added, {updated} updated, {errors} failed'**
  String importComplete(int created, int updated, int errors);

  /// No description provided for @monthlyComparison.
  ///
  /// In en, this message translates to:
  /// **'Monthly comparison'**
  String get monthlyComparison;

  /// No description provided for @month.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get month;

  /// No description provided for @profitByCategory.
  ///
  /// In en, this message translates to:
  /// **'Profit by category'**
  String get profitByCategory;

  /// No description provided for @stockValuation.
  ///
  /// In en, this message translates to:
  /// **'Stock valuation'**
  String get stockValuation;

  /// No description provided for @stockValueAtCost.
  ///
  /// In en, this message translates to:
  /// **'Value at cost'**
  String get stockValueAtCost;

  /// No description provided for @stockValueAtRetail.
  ///
  /// In en, this message translates to:
  /// **'Value at retail'**
  String get stockValueAtRetail;

  /// No description provided for @potentialProfit.
  ///
  /// In en, this message translates to:
  /// **'Potential profit'**
  String get potentialProfit;

  /// No description provided for @totalItems.
  ///
  /// In en, this message translates to:
  /// **'Products in stock'**
  String get totalItems;

  /// No description provided for @brandName.
  ///
  /// In en, this message translates to:
  /// **'Brand name'**
  String get brandName;

  /// No description provided for @genericName.
  ///
  /// In en, this message translates to:
  /// **'Generic name'**
  String get genericName;

  /// No description provided for @dose.
  ///
  /// In en, this message translates to:
  /// **'Dose / Dosage'**
  String get dose;

  /// No description provided for @profitMargin.
  ///
  /// In en, this message translates to:
  /// **'Profit Margin'**
  String get profitMargin;

  /// No description provided for @supplierCompany.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get supplierCompany;

  /// No description provided for @supplierCompanyContact.
  ///
  /// In en, this message translates to:
  /// **'Company contact number'**
  String get supplierCompanyContact;

  /// No description provided for @serverSettings.
  ///
  /// In en, this message translates to:
  /// **'Server Configuration'**
  String get serverSettings;

  /// No description provided for @apiUrl.
  ///
  /// In en, this message translates to:
  /// **'API Server Base URL'**
  String get apiUrl;

  /// No description provided for @branchId.
  ///
  /// In en, this message translates to:
  /// **'Branch ID'**
  String get branchId;

  /// No description provided for @testConnection.
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get testConnection;

  /// No description provided for @apiConnected.
  ///
  /// In en, this message translates to:
  /// **'Successfully connected to Laravel API!'**
  String get apiConnected;

  /// No description provided for @apiConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to connect to API server. Check URL and server status.'**
  String get apiConnectionFailed;

  /// No description provided for @invalidUrl.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid URL'**
  String get invalidUrl;

  /// No description provided for @superAdminRole.
  ///
  /// In en, this message translates to:
  /// **'Super Admin (HQ)'**
  String get superAdminRole;

  /// No description provided for @branchAdminRole.
  ///
  /// In en, this message translates to:
  /// **'Branch Admin'**
  String get branchAdminRole;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get viewAll;

  /// No description provided for @pendingPurchases.
  ///
  /// In en, this message translates to:
  /// **'Pending Purchases'**
  String get pendingPurchases;

  /// No description provided for @estStockValuation.
  ///
  /// In en, this message translates to:
  /// **'Est. Stock Valuation'**
  String get estStockValuation;

  /// No description provided for @grossMarginCogs.
  ///
  /// In en, this message translates to:
  /// **'Gross Margin (COGS)'**
  String get grossMarginCogs;

  /// No description provided for @inventoryValuation.
  ///
  /// In en, this message translates to:
  /// **'Inventory Valuation'**
  String get inventoryValuation;

  /// No description provided for @totalCostValue.
  ///
  /// In en, this message translates to:
  /// **'Total Cost Value'**
  String get totalCostValue;

  /// No description provided for @totalRetailValue.
  ///
  /// In en, this message translates to:
  /// **'Total Retail Value'**
  String get totalRetailValue;

  /// No description provided for @noRecentSales.
  ///
  /// In en, this message translates to:
  /// **'No recent sales recorded.'**
  String get noRecentSales;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// No description provided for @hqSettings.
  ///
  /// In en, this message translates to:
  /// **'HQ Settings'**
  String get hqSettings;

  /// No description provided for @backups.
  ///
  /// In en, this message translates to:
  /// **'Backups'**
  String get backups;

  /// No description provided for @ordersCount.
  ///
  /// In en, this message translates to:
  /// **'{count} Orders'**
  String ordersCount(int count);

  /// No description provided for @txCount.
  ///
  /// In en, this message translates to:
  /// **'{count} tx'**
  String txCount(int count);

  /// No description provided for @itemsLeft.
  ///
  /// In en, this message translates to:
  /// **'{count} left'**
  String itemsLeft(int count);

  /// No description provided for @requestUnlistedDrug.
  ///
  /// In en, this message translates to:
  /// **'Add / Request Unlisted Drug'**
  String get requestUnlistedDrug;

  /// No description provided for @customDrugName.
  ///
  /// In en, this message translates to:
  /// **'Drug / Product Name'**
  String get customDrugName;

  /// No description provided for @customDrugCategory.
  ///
  /// In en, this message translates to:
  /// **'Category (Optional)'**
  String get customDrugCategory;

  /// No description provided for @unassignedSupplierNotice.
  ///
  /// In en, this message translates to:
  /// **'Supplier and prices can be assigned later by admin.'**
  String get unassignedSupplierNotice;

  /// No description provided for @purchaseApproval.
  ///
  /// In en, this message translates to:
  /// **'Purchase Approval'**
  String get purchaseApproval;

  /// No description provided for @approveAndRestock.
  ///
  /// In en, this message translates to:
  /// **'Approve & Restock'**
  String get approveAndRestock;

  /// No description provided for @pendingApproval.
  ///
  /// In en, this message translates to:
  /// **'Pending Approval'**
  String get pendingApproval;

  /// No description provided for @approved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get approved;

  /// No description provided for @branchStaffManagement.
  ///
  /// In en, this message translates to:
  /// **'Branch Staff Management'**
  String get branchStaffManagement;

  /// No description provided for @addStaffMember.
  ///
  /// In en, this message translates to:
  /// **'Add Staff Member'**
  String get addStaffMember;

  /// No description provided for @managedBySuperAdmin.
  ///
  /// In en, this message translates to:
  /// **'Managed by Super Admin'**
  String get managedBySuperAdmin;

  /// No description provided for @outOfStockRequest.
  ///
  /// In en, this message translates to:
  /// **'Out of Stock Drug Request'**
  String get outOfStockRequest;

  /// No description provided for @requestDrugForCustomer.
  ///
  /// In en, this message translates to:
  /// **'Request Drug for Customer'**
  String get requestDrugForCustomer;

  /// No description provided for @requestedDrugName.
  ///
  /// In en, this message translates to:
  /// **'Requested Drug Name'**
  String get requestedDrugName;

  /// No description provided for @customerWishlistSaved.
  ///
  /// In en, this message translates to:
  /// **'Customer drug request saved'**
  String get customerWishlistSaved;

  /// No description provided for @requestNewStock.
  ///
  /// In en, this message translates to:
  /// **'Request Restock'**
  String get requestNewStock;

  /// No description provided for @restockAllLowStock.
  ///
  /// In en, this message translates to:
  /// **'Restock All Low Stock'**
  String get restockAllLowStock;

  /// No description provided for @lowStockFilter.
  ///
  /// In en, this message translates to:
  /// **'Low Stock'**
  String get lowStockFilter;

  /// No description provided for @allProductsFilter.
  ///
  /// In en, this message translates to:
  /// **'All Products'**
  String get allProductsFilter;

  /// No description provided for @expired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get expired;

  /// No description provided for @stockAdjusted.
  ///
  /// In en, this message translates to:
  /// **'Stock adjusted successfully'**
  String get stockAdjusted;

  /// No description provided for @cogs.
  ///
  /// In en, this message translates to:
  /// **'Cost of Goods (COGS)'**
  String get cogs;

  /// No description provided for @averageOrderValue.
  ///
  /// In en, this message translates to:
  /// **'Avg Order Value'**
  String get averageOrderValue;

  /// No description provided for @grossRevenue.
  ///
  /// In en, this message translates to:
  /// **'Gross Revenue'**
  String get grossRevenue;

  /// No description provided for @totalDiscounts.
  ///
  /// In en, this message translates to:
  /// **'Discounts'**
  String get totalDiscounts;

  /// No description provided for @totalTax.
  ///
  /// In en, this message translates to:
  /// **'Tax'**
  String get totalTax;

  /// No description provided for @totalPurchasesCount.
  ///
  /// In en, this message translates to:
  /// **'Purchase Orders'**
  String get totalPurchasesCount;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @last7Days.
  ///
  /// In en, this message translates to:
  /// **'Last 7 Days'**
  String get last7Days;

  /// No description provided for @last30Days.
  ///
  /// In en, this message translates to:
  /// **'Last 30 Days'**
  String get last30Days;

  /// No description provided for @thisMonth.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get thisMonth;

  /// No description provided for @customRange.
  ///
  /// In en, this message translates to:
  /// **'Custom Range'**
  String get customRange;

  /// No description provided for @paymentBreakdownSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Revenue share and volume across payment channels'**
  String get paymentBreakdownSubtitle;

  /// No description provided for @topProductsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Highest grossing products in this period'**
  String get topProductsSubtitle;

  /// No description provided for @margin.
  ///
  /// In en, this message translates to:
  /// **'Margin'**
  String get margin;

  /// No description provided for @salesTrends.
  ///
  /// In en, this message translates to:
  /// **'Daily Sales Trends'**
  String get salesTrends;

  /// No description provided for @salesTrendsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Daily transaction volume and revenue curve'**
  String get salesTrendsSubtitle;

  /// No description provided for @stockValuationTitle.
  ///
  /// In en, this message translates to:
  /// **'Stock Inventory Valuation'**
  String get stockValuationTitle;

  /// No description provided for @stockCostBasis.
  ///
  /// In en, this message translates to:
  /// **'Wholesale Cost Basis'**
  String get stockCostBasis;

  /// No description provided for @potentialStockProfit.
  ///
  /// In en, this message translates to:
  /// **'Unrealized Stock Profit'**
  String get potentialStockProfit;

  /// No description provided for @annualLedger.
  ///
  /// In en, this message translates to:
  /// **'12-Month Financial Ledger'**
  String get annualLedger;

  /// No description provided for @annualLedgerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Historical performance and monthly margins'**
  String get annualLedgerSubtitle;

  /// No description provided for @printReport.
  ///
  /// In en, this message translates to:
  /// **'Print Report'**
  String get printReport;

  /// No description provided for @printPreview.
  ///
  /// In en, this message translates to:
  /// **'Report Preview'**
  String get printPreview;

  /// No description provided for @unitsSold.
  ///
  /// In en, this message translates to:
  /// **'Units Sold'**
  String get unitsSold;

  /// No description provided for @rankMedal.
  ///
  /// In en, this message translates to:
  /// **'Rank'**
  String get rankMedal;

  /// No description provided for @financialLedgerSummary.
  ///
  /// In en, this message translates to:
  /// **'Financial Summary'**
  String get financialLedgerSummary;

  /// No description provided for @invoicesCount.
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get invoicesCount;

  /// No description provided for @potentialMargin.
  ///
  /// In en, this message translates to:
  /// **'Potential Margin'**
  String get potentialMargin;

  /// No description provided for @staffFeedback.
  ///
  /// In en, this message translates to:
  /// **'Staff Restock Feedback'**
  String get staffFeedback;

  /// No description provided for @sendRestockFeedback.
  ///
  /// In en, this message translates to:
  /// **'Restock Request / Feedback'**
  String get sendRestockFeedback;

  /// No description provided for @feedbackSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Restock feedback submitted to branch admin'**
  String get feedbackSubmitted;

  /// No description provided for @branchRestockRequests.
  ///
  /// In en, this message translates to:
  /// **'Staff Restock Recommendations'**
  String get branchRestockRequests;

  /// No description provided for @urgencyHighDemand.
  ///
  /// In en, this message translates to:
  /// **'High Demand'**
  String get urgencyHighDemand;

  /// No description provided for @urgencyLowStock.
  ///
  /// In en, this message translates to:
  /// **'Low Stock / Out of Stock'**
  String get urgencyLowStock;

  /// No description provided for @urgencyNormal.
  ///
  /// In en, this message translates to:
  /// **'Regular Restock'**
  String get urgencyNormal;

  /// No description provided for @suggestedQty.
  ///
  /// In en, this message translates to:
  /// **'Suggested Quantity'**
  String get suggestedQty;

  /// No description provided for @staffNotes.
  ///
  /// In en, this message translates to:
  /// **'Staff Notes (optional)'**
  String get staffNotes;

  /// No description provided for @createPurchaseOrderForDrug.
  ///
  /// In en, this message translates to:
  /// **'Create Purchase Order'**
  String get createPurchaseOrderForDrug;

  /// No description provided for @markOrdered.
  ///
  /// In en, this message translates to:
  /// **'Mark Ordered'**
  String get markOrdered;

  /// No description provided for @dismissFeedback.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismissFeedback;

  /// No description provided for @noStaffFeedback.
  ///
  /// In en, this message translates to:
  /// **'No pending staff restock recommendations for this branch'**
  String get noStaffFeedback;

  /// No description provided for @cashierFeedbackSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Frontline cashier insights and restock requests'**
  String get cashierFeedbackSubtitle;

  /// No description provided for @reportedBy.
  ///
  /// In en, this message translates to:
  /// **'Reported by {name}'**
  String reportedBy(String name);

  /// No description provided for @offlineModeBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Operating in Offline Mode — Local Storage Active'**
  String get offlineModeBannerTitle;

  /// No description provided for @offlineModeBannerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'All changes are saved locally to SQLite.'**
  String get offlineModeBannerSubtitle;

  /// No description provided for @offlinePendingTransactions.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 transaction queued for sync.} other{{count} transactions queued for sync.}}'**
  String offlinePendingTransactions(num count);

  /// No description provided for @syncFailedBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync Failed — Retries When Connection Is Stable'**
  String get syncFailedBannerTitle;

  /// No description provided for @networkRestoredBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Network Restored — Synchronizing with Server...'**
  String get networkRestoredBannerTitle;

  /// No description provided for @pendingSyncBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Pending Local Changes Ready to Sync'**
  String get pendingSyncBannerTitle;

  /// No description provided for @reconcilingRecordsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reconciling pending records and updating stock...'**
  String get reconcilingRecordsSubtitle;

  /// No description provided for @pendingServerReconciliation.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 offline transaction pending server reconciliation.} other{{count} offline transactions pending server reconciliation.}}'**
  String pendingServerReconciliation(num count);

  /// No description provided for @checkConnection.
  ///
  /// In en, this message translates to:
  /// **'Check Connection'**
  String get checkConnection;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync Now'**
  String get syncNow;

  /// No description provided for @supervisorAuthorization.
  ///
  /// In en, this message translates to:
  /// **'Supervisor Authorization'**
  String get supervisorAuthorization;

  /// No description provided for @supervisorUsernameOptional.
  ///
  /// In en, this message translates to:
  /// **'Supervisor Username (optional)'**
  String get supervisorUsernameOptional;

  /// No description provided for @supervisorPasswordPin.
  ///
  /// In en, this message translates to:
  /// **'Supervisor Password / PIN *'**
  String get supervisorPasswordPin;

  /// No description provided for @authorize.
  ///
  /// In en, this message translates to:
  /// **'Authorize'**
  String get authorize;

  /// No description provided for @invalidSupervisorPassword.
  ///
  /// In en, this message translates to:
  /// **'Invalid local supervisor password or PIN.'**
  String get invalidSupervisorPassword;

  /// No description provided for @checkForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for Updates'**
  String get checkForUpdates;

  /// No description provided for @checkingForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Checking for updates...'**
  String get checkingForUpdates;

  /// No description provided for @upToDate.
  ///
  /// In en, this message translates to:
  /// **'MePharma is up to date'**
  String get upToDate;

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Update Available'**
  String get updateAvailable;

  /// No description provided for @paymentBankTransfer.
  ///
  /// In en, this message translates to:
  /// **'Bank transfer'**
  String get paymentBankTransfer;

  /// No description provided for @transactionReference.
  ///
  /// In en, this message translates to:
  /// **'Transaction reference'**
  String get transactionReference;

  /// No description provided for @transactionRefHint.
  ///
  /// In en, this message translates to:
  /// **'Enter bank transfer reference number'**
  String get transactionRefHint;

  /// No description provided for @transactionRefRequired.
  ///
  /// In en, this message translates to:
  /// **'Transaction reference is required for bank transfer'**
  String get transactionRefRequired;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @refreshing.
  ///
  /// In en, this message translates to:
  /// **'Refreshing...'**
  String get refreshing;

  /// No description provided for @localOfflineTransactions.
  ///
  /// In en, this message translates to:
  /// **'Local Offline Transactions ({count})'**
  String localOfflineTransactions(int count);

  /// No description provided for @serverSyncedTransactions.
  ///
  /// In en, this message translates to:
  /// **'Server Synced Transactions ({count})'**
  String serverSyncedTransactions(int count);

  /// No description provided for @localSavedTransactions.
  ///
  /// In en, this message translates to:
  /// **'Local Sales Ledger ({count})'**
  String localSavedTransactions(int count);

  /// No description provided for @offlineQueueNotice.
  ///
  /// In en, this message translates to:
  /// **'These transactions were saved locally while offline and will sync automatically when online.'**
  String get offlineQueueNotice;

  /// No description provided for @syncingTransactions.
  ///
  /// In en, this message translates to:
  /// **'Synchronizing local transactions with server...'**
  String get syncingTransactions;

  /// No description provided for @superAdminShort.
  ///
  /// In en, this message translates to:
  /// **'Super Admin'**
  String get superAdminShort;

  /// No description provided for @branchAdminShort.
  ///
  /// In en, this message translates to:
  /// **'Branch Admin'**
  String get branchAdminShort;

  /// No description provided for @staffShort.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get staffShort;

  /// No description provided for @localModeActive.
  ///
  /// In en, this message translates to:
  /// **'Local Mode'**
  String get localModeActive;

  /// No description provided for @purchaseApprovedNotice.
  ///
  /// In en, this message translates to:
  /// **'Purchase request {invoice} has been approved and inventory is updated.'**
  String purchaseApprovedNotice(String invoice);

  /// No description provided for @printedOn.
  ///
  /// In en, this message translates to:
  /// **'Printed on {date}'**
  String printedOn(String date);

  /// No description provided for @stockOut.
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get stockOut;

  /// No description provided for @confirmApprovePurchase.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to approve this purchase order and add its inventory to branch stock?'**
  String get confirmApprovePurchase;

  /// No description provided for @supervisorApprovePurchaseReason.
  ///
  /// In en, this message translates to:
  /// **'Approving purchase orders and updating stock requires Branch Administrator or Supervisor authorization.'**
  String get supervisorApprovePurchaseReason;

  /// No description provided for @supervisorReturnReason.
  ///
  /// In en, this message translates to:
  /// **'Processing refunds and returns requires supervisor override.'**
  String get supervisorReturnReason;

  /// No description provided for @terminalQuotaTitle.
  ///
  /// In en, this message translates to:
  /// **'Terminal Seat Limit Reached'**
  String get terminalQuotaTitle;

  /// No description provided for @terminalQuotaInfo.
  ///
  /// In en, this message translates to:
  /// **'To add more cash counters or desktop terminals, please request a license seat upgrade on the Provider Platform.'**
  String get terminalQuotaInfo;

  /// No description provided for @understood.
  ///
  /// In en, this message translates to:
  /// **'Understood'**
  String get understood;

  /// No description provided for @supervisorAuthTitle.
  ///
  /// In en, this message translates to:
  /// **'Supervisor Authorization'**
  String get supervisorAuthTitle;

  /// No description provided for @supervisorPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Supervisor Password / PIN *'**
  String get supervisorPasswordRequired;

  /// No description provided for @requestOutOfStockDrug.
  ///
  /// In en, this message translates to:
  /// **'Request Out-of-Stock Drug'**
  String get requestOutOfStockDrug;

  /// No description provided for @diagnosticsCopied.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics copied to clipboard'**
  String get diagnosticsCopied;

  /// No description provided for @copyErrorDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Copy Error Diagnostics'**
  String get copyErrorDiagnostics;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
