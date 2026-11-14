import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/backup_service.dart';
import '../core/services/thermal_printer_service.dart';
import '../core/services/device_identifier_service.dart';
import '../core/services/network_monitor.dart';
import '../core/services/sync_engine.dart';
import '../core/services/update_checker_service.dart';
import '../data/db/app_database.dart' hide Customer, CustomerPayment;
import '../data/db/enums.dart';
// SQLite Repositories
import '../data/repositories/sqlite_auth_repository.dart';
import '../data/repositories/sqlite_category_repository.dart';
import '../data/repositories/sqlite_customer_repository.dart';
import '../data/repositories/sqlite_product_repository.dart';
import '../data/repositories/sqlite_purchase_repository.dart';
import '../data/repositories/sqlite_report_repository.dart';
import '../data/repositories/sqlite_return_repository.dart';
import '../data/repositories/sqlite_sale_repository.dart';
import '../data/repositories/sqlite_sales_hold_repository.dart';
import '../data/repositories/sqlite_settings_repository.dart';
import '../data/repositories/sqlite_staff_feedback_repository.dart';
import '../data/repositories/sqlite_stock_adjustment_repository.dart';
import '../data/repositories/sqlite_supplier_repository.dart';
import '../data/repositories/sqlite_user_repository.dart';

// Offline-first Repositories
import '../data/repositories/offline_first_sale_repository.dart';
import '../data/repositories/offline_first_product_repository.dart';
import '../data/repositories/offline_first_customer_repository.dart';
import '../data/repositories/offline_first_report_repository.dart';
import '../data/repositories/offline_first_staff_feedback_repository.dart';
import '../domain/models/backup_record.dart';
import '../domain/models/app_category.dart';
import '../domain/models/app_product.dart';
import '../domain/models/app_purchase.dart';
import '../domain/models/app_sale.dart';
import '../domain/models/app_return.dart';
import '../domain/models/app_sales_hold.dart';
import '../domain/models/app_supplier.dart';
import '../domain/models/app_user.dart';
import '../domain/models/customer.dart';
import '../domain/models/report_depth.dart';
import '../domain/models/report_summary.dart';
import '../domain/models/store_settings.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/category_repository.dart';
import '../domain/repositories/customer_repository.dart';
import '../domain/repositories/product_repository.dart';
import '../domain/repositories/purchase_repository.dart';
import '../domain/repositories/report_repository.dart';
import '../domain/repositories/return_repository.dart';
import '../domain/repositories/sale_repository.dart';
import '../domain/repositories/sales_hold_repository.dart';
import '../domain/repositories/settings_repository.dart';
import '../domain/repositories/stock_adjustment_repository.dart';
import '../domain/repositories/supplier_repository.dart';
import '../domain/repositories/user_repository.dart';

// API imports
import '../domain/models/api_config.dart';
import '../core/services/api_client.dart';
import '../core/services/api_config_manager.dart';
import '../data/repositories/api/api_auth_repository.dart';
import '../data/repositories/api/api_category_repository.dart';
import '../data/repositories/api/api_product_repository.dart';
import '../data/repositories/api/api_customer_repository.dart';
import '../data/repositories/api/api_sale_repository.dart';
import '../data/repositories/api/api_purchase_repository.dart';
import '../data/repositories/api/api_report_repository.dart';
import '../data/repositories/api/api_return_repository.dart';
import '../data/repositories/api/api_sales_hold_repository.dart';
import '../data/repositories/api/api_settings_repository.dart';
import '../data/repositories/api/api_stock_adjustment_repository.dart';
import '../data/repositories/api/api_supplier_repository.dart';
import '../data/repositories/api/api_staff_feedback_repository.dart';
import '../domain/models/staff_product_feedback.dart';
import '../domain/repositories/staff_feedback_repository.dart';
import '../data/repositories/api/api_user_repository.dart';
import '../presentation/pos/pos_controller.dart';

final apiConfigManagerProvider = Provider<ApiConfigManager>((ref) {
  return ApiConfigManager();
});

class ApiConfigNotifier extends StateNotifier<ApiConfig> {
  ApiConfigNotifier(this._manager, [ApiConfig? initialConfig])
      : super(initialConfig ?? const ApiConfig(
          mode: DatabaseMode.local,
          baseUrl: 'http://localhost:8000/api',
          branchId: 1,
          isConfigured: true,
          isLicenseValid: true,
          pharmacyName: 'Local Pharmacy (Offline)',
          pharmacyAddress: 'Standalone SQLite Database',
          licensePlan: 'offline_standalone',
          validityDaysRemaining: 365,
        )) {
    load();
  }

  final ApiConfigManager _manager;

  Future<void> load() async {
    var loaded = await _manager.loadConfig();
    if (loaded.baseUrl.contains('.localhost')) {
      loaded = loaded.copyWith(
        baseUrl: loaded.baseUrl.replaceAll(RegExp(r'//[^/:]+\.localhost'), '//localhost'),
      );
      await _manager.saveConfig(loaded);
    }
    if (loaded.terminalHardwareId == null || loaded.terminalHardwareId!.isEmpty) {
      final hwId = await DeviceIdentifierService.getHardwareId();
      final termName = DeviceIdentifierService.getTerminalName();
      loaded = loaded.copyWith(
        terminalHardwareId: hwId,
        terminalName: termName,
      );
      await _manager.saveConfig(loaded);
    }
    state = loaded;

    // Background sync of license & store info if configured
    if (loaded.isConfigured &&
        loaded.mode == DatabaseMode.onlineApi &&
        loaded.licenseKey != null &&
        loaded.licenseKey!.isNotEmpty) {
      _syncLicenseInBackground(loaded);
    }
  }

  void _syncLicenseInBackground(ApiConfig config) async {
    try {
      await activateLicense(
        mode: config.mode,
        pharmacyDomain: config.pharmacyDomain,
        licenseKey: config.licenseKey,
        branchId: config.branchId,
      );
    } catch (_) {
      // Offline fallback: keep existing local config
    }
  }

  Future<({bool success, String? error, ApiConfig? config})> activateLicense({
    required DatabaseMode mode,
    String? pharmacyDomain,
    String? licenseKey,
    int? branchId,
  }) async {
    if (mode == DatabaseMode.local) {
      final updated = state.copyWith(
        mode: DatabaseMode.local,
        isConfigured: true,
        isLicenseValid: true,
        pharmacyName: 'Local Pharmacy (Offline)',
        pharmacyAddress: 'Standalone SQLite Database',
        currency: 'SDG',
        currencySymbol: 'ج.س',
        taxRate: 0.0,
        licensePlan: 'offline_standalone',
        validityDaysRemaining: 365,
      );
      state = updated;
      await _manager.saveConfig(updated);
      return (success: true, error: null, config: updated);
    }

    final trimmedKey = (licenseKey ?? '').trim();
    if (trimmedKey.isEmpty) {
      return (success: false, error: 'Please enter a cryptographic license key.', config: null);
    }

    var domain = (pharmacyDomain ?? 'main.localhost:8000').trim();
    if (domain.isEmpty) {
      domain = 'main.localhost:8000';
    }

    // Extract tenant code from domain (e.g. main.localhost:8000 -> main)
    String tenantCode = 'main';
    final hostOnly = domain.replaceAll(RegExp(r'^https?://'), '').split('/').first;
    final parts = hostOnly.split(':')[0].split('.');
    if (parts.length > 1 && parts.first != 'www' && parts.first != 'localhost') {
      tenantCode = parts.first;
    }

    // Ensure baseUrl with /api prefix
    var cleanHost = domain.replaceAll(RegExp(r'^https?://'), '');
    if (cleanHost.endsWith('/')) {
      cleanHost = cleanHost.substring(0, cleanHost.length - 1);
    }
    if (cleanHost.endsWith('/api')) {
      cleanHost = cleanHost.substring(0, cleanHost.length - 4);
    }

    final scheme = (cleanHost.contains('localhost') ||
            cleanHost.contains('127.0.0.1') ||
            cleanHost.contains(':8000') ||
            cleanHost.contains(':3333') ||
            cleanHost.contains(':3334'))
        ? 'http'
        : 'https';

    // On Windows, subdomains of localhost (e.g. main.localhost) cannot be resolved by WinSock DNS.
    // Connect to localhost:port while sending Host and X-Pharmacy-Code headers.
    var networkTarget = cleanHost;
    if (networkTarget.contains('.localhost')) {
      networkTarget = networkTarget.replaceAll(RegExp(r'^[^/:]+\.localhost'), 'localhost');
    }

    final normalizedBaseUrl = '$scheme://$networkTarget/api';

    final hwId = state.terminalHardwareId ?? await DeviceIdentifierService.getHardwareId();
    final termName = state.terminalName ?? DeviceIdentifierService.getTerminalName();

    try {
      final uri = Uri.parse('$normalizedBaseUrl/pos/activate-license');
      final resp = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Host': hostOnly,
          'X-Pharmacy-Code': tenantCode,
        },
        body: jsonEncode({
          'licenseKey': trimmedKey,
          'hardwareUuid': hwId,
          'terminalName': termName,
        }),
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(resp.body) as Map<String, dynamic>;

      if (resp.statusCode != 200 || body['valid'] != true) {
        final errorMsg = body['error'] ?? 'License verification failed (HTTP ${resp.statusCode})';
        return (success: false, error: errorMsg.toString(), config: null);
      }

      final lic = body['license'] as Map<String, dynamic>? ?? {};
      final pharm = body['pharmacy'] as Map<String, dynamic>? ?? {};
      final term = body['terminal'] as Map<String, dynamic>? ?? {};

      final updated = state.copyWith(
        mode: DatabaseMode.onlineApi,
        baseUrl: normalizedBaseUrl,
        pharmacyDomain: domain,
        pharmacyCode: pharm['code']?.toString() ?? tenantCode,
        licenseKey: trimmedKey,
        isConfigured: true,
        isLicenseValid: true,
        pharmacyName: pharm['name']?.toString() ?? 'Pharmacy Branch',
        pharmacyPhone: pharm['phone']?.toString(),
        pharmacyAddress: pharm['address']?.toString(),
        currency: pharm['currency']?.toString() ?? 'SDG',
        currencySymbol: pharm['currencySymbol']?.toString() ?? 'ج.س',
        taxRate: (pharm['taxRate'] as num?)?.toDouble() ?? 0.0,
        receiptFooter: pharm['receiptFooter']?.toString(),
        licenseExpiresAt: lic['expiresAt']?.toString(),
        licensePlan: lic['plan']?.toString(),
        validityDaysRemaining: lic['validityDaysRemaining'] as int?,
        terminalHardwareId: term['hardwareUuid']?.toString() ?? hwId,
        terminalName: term['name']?.toString() ?? termName,
        seatNumber: term['seatNumber'] as int?,
        branchId: branchId ?? pharm['id'] as int? ?? 1,
      );

      state = updated;
      await _manager.saveConfig(updated);
      return (success: true, error: null, config: updated);
    } catch (e) {
      return (
        success: false,
        error: 'Unable to reach pharmacy server at $normalizedBaseUrl: $e',
        config: null,
      );
    }
  }

  Future<void> resetConfiguration() async {
    final hwId = await DeviceIdentifierService.getHardwareId();
    final termName = DeviceIdentifierService.getTerminalName();
    final fresh = ApiConfig(
      mode: DatabaseMode.onlineApi,
      baseUrl: 'http://localhost:8000/api',
      branchId: 1,
      pharmacyDomain: 'main.localhost:8000',
      pharmacyCode: 'main',
      isConfigured: false,
      isLicenseValid: false,
      terminalHardwareId: hwId,
      terminalName: termName,
    );
    state = fresh;
    await _manager.saveConfig(fresh);
  }

  Future<void> updateConfig({
    DatabaseMode? mode,
    String? baseUrl,
    int? branchId,
    String? pharmacyCode,
    bool? isConfigured,
  }) async {
    final nextMode = mode ?? state.mode;
    final updated = state.copyWith(
      mode: mode,
      baseUrl: baseUrl,
      branchId: branchId,
      pharmacyCode: pharmacyCode,
      isConfigured: isConfigured ?? (nextMode == DatabaseMode.local ? true : state.isConfigured),
    );
    state = updated;
    await _manager.saveConfig(updated);
  }

  Future<void> updateToken(String? token) async {
    final updated = state.copyWith(token: token);
    state = updated;
    await _manager.saveConfig(updated);
  }
}

final apiConfigProvider = StateNotifierProvider<ApiConfigNotifier, ApiConfig>((ref) {
  return ApiConfigNotifier(ref.watch(apiConfigManagerProvider));
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final initialConfig = ref.watch(apiConfigProvider);
  final client = ApiClient(
    baseUrl: initialConfig.baseUrl,
    token: initialConfig.token,
    pharmacyCode: initialConfig.pharmacyCode,
    terminalHardwareId: initialConfig.terminalHardwareId,
    terminalName: initialConfig.terminalName,
  );
  ref.listen<ApiConfig>(apiConfigProvider, (_, next) {
    client.updateToken(next.token);
    client.updateBaseUrl(next.baseUrl);
    client.updatePharmacyCode(next.pharmacyCode);
    client.updateTerminalInfo(
      hardwareId: next.terminalHardwareId,
      name: next.terminalName,
    );
  });
  return client;
});

final networkMonitorProvider = ChangeNotifierProvider<NetworkMonitor>((ref) {
  final initialConfig = ref.watch(apiConfigProvider.select((c) => (baseUrl: c.baseUrl, mode: c.mode)));
  final monitor = NetworkMonitor(
    baseUrl: initialConfig.baseUrl,
    enabled: initialConfig.mode == DatabaseMode.onlineApi,
  );
  ref.listen<String>(apiConfigProvider.select((c) => c.baseUrl), (_, newBaseUrl) {
    monitor.updateBaseUrl(newBaseUrl);
  });
  ref.listen<DatabaseMode>(apiConfigProvider.select((c) => c.mode), (_, nextMode) {
    monitor.setEnabled(nextMode == DatabaseMode.onlineApi);
  });
  return monitor;
});

final syncEngineProvider = ChangeNotifierProvider<SyncEngine>((ref) {
  final db = ref.watch(databaseProvider);
  final client = ref.watch(apiClientProvider);
  final monitor = ref.watch(networkMonitorProvider);
  return SyncEngine(db: db, apiClient: client, networkMonitor: monitor);
});

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  final config = ref.watch(apiConfigProvider);
  if (config.mode == DatabaseMode.local) {
    return SqliteUserRepository(ref.watch(databaseProvider));
  }
  return ApiUserRepository(ref.watch(apiClientProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final config = ref.watch(apiConfigProvider);
  if (config.mode == DatabaseMode.local) {
    return SqliteAuthRepository(ref.watch(databaseProvider));
  }
  return ApiAuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(apiConfigManagerProvider),
    onTokenUpdated: (token) {
      ref.read(apiConfigProvider.notifier).updateToken(token);
    },
  );
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final local = SqliteSettingsRepository(ref.watch(databaseProvider));
  final config = ref.watch(apiConfigProvider);
  if (config.mode == DatabaseMode.local) {
    return local;
  }
  return ApiSettingsRepository(ref.watch(apiClientProvider), local);
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final config = ref.watch(apiConfigProvider);
  if (config.mode == DatabaseMode.local) {
    return SqliteCategoryRepository(ref.watch(databaseProvider));
  }
  return ApiCategoryRepository(ref.watch(apiClientProvider));
});

final supplierRepositoryProvider = Provider<SupplierRepository>((ref) {
  final config = ref.watch(apiConfigProvider);
  if (config.mode == DatabaseMode.local) {
    return SqliteSupplierRepository(ref.watch(databaseProvider));
  }
  return ApiSupplierRepository(ref.watch(apiClientProvider));
});

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  final local = SqliteProductRepository(ref.watch(databaseProvider));
  final config = ref.watch(apiConfigProvider);
  if (config.mode == DatabaseMode.local) {
    return local;
  }
  final api = ApiProductRepository(ref.watch(apiClientProvider));
  final syncEngine = ref.watch(syncEngineProvider);
  final networkMonitor = ref.watch(networkMonitorProvider);
  return OfflineFirstProductRepository(
    apiRepo: api,
    localRepo: local,
    syncEngine: syncEngine,
    networkMonitor: networkMonitor,
  );
});

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  final local = SqliteCustomerRepository(ref.watch(databaseProvider));
  final config = ref.watch(apiConfigProvider);
  if (config.mode == DatabaseMode.local) {
    return local;
  }
  final api = ApiCustomerRepository(ref.watch(apiClientProvider));
  final syncEngine = ref.watch(syncEngineProvider);
  final networkMonitor = ref.watch(networkMonitorProvider);
  return OfflineFirstCustomerRepository(
    apiRepo: api,
    localRepo: local,
    syncEngine: syncEngine,
    networkMonitor: networkMonitor,
  );
});

final stockAdjustmentRepositoryProvider = Provider<StockAdjustmentRepository>((ref) {
  final config = ref.watch(apiConfigProvider);
  if (config.mode == DatabaseMode.local) {
    return SqliteStockAdjustmentRepository(ref.watch(databaseProvider));
  }
  return ApiStockAdjustmentRepository(ref.watch(apiClientProvider));
});

final saleRepositoryProvider = Provider<SaleRepository>((ref) {
  final local = SqliteSaleRepository(ref.watch(databaseProvider));
  final config = ref.watch(apiConfigProvider);
  if (config.mode == DatabaseMode.local) {
    return local;
  }
  final api = ApiSaleRepository(ref.watch(apiClientProvider));
  final syncEngine = ref.watch(syncEngineProvider);
  final networkMonitor = ref.watch(networkMonitorProvider);
  return OfflineFirstSaleRepository(
    apiRepo: api,
    localRepo: local,
    syncEngine: syncEngine,
    networkMonitor: networkMonitor,
  );
});

final salesHoldRepositoryProvider = Provider<SalesHoldRepository>((ref) {
  final config = ref.watch(apiConfigProvider);
  if (config.mode == DatabaseMode.local) {
    return SqliteSalesHoldRepository(ref.watch(databaseProvider));
  }
  return ApiSalesHoldRepository(ref.watch(apiClientProvider));
});

final returnRepositoryProvider = Provider<ReturnRepository>((ref) {
  final config = ref.watch(apiConfigProvider);
  if (config.mode == DatabaseMode.local) {
    return SqliteReturnRepository(ref.watch(databaseProvider));
  }
  return ApiReturnRepository(ref.watch(apiClientProvider));
});

final allReturnsProvider = StreamProvider<List<AppReturn>>((ref) {
  return ref.watch(returnRepositoryProvider).watchAllReturns();
});

final purchaseRepositoryProvider = Provider<PurchaseRepository>((ref) {
  final config = ref.watch(apiConfigProvider);
  if (config.mode == DatabaseMode.local) {
    return SqlitePurchaseRepository(ref.watch(databaseProvider));
  }
  return ApiPurchaseRepository(ref.watch(apiClientProvider));
});

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  final local = SqliteReportRepository(ref.watch(databaseProvider));
  final config = ref.watch(apiConfigProvider);
  if (config.mode == DatabaseMode.local) {
    return local;
  }
  return OfflineFirstReportRepository(
    apiRepo: ApiReportRepository(ref.watch(apiClientProvider)),
    localRepo: local,
    networkMonitor: ref.watch(networkMonitorProvider),
  );
});

final staffFeedbackRepositoryProvider = Provider<StaffFeedbackRepository>((ref) {
  final local = SqliteStaffFeedbackRepository(ref.watch(databaseProvider));
  final config = ref.watch(apiConfigProvider);
  if (config.mode == DatabaseMode.local) {
    return local;
  }
  final api = ApiStaffFeedbackRepository(ref.watch(apiClientProvider));
  final syncEngine = ref.watch(syncEngineProvider);
  final networkMonitor = ref.watch(networkMonitorProvider);
  return OfflineFirstStaffFeedbackRepository(
    apiRepo: api,
    localRepo: local,
    syncEngine: syncEngine,
    networkMonitor: networkMonitor,
  );
});

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref.watch(databaseProvider));
});

final backupHistoryProvider = StreamProvider<List<BackupRecord>>((ref) {
  return ref.watch(backupServiceProvider).watchLogs();
});

final thermalPrinterServiceProvider = Provider<ThermalPrinterService>((ref) {
  return ThermalPrinterService(ref.watch(settingsRepositoryProvider));
});

final updateCheckerServiceProvider = Provider<UpdateCheckerService>((ref) {
  return UpdateCheckerService(ref.watch(settingsRepositoryProvider));
});

/// The currently selected locale (en / ar). Persisted through the settings
/// repository by [LanguageSwitcher] and restored during app bootstrap.
final localeProvider = StateProvider<Locale>((ref) => const Locale('en'));

/// The currently selected theme mode (system / light / dark). Persisted through
/// the settings repository by [ThemeModeSwitcher] and restored during app bootstrap.
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

/// Whether the desktop navigation sidebar is expanded (full width) or collapsed (icon rail).
final sidebarExpandedProvider = StateProvider<bool>((ref) => true);

final categoryListProvider = StreamProvider<List<AppCategory>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchAll();
});

final supplierListProvider = StreamProvider<List<AppSupplier>>((ref) {
  return ref.watch(supplierRepositoryProvider).watchAll();
});

final productListProvider = StreamProvider<List<AppProduct>>((ref) {
  return ref.watch(productRepositoryProvider).watchAll();
});

final lowStockProductsProvider = StreamProvider<List<AppProduct>>((ref) {
  return ref.watch(productRepositoryProvider).watchLowStock();
});

/// Products expiring within 30 days (including already expired).
final expiringProductsProvider = StreamProvider<List<AppProduct>>((ref) {
  return ref.watch(productRepositoryProvider).watchExpiring(withinDays: 30);
});

final customerListProvider = StreamProvider<List<CustomerWithBalance>>((ref) {
  return ref.watch(customerRepositoryProvider).watchAll();
});

final customerPaymentsProvider =
    StreamProvider.autoDispose.family<List<CustomerPayment>, int>((ref, id) {
  return ref.watch(customerRepositoryProvider).watchPayments(id);
});

final branchStaffFeedbacksProvider =
    StreamProvider.family<List<StaffProductFeedback>, int?>((ref, branchId) {
  return ref
      .watch(staffFeedbackRepositoryProvider)
      .watchBranchFeedbacks(branchId: branchId, status: 'pending');
});

final currencySymbolProvider = FutureProvider<String>((ref) {
  return ref.watch(settingsRepositoryProvider).getCurrencySymbol();
});

final storeSettingsProvider = FutureProvider<StoreSettings>((ref) {
  return ref.watch(settingsRepositoryProvider).getStoreSettings();
});

final taxRateProvider = FutureProvider<double>((ref) async {
  final settings = await ref.watch(settingsRepositoryProvider).getStoreSettings();
  final value = double.tryParse(settings.taxRate) ?? 0;
  if (!value.isFinite) return 0;
  return value.clamp(0, 100).toDouble();
});

final defaultLowStockThresholdProvider = FutureProvider<int>((ref) {
  return ref.watch(settingsRepositoryProvider).getDefaultLowStockThreshold();
});

final salesHoldListProvider = StreamProvider<List<AppSalesHold>>((ref) {
  return ref.watch(salesHoldRepositoryProvider).watchAll();
});

final posControllerProvider =
    NotifierProvider<PosController, PosState>(PosController.new);

/// Filter for the sales history list. Records compare by value, so new
/// instances with equal fields reuse the same provider.
typedef SaleFilter = ({
  DateTime? from,
  DateTime? to,
  String? paymentMethod,
  SaleStatus? status,
  String? search,
});

final salesHistoryListProvider =
    StreamProvider.autoDispose.family<List<AppSale>, SaleFilter>((ref, filter) {
  return ref.watch(saleRepositoryProvider).watchSales(
        from: filter.from,
        to: filter.to,
        paymentMethod: filter.paymentMethod,
        status: filter.status,
        search: filter.search,
      );
});

final pendingSyncInvoicesProvider = StreamProvider<Set<String>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.syncQueueEntries)
        ..where((t) => t.status.isIn(['pending', 'failed'])))
      .watch()
      .map((entries) {
    final set = <String>{};
    for (final e in entries) {
      if (e.entityType == 'sale') {
        try {
          final payload = jsonDecode(e.payloadJson) as Map<String, dynamic>;
          final inv = payload['invoice_number'] as String?;
          if (inv != null && inv.isNotEmpty) {
            set.add(inv);
          }
        } catch (_) {}
      }
    }
    return set;
  });
});

final saleDetailProvider =
    FutureProvider.autoDispose.family<SaleDetail, int>((ref, id) {
  return ref.watch(saleRepositoryProvider).getSaleDetail(id);
});

final cashierNameProvider =
    FutureProvider.autoDispose.family<String, int>((ref, userId) async {
  final user = await ref.watch(userRepositoryProvider).findById(userId);
  return user?.username ?? '';
});

final userListProvider = StreamProvider<List<AppUser>>((ref) {
  return ref.watch(userRepositoryProvider).watchUsers();
});

final purchaseListProvider = StreamProvider<List<AppPurchase>>((ref) {
  return ref.watch(purchaseRepositoryProvider).watchPurchases();
});

final purchaseDetailProvider =
    FutureProvider.autoDispose.family<PurchaseDetail, int>((ref, id) {
  return ref.watch(purchaseRepositoryProvider).getPurchaseDetail(id);
});

/// Inclusive report date range.
typedef ReportRange = ({DateTime from, DateTime to});

final reportSummaryProvider =
    FutureProvider.autoDispose.family<ReportSummary, ReportRange>(
  (ref, range) {
    return ref
        .watch(reportRepositoryProvider)
        .getSummary(from: range.from, to: range.to);
  },
);

/// Revenue and sale count for the current calendar day.
final todaySalesProvider = FutureProvider<ReportSummary>((ref) {
  final now = DateTime.now();
  final from = DateTime(now.year, now.month, now.day);
  final to = DateTime(now.year, now.month, now.day, 23, 59, 59);
  return ref
      .watch(reportRepositoryProvider)
      .getSummary(from: from, to: to);
});

final monthlyReportProvider = FutureProvider<List<MonthlyReport>>((ref) {
  return ref.watch(reportRepositoryProvider).getMonthlySummary(months: 6);
});

final categoryReportProvider =
    FutureProvider.autoDispose.family<List<CategoryReport>, ReportRange>(
  (ref, range) {
    return ref
        .watch(reportRepositoryProvider)
        .getCategorySummary(from: range.from, to: range.to);
  },
);

final stockValuationProvider = FutureProvider<StockValuation>((ref) {
  return ref.watch(reportRepositoryProvider).getStockValuation();
});

final syncEventsProvider = StreamProvider<String>((ref) async* {
  final config = ref.watch(apiConfigProvider);
  if (config.mode != DatabaseMode.onlineApi ||
      config.token == null ||
      config.token!.isEmpty) {
    return;
  }
  final client = ref.watch(apiClientProvider);
  final monitor = ref.watch(networkMonitorProvider);
  while (true) {
    try {
      await for (final event in client.connectEvents()) {
        monitor.reportSuccess();
        yield event;
      }
    } catch (_) {
      // Background reconnection loop
    }
    await Future.delayed(const Duration(seconds: 5));
  }
});

final syncEventListener = Provider<void>((ref) {
  ref.listen<AsyncValue<String>>(syncEventsProvider, (prev, next) {
    if (next.hasValue) {
      final data = next.value!;
      try {
        final json = jsonDecode(data) as Map<String, dynamic>;
        final eventName = json['event'] as String?;
        if (eventName == 'purchase_approved' ||
            eventName == 'purchase_created' ||
            eventName == 'product_updated' ||
            eventName == 'product_created' ||
            eventName == 'stock_adjusted') {
          ref.read(productRepositoryProvider).refresh();
          ref.read(purchaseRepositoryProvider).refresh();
          ref.invalidate(productListProvider);
          ref.invalidate(lowStockProductsProvider);
          ref.invalidate(expiringProductsProvider);
          ref.invalidate(todaySalesProvider);
          ref.invalidate(stockValuationProvider);
        } else if (eventName == 'sale_created') {
          ref.read(productRepositoryProvider).refresh();
          ref.invalidate(productListProvider);
          ref.invalidate(lowStockProductsProvider);
          ref.invalidate(todaySalesProvider);
          ref.invalidate(stockValuationProvider);
        } else if (eventName == 'category_created') {
          ref.invalidate(categoryListProvider);
        } else if (eventName == 'supplier_created') {
          ref.invalidate(supplierListProvider);
        } else if (eventName == 'staff_feedback_created' ||
            eventName == 'staff_feedback_updated') {
          ref.read(staffFeedbackRepositoryProvider).refresh();
          ref.invalidate(branchStaffFeedbacksProvider);
        }
      } catch (_) {}
    }
  });
});
