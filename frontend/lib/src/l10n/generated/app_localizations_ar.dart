// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'نظام إدارة الصيدلية';

  @override
  String get signIn => 'تسجيل الدخول';

  @override
  String get signingIn => 'جارٍ تسجيل الدخول...';

  @override
  String get username => 'اسم المستخدم';

  @override
  String get password => 'كلمة المرور';

  @override
  String get invalidCredentials => 'اسم المستخدم أو كلمة المرور غير صحيحة';

  @override
  String get errorLogin => 'حدث خطأ ما. حاول مرة أخرى.';

  @override
  String get language => 'اللغة';

  @override
  String get english => 'الإنجليزية';

  @override
  String get arabic => 'العربية';

  @override
  String get dashboard => 'الرئيسية';

  @override
  String get pos => 'نقطة البيع';

  @override
  String get salesHistory => 'سجل المبيعات';

  @override
  String get products => 'المنتجات';

  @override
  String get categories => 'الفئات';

  @override
  String get suppliers => 'الموردون';

  @override
  String get purchases => 'المشتريات';

  @override
  String get users => 'المستخدمون';

  @override
  String get reports => 'التقارير';

  @override
  String get settings => 'الإعدادات';

  @override
  String get backup => 'النسخ الاحتياطي';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get comingSoon => 'قريباً';

  @override
  String welcomeBack(String name) {
    return 'مرحباً بعودتك، $name';
  }

  @override
  String welcomeBackMessage(String role) {
    return 'أنت مسجل الدخول بصفة $role';
  }

  @override
  String get roleAdmin => 'مدير';

  @override
  String get roleStaff => 'موظف';

  @override
  String get quickSale => 'بيع جديد';

  @override
  String get todaySales => 'مبيعات اليوم';

  @override
  String get lowStockItems => 'عناصر منخفضة المخزون';

  @override
  String get actions => 'إجراءات';

  @override
  String get save => 'حفظ';

  @override
  String get saving => 'جارٍ الحفظ...';

  @override
  String get saved => 'تم الحفظ';

  @override
  String get cancel => 'إلغاء';

  @override
  String get delete => 'حذف';

  @override
  String get edit => 'تعديل';

  @override
  String get searchProducts => 'ابحث بالاسم أو رمز الصنف أو الباركود';

  @override
  String get fieldRequired => 'هذا الحقل مطلوب';

  @override
  String get invalidNumber => 'رقم غير صالح';

  @override
  String alreadyInUse(String field) {
    return '$field مستخدم بالفعل';
  }

  @override
  String get errorOccurred => 'حدث خطأ ما. حاول مرة أخرى.';

  @override
  String get sku => 'رمز الصنف';

  @override
  String get barcode => 'الباركود';

  @override
  String get productName => 'اسم المنتج';

  @override
  String get category => 'الفئة';

  @override
  String get supplier => 'المورد';

  @override
  String get costPrice => 'سعر التكلفة';

  @override
  String get sellingPrice => 'سعر البيع';

  @override
  String get stock => 'المخزون';

  @override
  String get lowStockThreshold => 'تنبيه عند انخفاض المخزون';

  @override
  String get expiryDate => 'تاريخ الانتهاء';

  @override
  String get description => 'الوصف';

  @override
  String get noCategory => 'بدون فئة';

  @override
  String get noSupplier => 'بدون مورد';

  @override
  String get noProducts => 'لا توجد منتجات';

  @override
  String get addProduct => 'إضافة منتج';

  @override
  String get editProduct => 'تعديل المنتج';

  @override
  String get deleteProduct => 'حذف المنتج';

  @override
  String get productAdded => 'تمت إضافة المنتج';

  @override
  String get productSaved => 'تم حفظ المنتج';

  @override
  String get productDeleted => 'تم حذف المنتج';

  @override
  String confirmDeleteProduct(String name) {
    return 'حذف $name؟';
  }

  @override
  String get confirmDeleteProductMessage =>
      'سيؤدي هذا إلى إزالة المنتج من المخزون. لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get adjustStock => 'تعديل المخزون';

  @override
  String get stockAdjustment => 'تعديل كمية المخزون';

  @override
  String get adjustmentQuantity => 'كمية التعديل (+/-)';

  @override
  String get adjustmentReason => 'سبب التعديل (اختياري)';

  @override
  String get adjustmentReasonHint => 'مثال: جرد دوري، بضاعة تالفة، تصحيح إدخال';

  @override
  String get positiveAddsNegativeRemoves =>
      'العدد الموجب يضيف للمخزون، والسالب يخصم منه.';

  @override
  String get currentStock => 'المخزون الحالي';

  @override
  String get addCategory => 'إضافة فئة';

  @override
  String get editCategory => 'تعديل الفئة';

  @override
  String get categoryName => 'اسم الفئة';

  @override
  String get deleteCategory => 'حذف الفئة';

  @override
  String get categoryAdded => 'تمت إضافة الفئة';

  @override
  String get categorySaved => 'تم حفظ الفئة';

  @override
  String confirmDeleteCategory(String name) {
    return 'حذف الفئة $name؟';
  }

  @override
  String get noCategories => 'لا توجد فئات بعد';

  @override
  String get addSupplier => 'إضافة مورد';

  @override
  String get editSupplier => 'تعديل المورد';

  @override
  String get supplierName => 'اسم المورد';

  @override
  String get contactPerson => 'الشخص المسؤول';

  @override
  String get phone => 'الهاتف';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get address => 'العنوان';

  @override
  String get deleteSupplier => 'حذف المورد';

  @override
  String get supplierAdded => 'تمت إضافة المورد';

  @override
  String get supplierSaved => 'تم حفظ المورد';

  @override
  String confirmDeleteSupplier(String name) {
    return 'حذف المورد $name؟';
  }

  @override
  String get noSuppliers => 'لا يوجد موردون بعد';

  @override
  String get storeSettings => 'إعدادات المتجر';

  @override
  String get storeName => 'اسم المتجر';

  @override
  String get storeAddress => 'عنوان المتجر';

  @override
  String get storePhone => 'هاتف المتجر';

  @override
  String get storeTaxId => 'الرقم الضريبي';

  @override
  String get taxRate => 'نسبة الضريبة (%)';

  @override
  String get currencySymbol => 'رمز العملة';

  @override
  String get scanBarcode => 'امسح الباركود، الصنف، الاسم، أو الاسم العلمي...';

  @override
  String get productNotFound => 'المنتج غير موجود';

  @override
  String outOfStock(String name) {
    return 'نفد المخزون: $name';
  }

  @override
  String get emptyCart => 'السلة فارغة';

  @override
  String get insufficientStock => 'المخزون غير كافٍ';

  @override
  String get insufficientReceived => 'المبلغ المستلم أقل من الإجمالي';

  @override
  String get cart => 'السلة';

  @override
  String get clearCart => 'مسح السلة';

  @override
  String get confirmClearCartMessage => 'ستتم إزالة جميع الأصناف من السلة.';

  @override
  String get newSale => 'بيع جديد';

  @override
  String get holdSale => 'تعليق البيع';

  @override
  String get resumeHold => 'استئناف بيع معلق';

  @override
  String get saleHeld => 'تم تعليق البيع';

  @override
  String saleCompleted(String invoice) {
    return 'اكتمل البيع: $invoice';
  }

  @override
  String get noHolds => 'لا توجد مبيعات معلقة';

  @override
  String get deleteHold => 'حذف المعلق';

  @override
  String confirmDeleteHold(String number) {
    return 'حذف البيع المعلق $number؟';
  }

  @override
  String holdPartiallyRestored(String missing) {
    return 'بعض المنتجات لم تعد متوفرة وتم تخطيها: $missing';
  }

  @override
  String get subtotal => 'المجموع الفرعي';

  @override
  String get discount => 'الخصم';

  @override
  String get discountNone => 'بدون خصم';

  @override
  String get discountPercentage => 'نسبة مئوية';

  @override
  String get discountFixed => 'مبلغ ثابت';

  @override
  String get tax => 'الضريبة';

  @override
  String get total => 'الإجمالي';

  @override
  String get pay => 'الدفع';

  @override
  String get payment => 'الدفع';

  @override
  String get paymentCash => 'نقداً';

  @override
  String get paymentCard => 'بطاقة';

  @override
  String get paymentMobileMoney => 'محفظة إلكترونية';

  @override
  String get amountReceived => 'المبلغ المستلم';

  @override
  String get changeDue => 'الباقي';

  @override
  String get confirmPayment => 'تأكيد الدفع';

  @override
  String get receiptInvoice => 'فاتورة:';

  @override
  String get receiptCashier => 'أمين الصندوق:';

  @override
  String get receiptCustomer => 'العميل:';

  @override
  String get receiptOnAccount => 'على الحساب';

  @override
  String get receiptThanks => 'شكراً لشرائك!';

  @override
  String get printFailed => 'فشلت الطباعة';

  @override
  String get printFailedMessage =>
      'تعذرت طباعة الإيصال. تحقق من إعدادات الطابعة وحاول مرة أخرى، أو اطبعه لاحقاً من سجل المبيعات.';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get dismiss => 'إغلاق';

  @override
  String get hintScan => 'F1 مسح';

  @override
  String get hintPay => 'F2 دفع';

  @override
  String get hintHold => 'F4 تعليق';

  @override
  String get hintClear => 'Esc مسح';

  @override
  String get printerSettings => 'إعدادات الطابعة';

  @override
  String get printerType => 'نوع الطابعة';

  @override
  String get printerNone => 'بدون';

  @override
  String get printerWindows => 'طابعة ويندوز (USB / تعريف)';

  @override
  String get printerNetwork => 'طابعة شبكة (TCP / 9100)';

  @override
  String get printerAddress => 'اسم الطابعة أو العنوان';

  @override
  String get printerAddressHintWindows => 'اسم الطابعة المثبتة';

  @override
  String get printerAddressHintNetwork => 'مثال: 192.168.1.50';

  @override
  String get printerPort => 'المنفذ';

  @override
  String get paperSize => 'حجم الورق';

  @override
  String get testPrint => 'طباعة تجريبية';

  @override
  String get testReceiptSent => 'تم إرسال إيصال تجريبي إلى الطابعة';

  @override
  String get from => 'من';

  @override
  String get to => 'إلى';

  @override
  String get searchInvoice => 'ابحث برقم الفاتورة أو اسم العميل';

  @override
  String get dateRange => 'الفترة الزمنية';

  @override
  String get paymentAll => 'كل طرق الدفع';

  @override
  String get status => 'الحالة';

  @override
  String get statusAll => 'كل الحالات';

  @override
  String get resetFilters => 'إعادة تعيين الفلاتر';

  @override
  String get noSales => 'لا توجد مبيعات مطابقة للفلاتر الحالية';

  @override
  String get saleStatusCompleted => 'مكتملة';

  @override
  String get saleStatusReturned => 'مُرجع';

  @override
  String get saleStatusVoided => 'ملغاة';

  @override
  String get saleDetail => 'تفاصيل البيع';

  @override
  String get printReceipt => 'طباعة الإيصال';

  @override
  String get returnItems => 'إرجاع أصناف';

  @override
  String get close => 'إغلاق';

  @override
  String get cashier => 'الكاشير';

  @override
  String get customer => 'العميل';

  @override
  String get date => 'التاريخ';

  @override
  String get returns => 'المرتجعات';

  @override
  String get returnProcessed => 'تمت معالجة الإرجاع';

  @override
  String get nothingToReturn => 'اختر صنفاً واحداً على الأقل للإرجاع';

  @override
  String get processReturn => 'معالجة الإرجاع';

  @override
  String get returnReason => 'السبب (اختياري)';

  @override
  String get returnReasonHint => 'مثال: صنف خاطئ، تالف';

  @override
  String get sold => 'المباع';

  @override
  String get alreadyReturned => 'مُرجع مسبقاً';

  @override
  String get newPurchase => 'شراء جديد';

  @override
  String get purchaseSaved => 'تم حفظ عملية الشراء';

  @override
  String get noPurchases => 'لا توجد مشتريات بعد';

  @override
  String get purchaseDetail => 'تفاصيل الشراء';

  @override
  String get selectSupplier => 'اختر المورد';

  @override
  String get noPurchaseLines => 'لا توجد بنود شراء بعد';

  @override
  String get purchaseDate => 'تاريخ الشراء';

  @override
  String get purchaseTotal => 'إجمالي الشراء';

  @override
  String get addLine => 'إضافة بند';

  @override
  String get decrease => 'تقليل';

  @override
  String get increase => 'زيادة';

  @override
  String get remove => 'إزالة';

  @override
  String get selectProduct => 'اختر المنتج';

  @override
  String get searchProduct => 'ابحث عن المنتجات';

  @override
  String get noResults => 'لا توجد نتائج';

  @override
  String get quantity => 'الكمية';

  @override
  String get unitCost => 'تكلفة الوحدة';

  @override
  String get add => 'إضافة';

  @override
  String get invalidLineValues => 'أدخل كمية وتكلفة وحدة صحيحتين';

  @override
  String get productAlreadyAdded => 'المنتج موجود بالفعل في بنود الشراء';

  @override
  String get addUser => 'إضافة مستخدم';

  @override
  String get editUser => 'تعديل المستخدم';

  @override
  String get userAdded => 'تمت إضافة المستخدم';

  @override
  String get userSaved => 'تم حفظ المستخدم';

  @override
  String get role => 'الدور';

  @override
  String get active => 'نشط';

  @override
  String get inactive => 'غير نشط';

  @override
  String get cannotDeactivateSelf => 'لا يمكنك تعطيل حسابك الخاص';

  @override
  String get needOneActiveAdmin => 'يجب وجود مدير نشط واحد على الأقل';

  @override
  String get newPassword => 'كلمة المرور الجديدة';

  @override
  String get leaveEmptyToKeep => 'اتركه فارغاً للإبقاء على كلمة المرور الحالية';

  @override
  String get salesCount => 'المبيعات';

  @override
  String get revenue => 'الإيرادات';

  @override
  String get netRevenue => 'صافي الإيرادات';

  @override
  String get refunds => 'المرتجعات';

  @override
  String get purchasesCost => 'تكلفة المشتريات';

  @override
  String get estimatedProfit => 'الربح التقديري';

  @override
  String get totalSales => 'إجمالي المبيعات';

  @override
  String get salesByPayment => 'المبيعات حسب طريقة الدفع';

  @override
  String get topProducts => 'أفضل المنتجات';

  @override
  String get exportCsv => 'تصدير CSV';

  @override
  String exportedTo(String path) {
    return 'تم تصدير التقرير إلى $path';
  }

  @override
  String get noData => 'لا توجد بيانات لهذه الفترة';

  @override
  String get createBackup => 'إنشاء نسخة احتياطية';

  @override
  String backupCreated(String path) {
    return 'تم إنشاء النسخة الاحتياطية: $path';
  }

  @override
  String get backupFailed => 'فشل إنشاء النسخة الاحتياطية';

  @override
  String get restoreBackup => 'استعادة';

  @override
  String confirmRestore(String name) {
    return 'استعادة النسخة $name؟ سيؤدي هذا إلى استبدال جميع البيانات الحالية بالنسخة الاحتياطية.';
  }

  @override
  String get restoreComplete => 'تمت الاستعادة. يرجى تسجيل الدخول مرة أخرى.';

  @override
  String get restoreFailed => 'فشلت الاستعادة';

  @override
  String get backupsLocation =>
      'تُخزَّن النسخ الاحتياطية في مجلد المستندات لديك (MePharmaBackups).';

  @override
  String get noBackups => 'لا توجد نسخ احتياطية بعد';

  @override
  String confirmDeleteBackup(String fileName) {
    return 'حذف النسخة الاحتياطية $fileName؟ لا يمكن التراجع عن هذا الإجراء.';
  }

  @override
  String get backupDeleted => 'تم حذف النسخة الاحتياطية';

  @override
  String get customers => 'العملاء';

  @override
  String get expiry => 'الانتهاء';

  @override
  String get paymentCredit => 'على الحساب';

  @override
  String get creditChargedToAccount =>
      'سيُضاف هذا المبلغ إلى رصيد حساب العميل.';

  @override
  String get creditNeedsCustomer => 'اختر عميلاً لتسجيل هذا البيع على حسابه.';

  @override
  String get creditLimitExceeded =>
      'يتجاوز هذا البيع سقف الائتمان الخاص بالعميل.';

  @override
  String get outstandingBalance => 'الرصيد المستحق';

  @override
  String get walkInCustomer => 'عميل عابر';

  @override
  String get productExpired => 'انتهت صلاحية هذا المنتج ولا يمكن بيعه.';

  @override
  String get addCustomer => 'إضافة عميل';

  @override
  String get editCustomer => 'تعديل العميل';

  @override
  String get customerName => 'اسم العميل';

  @override
  String get creditLimit => 'سقف الائتمان';

  @override
  String get notes => 'ملاحظات';

  @override
  String get customerAdded => 'تمت إضافة العميل';

  @override
  String get customerSaved => 'تم حفظ العميل';

  @override
  String get recordPayment => 'تسجيل دفعة';

  @override
  String recordPaymentFor(String name) {
    return 'تسجيل دفعة لـ $name';
  }

  @override
  String get amount => 'المبلغ';

  @override
  String get note => 'ملاحظة';

  @override
  String get paymentRecorded => 'تم تسجيل الدفعة';

  @override
  String get balance => 'الرصيد';

  @override
  String get paymentHistory => 'سجل الدفعات';

  @override
  String get noPayments => 'لا توجد دفعات مسجلة بعد';

  @override
  String confirmDeleteCustomer(String name) {
    return 'حذف العميل $name؟';
  }

  @override
  String get deleteCustomerHint =>
      'سيُحذف سجل دفعات العميل وستبقى مبيعاته بدون عميل. لا يمكن التراجع عن هذا الإجراء.';

  @override
  String customerHasOutstandingBalance(String amount) {
    return 'لدى هذا العميل رصيد مستحق قدره $amount.';
  }

  @override
  String get customerNameTaken => 'يوجد عميل بهذا الاسم بالفعل';

  @override
  String get creditLimitNegative => 'لا يمكن أن يكون سقف الائتمان سالباً';

  @override
  String get overLimit => 'تجاوز الحد';

  @override
  String get searchCustomers => 'ابحث عن العملاء';

  @override
  String get noCustomers => 'لا يوجد عملاء بعد';

  @override
  String get payments => 'الدفعات';

  @override
  String get todayLabel => 'اليوم';

  @override
  String get yesterdayLabel => 'أمس';

  @override
  String nextDays(int days) {
    return 'الـ $days أيام القادمة';
  }

  @override
  String get expiryHint =>
      'تُعلَّم المنتجات كمنتهية الصلاحية في تاريخ انتهائها.';

  @override
  String get noExpiringProducts => 'لا توجد منتجات تنتهي خلال الفترة المحددة';

  @override
  String get expiredProducts => 'منتهية الصلاحية';

  @override
  String get expiringSoon => 'تنتهي قريباً';

  @override
  String expiredOn(String date) {
    return 'انتهت في $date';
  }

  @override
  String daysUntilExpiry(int days) {
    return 'بعد $days يوم';
  }

  @override
  String get expiredLabel => 'منتهية';

  @override
  String get defaultLowStockThreshold => 'تنبيه المخزون المنخفض الافتراضي';

  @override
  String get defaultLowStockHint => 'يُستخدم عند إضافة منتجات جديدة';

  @override
  String get receiptFooter => 'تذييل الإيصال';

  @override
  String get receiptFooterHint => 'يظهر أسفل الإيصالات المطبوعة، مثل رسالة شكر';

  @override
  String get import => 'استيراد';

  @override
  String get export => 'تصدير';

  @override
  String exportComplete(String path) {
    return 'تم التصدير إلى $path';
  }

  @override
  String get noProductsImported => 'لا توجد منتجات في الملف المحدد';

  @override
  String importComplete(int created, int updated, int errors) {
    return 'تم الاستيراد: $created أُضيف، $updated حُدّث، $errors فشل';
  }

  @override
  String get monthlyComparison => 'مقارنة شهرية';

  @override
  String get month => 'الشهر';

  @override
  String get profitByCategory => 'الربح حسب الفئة';

  @override
  String get stockValuation => 'تقييم المخزون';

  @override
  String get stockValueAtCost => 'القيمة بالتكلفة';

  @override
  String get stockValueAtRetail => 'القيمة بسعر البيع';

  @override
  String get potentialProfit => 'الربح المتوقع';

  @override
  String get totalItems => 'منتجات في المخزون';

  @override
  String get brandName => 'الاسم التجاري';

  @override
  String get genericName => 'الاسم العلمي';

  @override
  String get dose => 'الجرعة / العيار';

  @override
  String get profitMargin => 'هامش الربح';

  @override
  String get supplierCompany => 'الشركة';

  @override
  String get supplierCompanyContact => 'رقم اتصال الشركة';

  @override
  String get serverSettings => 'إعدادات الخادم';

  @override
  String get apiUrl => 'رابط الخادم الرئيسي (API)';

  @override
  String get branchId => 'رقم الفرع';

  @override
  String get testConnection => 'فحص الاتصال';

  @override
  String get apiConnected => 'تم الاتصال بخادم Laravel بنجاح!';

  @override
  String get apiConnectionFailed =>
      'فشل الاتصال بالخادم. يرجى التحقق من الرابط وحالة الخادم.';

  @override
  String get invalidUrl => 'يرجى إدخال رابط صحيح';

  @override
  String get superAdminRole => 'مدير عام النظام (المركز الرئيسي)';

  @override
  String get branchAdminRole => 'مدير الفرع';

  @override
  String get viewAll => 'عرض الكل';

  @override
  String get pendingPurchases => 'طلبيات الشراء المعلقة';

  @override
  String get estStockValuation => 'التقييم التقديري للمخزون';

  @override
  String get grossMarginCogs => 'هامش الربح الإجمالي (COGS)';

  @override
  String get inventoryValuation => 'تقييم المخزون';

  @override
  String get totalCostValue => 'إجمالي قيمة التكلفة';

  @override
  String get totalRetailValue => 'إجمالي قيمة البيع';

  @override
  String get noRecentSales => 'لا توجد مبيعات مسجلة مؤخراً.';

  @override
  String get quickActions => 'إجراءات سريعة';

  @override
  String get hqSettings => 'إعدادات المركز الرئيسي';

  @override
  String get backups => 'النسخ الاحتياطية';

  @override
  String ordersCount(int count) {
    return '$count طلبيات';
  }

  @override
  String txCount(int count) {
    return '$count عملية';
  }

  @override
  String itemsLeft(int count) {
    return 'متبقي $count';
  }

  @override
  String get requestUnlistedDrug => 'إضافة / طلب دواء غير مدرج';

  @override
  String get customDrugName => 'اسم الدواء / المنتج';

  @override
  String get customDrugCategory => 'التصنيف (اختياري)';

  @override
  String get unassignedSupplierNotice =>
      'يمكن تحديد المورد والأسعار لاحقاً بواسطة المدير.';

  @override
  String get purchaseApproval => 'اعتماد الشراء';

  @override
  String get approveAndRestock => 'اعتماد وإضافة للمخزون';

  @override
  String get pendingApproval => 'بانتظار الاعتماد';

  @override
  String get approved => 'معتمد';

  @override
  String get branchStaffManagement => 'إدارة موظفي الفرع';

  @override
  String get addStaffMember => 'إضافة موظف';

  @override
  String get managedBySuperAdmin => 'تتم إدارته بواسطة المدير العام';

  @override
  String get outOfStockRequest => 'طلب دواء غير متوفر';

  @override
  String get requestDrugForCustomer => 'تسجيل طلب دواء لعميل';

  @override
  String get requestedDrugName => 'اسم الدواء المطلوب';

  @override
  String get customerWishlistSaved => 'تم حفظ طلب الدواء للعميل';

  @override
  String get requestNewStock => 'طلب توريد / مخزون جديد';

  @override
  String get restockAllLowStock => 'طلب توريد النواقص';

  @override
  String get lowStockFilter => 'النواقص والمخزون المنخفض';

  @override
  String get allProductsFilter => 'جميع الأدوية';

  @override
  String get expired => 'منتهي الصلاحية';

  @override
  String get stockAdjusted => 'تم تعديل المخزون بنجاح';

  @override
  String get cogs => 'تكلفة البضاعة (COGS)';

  @override
  String get averageOrderValue => 'متوسط قيمة الطلب';

  @override
  String get grossRevenue => 'إجمالي الإيرادات';

  @override
  String get totalDiscounts => 'الخصومات';

  @override
  String get totalTax => 'الضريبة';

  @override
  String get totalPurchasesCount => 'فواتير المشتريات';

  @override
  String get today => 'اليوم';

  @override
  String get last7Days => 'آخر 7 أيام';

  @override
  String get last30Days => 'آخر 30 يوماً';

  @override
  String get thisMonth => 'هذا الشهر';

  @override
  String get customRange => 'نطاق مخصص';

  @override
  String get paymentBreakdownSubtitle =>
      'نسبة وتوزيع الإيرادات حسب وسيلة الدفع';

  @override
  String get topProductsSubtitle =>
      'أعلى الأدوية تحقيقاً للإيرادات في هذه الفترة';

  @override
  String get margin => 'الهامش';

  @override
  String get salesTrends => 'مؤشرات المبيعات اليومية';

  @override
  String get salesTrendsSubtitle => 'حركة الإيرادات وعدد العمليات اليومية';

  @override
  String get stockValuationTitle => 'تقييم المخزون المالي';

  @override
  String get stockCostBasis => 'التكلفة الإجمالية بسعر الجملة';

  @override
  String get potentialStockProfit => 'الأرباح المتوقعة عند بيع المخزون';

  @override
  String get annualLedger => 'السجل المالي السنوي (12 شهراً)';

  @override
  String get annualLedgerSubtitle => 'الأداء المالي ونسب الأرباح الشهرية';

  @override
  String get printReport => 'طباعة التقرير';

  @override
  String get printPreview => 'معاينة التقرير';

  @override
  String get unitsSold => 'الوحدات المباعة';

  @override
  String get rankMedal => 'الترتيب';

  @override
  String get financialLedgerSummary => 'الملخص المالي';

  @override
  String get invoicesCount => 'الفواتير';

  @override
  String get potentialMargin => 'الهامش المتوقع';

  @override
  String get staffFeedback => 'ملاحظات وتوصيات الكاشير';

  @override
  String get sendRestockFeedback => 'طلب نواقص / توصية توريد';

  @override
  String get feedbackSubmitted => 'تم إرسال توصية التوريد لمدير الفرع بنجاح';

  @override
  String get branchRestockRequests => 'توصيات نواقص الأدوية من الكاشير';

  @override
  String get urgencyHighDemand => 'طلب متزايد / نفاد وشيك';

  @override
  String get urgencyLowStock => 'مخزون منخفض / نافد';

  @override
  String get urgencyNormal => 'إعادة طلب دورية';

  @override
  String get suggestedQty => 'الكمية المقترحة';

  @override
  String get staffNotes => 'ملاحظات الكاشير (اختياري)';

  @override
  String get createPurchaseOrderForDrug => 'إنشاء أمر شراء';

  @override
  String get markOrdered => 'تم الطلب';

  @override
  String get dismissFeedback => 'تجاهل';

  @override
  String get noStaffFeedback => 'لا توجد توصيات نواقص معلقة لهذا الفرع حالياً';

  @override
  String get cashierFeedbackSubtitle =>
      'رؤى وتوصيات الكاشير حول الأدوية الأكثر طلباً والنواقص';

  @override
  String reportedBy(String name) {
    return 'بواسطة: $name';
  }

  @override
  String get offlineModeBannerTitle =>
      'العمل في وضع عدم الاتصال — التخزين المحلي نشط';

  @override
  String get offlineModeBannerSubtitle =>
      'يتم حفظ جميع التغييرات محلياً في قاعدة البيانات.';

  @override
  String offlinePendingTransactions(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count معاملة في انتظار المزامنة.',
      many: '$count معاملة في انتظار المزامنة.',
      few: '$count معاملات في انتظار المزامنة.',
      two: 'معاملتان في انتظار المزامنة.',
      one: 'معاملة واحدة في انتظار المزامنة.',
    );
    return '$_temp0';
  }

  @override
  String get syncFailedBannerTitle =>
      'فشلت المزامنة — ستتم إعادة المحاولة فور استقرار الاتصال';

  @override
  String get networkRestoredBannerTitle =>
      'تمت استعادة الاتصال — جارٍ المزامنة مع الخادم...';

  @override
  String get pendingSyncBannerTitle => 'تغييرات محلية جاهزة للمزامنة';

  @override
  String get reconcilingRecordsSubtitle =>
      'جارٍ مطابقة السجلات المعلقة وتحديث المخزون...';

  @override
  String pendingServerReconciliation(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count معاملة بانتظار المطابقة مع الخادم.',
      many: '$count معاملة بانتظار المطابقة مع الخادم.',
      few: '$count معاملات بانتظار المطابقة مع الخادم.',
      two: 'معاملتان بانتظار المطابقة مع الخادم.',
      one: 'معاملة واحدة بانتظار المطابقة مع الخادم.',
    );
    return '$_temp0';
  }

  @override
  String get checkConnection => 'فحص الاتصال';

  @override
  String get syncNow => 'مزامنة الآن';

  @override
  String get supervisorAuthorization => 'صلاحية المشرف';

  @override
  String get supervisorUsernameOptional => 'اسم مستخدم المشرف (اختياري)';

  @override
  String get supervisorPasswordPin => 'رمز المشرف أو كلمة المرور *';

  @override
  String get authorize => 'تأكيد الصلاحية';

  @override
  String get invalidSupervisorPassword =>
      'رمز المشرف أو كلمة المرور غير صحيحة.';

  @override
  String get checkForUpdates => 'التحقق من التحديثات';

  @override
  String get checkingForUpdates => 'جارٍ التحقق من التحديثات...';

  @override
  String get upToDate => 'نظام MePharma محدّث إلى آخر إصدار';

  @override
  String get updateAvailable => 'يتوفر تحديث جديد';
}
