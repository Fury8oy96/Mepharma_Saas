import router from '@adonisjs/core/services/router'
import { middleware } from '#start/kernel'

// Controllers
const SystemAuthController = () => import('#controllers/provider/system_auth_controller')
const TenantsController = () => import('#controllers/provider/tenants_controller')
const LicensesController = () => import('#controllers/provider/licenses_controller')
const TelemetryController = () => import('#controllers/provider/telemetry_controller')
const AuditLogsController = () => import('#controllers/provider/audit_logs_controller')
const BackupsController = () => import('#controllers/provider/backups_controller')
const MasterCatalogController = () => import('#controllers/provider/master_catalog_controller')

const AdminAuthController = () => import('#controllers/pharmacy_admin/admin_auth_controller')
const StaffController = () => import('#controllers/pharmacy_admin/staff_controller')
const CatalogController = () => import('#controllers/pharmacy_admin/catalog_controller')
const ProcurementController = () => import('#controllers/pharmacy_admin/procurement_controller')
const CustomersController = () => import('#controllers/pharmacy_admin/customers_controller')
const ReportsController = () => import('#controllers/pharmacy_admin/reports_controller')
const SettingsController = () => import('#controllers/pharmacy_admin/settings_controller')
const StaffFeedbackController = () => import('#controllers/pharmacy_admin/staff_feedback_controller')
const StockAdjustmentsController = () => import('#controllers/pharmacy_admin/stock_adjustments_controller')

const PosAuthController = () => import('#controllers/desktop_pos/pos_auth_controller')
const PosLicenseController = () => import('#controllers/desktop_pos/pos_license_controller')
const PosCheckoutController = () => import('#controllers/desktop_pos/pos_checkout_controller')
const PosProductsController = () => import('#controllers/desktop_pos/pos_products_controller')
const PosHoldsController = () => import('#controllers/desktop_pos/pos_holds_controller')
const PosReturnsController = () => import('#controllers/desktop_pos/pos_returns_controller')
const PosSyncController = () => import('#controllers/desktop_pos/pos_sync_controller')

/*
|--------------------------------------------------------------------------
| Public Status & Health Check Endpoints
|--------------------------------------------------------------------------
*/
router.get('/status', async () => ({ status: 'ok', engine: 'AdonisJS v6 Enterprise Core', version: '2.0.0' }))
router.get('/api/status', async () => ({ status: 'ok', engine: 'AdonisJS v6 Enterprise Core', version: '2.0.0' }))
router.get('/health', async () => ({ status: 'healthy', timestamp: new Date().toISOString() }))
router.get('/api/health', async () => ({ status: 'healthy', timestamp: new Date().toISOString() }))

// SSE Event Streams
router.get('/sync/events', [PosSyncController, 'events'])
router.get('/api/sync/events', [PosSyncController, 'events'])

/*
|--------------------------------------------------------------------------
| 1. PROVIDER CONTROL PLANE ROUTES (Platform Superadmin)
|--------------------------------------------------------------------------
*/
router
  .group(() => {
    router.post('/auth/login', [SystemAuthController, 'login'])

    router
      .group(() => {
        // Tenants & Licenses
        router.get('/tenants', [TenantsController, 'index'])
        router.post('/tenants', [TenantsController, 'store'])
        router.get('/tenants/:id', [TenantsController, 'show'])
        router.put('/tenants/:id', [TenantsController, 'update'])
        router.delete('/tenants/:id', [TenantsController, 'destroy'])

        // Terminal Seats & Hardware Management
        router.get('/tenants/:id/terminals', [TenantsController, 'getTerminals'])
        router.put('/tenants/:id/seats', [TenantsController, 'updateSeats'])
        router.put('/tenants/:id/terminals/:terminalId', [TenantsController, 'updateTerminal'])
        router.delete('/tenants/:id/terminals/:terminalId', [TenantsController, 'unlinkTerminal'])
        router.post('/tenants/:id/terminals/:terminalId/unlink', [TenantsController, 'unlinkTerminal'])

        router.post('/licenses/issue', [LicensesController, 'issue'])
        router.post('/licenses/verify', [LicensesController, 'verify'])

        // Deep Telemetry & System Monitoring
        router.get('/telemetry', [TelemetryController, 'index'])

        // Enterprise Audit Trail
        router.get('/audit-logs', [AuditLogsController, 'index'])

        // Disaster Recovery & Whole-System Backups
        router.get('/backups', [BackupsController, 'index'])
        router.post('/backups', [BackupsController, 'create'])
        router.post('/backups/create', [BackupsController, 'create'])
        router.post('/backups/:filename/restore', [BackupsController, 'restore'])
        router.post('/backups/restore', [BackupsController, 'restore'])
        router.get('/backups/:filename/download', [BackupsController, 'download'])
        router.get('/backups/download/:filename', [BackupsController, 'download'])

        // Master Catalog Management
        router.get('/master-catalog', [MasterCatalogController, 'index'])
        router.post('/master-catalog', [MasterCatalogController, 'store'])
        router.put('/master-catalog/:id', [MasterCatalogController, 'update'])
        router.delete('/master-catalog/:id', [MasterCatalogController, 'destroy'])
      })
      .use(middleware.providerGate())
  })
  .prefix('/provider/api')

/*
|--------------------------------------------------------------------------
| 2. PHARMACY ADMIN WEB DASHBOARD ROUTES
| Full API handlers supporting both /admin/api/... and direct /... requests
|--------------------------------------------------------------------------
*/
const registerPharmacyAdminRoutes = (r: typeof router) => {
  // Public branch info & login endpoint
  r.get('/info', [AdminAuthController, 'info'])
  r.post('/auth/login', [AdminAuthController, 'login'])

  // Admin routes protected by WebDashboardGate
  r.group(() => {
    r.get('/auth/me', [AdminAuthController, 'me'])

    // Staff & Users Management
    r.get('/staff', [StaffController, 'index'])
    r.post('/staff', [StaffController, 'store'])
    r.put('/staff/:id', [StaffController, 'update'])
    r.delete('/staff/:id', [StaffController, 'destroy'])

    r.get('/users', [StaffController, 'index'])
    r.post('/users', [StaffController, 'store'])
    r.put('/users/:id', [StaffController, 'update'])
    r.delete('/users/:id', [StaffController, 'destroy'])

    // Catalog: Products, Categories, Suppliers
    r.get('/products', [CatalogController, 'getProducts'])
    r.post('/products', [CatalogController, 'storeProduct'])
    r.get('/products/:id', [CatalogController, 'getProduct']).where('id', router.matchers.number())
    r.put('/products/:id', [CatalogController, 'updateProduct']).where('id', router.matchers.number())
    r.delete('/products/:id', [CatalogController, 'deleteProduct']).where('id', router.matchers.number())
    r.post('/products/merge', [CatalogController, 'mergeProducts'])

    r.get('/categories', [CatalogController, 'getCategories'])
    r.post('/categories', [CatalogController, 'storeCategory'])
    r.put('/categories/:id', [CatalogController, 'updateCategory']).where('id', router.matchers.number())
    r.delete('/categories/:id', [CatalogController, 'deleteCategory']).where('id', router.matchers.number())

    r.get('/suppliers', [CatalogController, 'getSuppliers'])
    r.post('/suppliers', [CatalogController, 'storeSupplier'])
    r.put('/suppliers/:id', [CatalogController, 'updateSupplier']).where('id', router.matchers.number())
    r.delete('/suppliers/:id', [CatalogController, 'deleteSupplier']).where('id', router.matchers.number())

    // Procurement / Purchase Orders
    r.get('/purchases/next-number', [ProcurementController, 'nextNumber'])
    r.get('/purchases', [ProcurementController, 'index'])
    r.post('/purchases', [ProcurementController, 'store'])
    r.get('/purchases/:id', [ProcurementController, 'show']).where('id', router.matchers.number())
    r.put('/purchases/:id', [ProcurementController, 'update']).where('id', router.matchers.number())
    r.put('/purchases/:id/approve', [ProcurementController, 'approve']).where('id', router.matchers.number())
    r.post('/purchases/:id/approve', [ProcurementController, 'approve']).where('id', router.matchers.number())

    // Staff Restock Feedbacks / Recommendations
    r.get('/staff-feedbacks', [StaffFeedbackController, 'index'])
    r.post('/staff-feedbacks', [StaffFeedbackController, 'store'])
    r.patch('/staff-feedbacks/:id', [StaffFeedbackController, 'update']).where('id', router.matchers.number())

    // Stock Adjustments
    r.get('/stock-adjustments', [StockAdjustmentsController, 'index'])
    r.post('/stock-adjustments', [StockAdjustmentsController, 'store'])

    // Sales Ledger
    r.get('/sales', [PosCheckoutController, 'index'])
    r.get('/sales/:id', [PosCheckoutController, 'show']).where('id', router.matchers.number())

    // Customers & CRM
    r.get('/customers', [CustomersController, 'index'])
    r.post('/customers', [CustomersController, 'store'])
    r.get('/customers/:id', [CustomersController, 'show']).where('id', router.matchers.number())
    r.put('/customers/:id', [CustomersController, 'update']).where('id', router.matchers.number())
    r.delete('/customers/:id', [CustomersController, 'destroy']).where('id', router.matchers.number())
    r.get('/customers/:id/balance', [CustomersController, 'getBalance']).where('id', router.matchers.number())
    r.get('/customers/:id/payments', [CustomersController, 'getPayments']).where('id', router.matchers.number())
    r.post('/customers/:id/payments', [CustomersController, 'recordPayment']).where('id', router.matchers.number())

    r.get('/customer-requests', [CustomersController, 'getRequests'])
    r.post('/customer-requests', [CustomersController, 'storeRequest'])
    r.post('/customer-requests/:id/notify', [CustomersController, 'notifyRequest'])
    r.post('/customer-requests/:id/fulfill', [CustomersController, 'fulfillRequest'])

    r.get('/communications/logs', [CustomersController, 'getLogs'])
    r.get('/communications/templates', [CustomersController, 'getTemplates'])
    r.post('/communications/broadcast', [CustomersController, 'broadcast'])

    // Formulary Import
    r.get('/master-catalog', [MasterCatalogController, 'index'])
    r.post('/master-catalog/import', [MasterCatalogController, 'importToTenant'])

    // Financial Reports & Cockpit Overview
    r.get('/reports/overview', [ReportsController, 'overview'])
    r.get('/reports/summary', [ReportsController, 'summary'])
    r.get('/reports/sales', [ReportsController, 'salesChart'])
    r.get('/reports/monthly', [ReportsController, 'monthly'])
    r.get('/reports/categories', [ReportsController, 'categories'])
    r.get('/reports/stock-valuation', [ReportsController, 'stockValuation'])

    // Settings
    r.get('/settings', [SettingsController, 'index'])
    r.post('/settings', [SettingsController, 'update'])
    r.get('/settings/store', [SettingsController, 'getStore'])
    r.post('/settings/store', [SettingsController, 'update'])
    r.post('/settings/apply-margin', [SettingsController, 'applyMargin'])
  }).use(middleware.webGate())
}

// 1. Mount under /admin/api
router.group(() => {
  registerPharmacyAdminRoutes(router)
}).prefix('/admin/api')

// 2. Also mount direct root routes for full compatibility
registerPharmacyAdminRoutes(router)

/*
|--------------------------------------------------------------------------
| 3. DESKTOP POS API ROUTES (Flutter Windows Client)
|--------------------------------------------------------------------------
*/
router
  .group(() => {
    router.post('/pos/activate-license', [PosLicenseController, 'activateLicense'])
    router.post('/license/activate', [PosLicenseController, 'activateLicense'])
    router.get('/pos/pharmacy-info', [PosLicenseController, 'info'])
    router.get('/sync/status', [PosSyncController, 'status'])
    router.post('/auth/login', [PosAuthController, 'login']).use(middleware.terminalSeat())
  })
  .prefix('/api')

// Authenticated POS Client Operations
router
  .group(() => {
    router.post('/auth/verify-supervisor', [PosAuthController, 'verifySupervisor'])

    // Users lookup & management
    router.get('/users/count', [StaffController, 'count'])
    router.get('/users/username/:username', [StaffController, 'findByUsername'])
    router.post('/users/ensure-default-admin', [StaffController, 'ensureDefaultAdmin'])
    router.get('/users', [StaffController, 'index'])
    router.get('/users/:id', [StaffController, 'show']).where('id', router.matchers.number())
    router.post('/users', [StaffController, 'store'])
    router.put('/users/:id', [StaffController, 'update']).where('id', router.matchers.number())
    router.delete('/users/:id', [StaffController, 'destroy']).where('id', router.matchers.number())

    // Products catalog for POS
    router.get('/products/check-sku', [PosProductsController, 'checkSku'])
    router.get('/products/check-barcode', [PosProductsController, 'checkBarcode'])
    router.get('/products/count-low-stock', [PosProductsController, 'countLowStock'])
    router.get('/products/low-stock', [PosProductsController, 'lowStock'])
    router.get('/products/expiring', [PosProductsController, 'expiring'])
    router.get('/products/sku/:sku', [PosProductsController, 'findBySku'])
    router.get('/products/barcode/:barcode', [PosProductsController, 'findByBarcode'])
    router.get('/products/:productId/adjustments', [StockAdjustmentsController, 'forProduct']).where('productId', router.matchers.number())
    router.get('/products', [PosProductsController, 'index'])
    router.post('/products', [PosProductsController, 'store'])
    router.get('/products/:id', [PosProductsController, 'show']).where('id', router.matchers.number())
    router.put('/products/:id', [PosProductsController, 'update']).where('id', router.matchers.number())
    router.delete('/products/:id', [PosProductsController, 'destroy']).where('id', router.matchers.number())

    router.get('/pos/products', [PosProductsController, 'index'])
    router.post('/pos/products', [PosProductsController, 'store'])
    router.get('/pos/products/:id', [PosProductsController, 'show']).where('id', router.matchers.number())
    router.put('/pos/products/:id', [PosProductsController, 'update']).where('id', router.matchers.number())
    router.delete('/pos/products/:id', [PosProductsController, 'destroy']).where('id', router.matchers.number())

    // Stock adjustments
    router.get('/stock-adjustments', [StockAdjustmentsController, 'index'])
    router.post('/stock-adjustments', [StockAdjustmentsController, 'store'])

    // Categories & Suppliers
    router.get('/categories', [CatalogController, 'getCategories'])
    router.post('/categories', [CatalogController, 'storeCategory'])
    router.put('/categories/:id', [CatalogController, 'updateCategory']).where('id', router.matchers.number())
    router.delete('/categories/:id', [CatalogController, 'deleteCategory']).where('id', router.matchers.number())

    router.get('/suppliers', [CatalogController, 'getSuppliers'])
    router.post('/suppliers', [CatalogController, 'storeSupplier'])
    router.put('/suppliers/:id', [CatalogController, 'updateSupplier']).where('id', router.matchers.number())
    router.delete('/suppliers/:id', [CatalogController, 'deleteSupplier']).where('id', router.matchers.number())

    // Customers & Credit Payments
    router.get('/customers/check-name', [CustomersController, 'checkName'])
    router.get('/customers', [CustomersController, 'index'])
    router.post('/customers', [CustomersController, 'store'])
    router.get('/customers/:id', [CustomersController, 'show']).where('id', router.matchers.number())
    router.put('/customers/:id', [CustomersController, 'update']).where('id', router.matchers.number())
    router.delete('/customers/:id', [CustomersController, 'destroy']).where('id', router.matchers.number())
    router.get('/customers/:id/balance', [CustomersController, 'getBalance']).where('id', router.matchers.number())
    router.get('/customers/:id/payments', [CustomersController, 'getPayments']).where('id', router.matchers.number())
    router.post('/customers/:id/payments', [CustomersController, 'recordPayment']).where('id', router.matchers.number())
    router.get('/customer-requests', [CustomersController, 'getRequests'])
    router.post('/customer-requests', [CustomersController, 'storeRequest'])

    // Reports for POS Dashboard
    router.get('/reports/overview', [ReportsController, 'overview'])
    router.get('/reports/summary', [ReportsController, 'summary'])
    router.get('/reports/stock-valuation', [ReportsController, 'stockValuation'])
    router.get('/reports/monthly', [ReportsController, 'monthly'])
    router.get('/reports/categories', [ReportsController, 'categories'])
    router.get('/reports/sales', [ReportsController, 'salesChart'])

    // Purchases / Procurement
    router.get('/purchases/next-number', [ProcurementController, 'nextNumber'])
    router.get('/purchases', [ProcurementController, 'index'])
    router.post('/purchases', [ProcurementController, 'store'])
    router.get('/purchases/:id', [ProcurementController, 'show']).where('id', router.matchers.number())
    router.put('/purchases/:id', [ProcurementController, 'update']).where('id', router.matchers.number())
    router.put('/purchases/:id/approve', [ProcurementController, 'approve']).where('id', router.matchers.number())
    router.post('/purchases/:id/approve', [ProcurementController, 'approve']).where('id', router.matchers.number())

    // Staff Restock Feedbacks / Recommendations
    router.get('/staff-feedbacks', [StaffFeedbackController, 'index'])
    router.post('/staff-feedbacks', [StaffFeedbackController, 'store'])
    router.patch('/staff-feedbacks/:id', [StaffFeedbackController, 'update']).where('id', router.matchers.number())

    // Store Settings
    router.get('/settings', [SettingsController, 'index'])
    router.get('/settings/store', [SettingsController, 'getStore'])
    router.get('/settings/:key', [SettingsController, 'showKey'])
    router.get('/store-settings', [SettingsController, 'getStore'])
    router.post('/settings', [SettingsController, 'update'])
    router.post('/settings/store', [SettingsController, 'update'])
    router.post('/settings/apply-margin', [SettingsController, 'applyMargin'])

    // Sales Ledger & Checkout
    router.get('/sales/next-number', [PosCheckoutController, 'nextNumber'])
    router.get('/sales', [PosCheckoutController, 'index'])
    router.post('/sales', [PosCheckoutController, 'store'])
    router.get('/sales/:id', [PosCheckoutController, 'show']).where('id', router.matchers.number())
    router.get('/sales/:saleId/returns', [PosReturnsController, 'forSale']).where('saleId', router.matchers.number())
    router.get('/sales/:saleId/return-items', [PosReturnsController, 'returnItemsForSale']).where('saleId', router.matchers.number())

    // Sales Holds
    router.get('/sales-holds', [PosHoldsController, 'index'])
    router.post('/sales-holds', [PosHoldsController, 'store'])
    router.post('/sales-holds/create', [PosHoldsController, 'store'])
    router.delete('/sales-holds/:id', [PosHoldsController, 'destroy']).where('id', router.matchers.number())

    // Returns
    router.get('/returns', [PosReturnsController, 'index'])
    router.post('/returns', [PosReturnsController, 'store'])

    // Delta Sync
    router.get('/sync/pull', [PosSyncController, 'pullUpdates'])
    router.get('/sync/pull-updates', [PosSyncController, 'pullUpdates'])
    router.post('/sync/push', [PosSyncController, 'pushBatch'])
    router.post('/sync/push-batch', [PosSyncController, 'pushBatch'])
  })
  .prefix('/api')
  .use(middleware.authJwt())

// Root sync & license endpoints (authenticated sync mutations)
router.get('/sync/status', [PosSyncController, 'status'])
router
  .group(() => {
    router.get('/sync/pull', [PosSyncController, 'pullUpdates'])
    router.get('/sync/pull-updates', [PosSyncController, 'pullUpdates'])
    router.post('/sync/push', [PosSyncController, 'pushBatch'])
    router.post('/sync/push-batch', [PosSyncController, 'pushBatch'])
  })
  .use(middleware.authJwt())

router.post('/pos/activate-license', [PosLicenseController, 'activateLicense'])
router.post('/license/activate', [PosLicenseController, 'activateLicense'])
router.get('/pos/pharmacy-info', [PosLicenseController, 'info'])

/*
|--------------------------------------------------------------------------
| SPA Fallback for Web Dashboards (Provider & Pharmacy Admin)
| Only handles non-API GET requests
|--------------------------------------------------------------------------
*/
router.get('*', async ({ request, response }) => {
  const url = request.url()
  if (
    url.startsWith('/api') ||
    url.startsWith('/provider/api') ||
    url.startsWith('/admin/api') ||
    url.includes('/purchases') ||
    url.includes('/staff-feedbacks') ||
    url.includes('/stock-adjustments') ||
    url.includes('/products') ||
    url.includes('/categories') ||
    url.includes('/suppliers') ||
    url.includes('/reports') ||
    url.includes('/settings') ||
    url.includes('/customers') ||
    url.includes('/users') ||
    url.includes('/sales-holds') ||
    url.includes('/returns')
  ) {
    return response.status(404).json({
      error: 'Not Found',
      message: `API route '${url}' was not found.`,
    })
  }

  return response.download('public/index.html')
})
