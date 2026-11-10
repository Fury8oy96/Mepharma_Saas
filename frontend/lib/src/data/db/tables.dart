import 'package:drift/drift.dart';

import 'enums.dart';

class Users extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get username => text().unique()();

  TextColumn get passwordHash => text()();

  TextColumn get role => textEnum<UserRole>()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  TextColumn get description => text().nullable()();
}

class Suppliers extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  TextColumn get contactPerson => text().nullable()();

  TextColumn get phone => text().nullable()();

  TextColumn get email => text().nullable()();

  TextColumn get address => text().nullable()();
}

@TableIndex(name: 'products_name_idx', columns: {#name})
class Products extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get sku => text().unique()();

  TextColumn get barcode => text().unique().nullable()();

  TextColumn get name => text()();

  IntColumn get categoryId =>
      integer().references(Categories, #id, onDelete: KeyAction.setNull).nullable()();

  IntColumn get supplierId =>
      integer().references(Suppliers, #id, onDelete: KeyAction.setNull).nullable()();

  /// Minor units (cents).
  IntColumn get costPrice => integer().withDefault(const Constant(0))();

  /// Minor units (cents).
  IntColumn get sellingPrice => integer().withDefault(const Constant(0))();

  IntColumn get stockQuantity => integer().withDefault(const Constant(0))();

  IntColumn get lowStockThreshold => integer().withDefault(const Constant(10))();

  DateTimeColumn get expiryDate => dateTime().nullable()();

  TextColumn get description => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@TableIndex(name: 'sales_created_at_idx', columns: {#createdAt})
class Sales extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get invoiceNumber => text().unique()();

  IntColumn get userId => integer().references(Users, #id)();

  TextColumn get customerName => text().nullable()();

  /// Minor units (cents), before discount/tax.
  IntColumn get subtotal => integer().withDefault(const Constant(0))();

  /// Minor units (cents).
  IntColumn get discount => integer().withDefault(const Constant(0))();

  TextColumn get discountType => textEnum<DiscountType>().nullable()();

  /// Minor units (cents).
  IntColumn get taxAmount => integer().withDefault(const Constant(0))();

  /// Minor units (cents), final payable.
  IntColumn get totalAmount => integer()();

  /// Minor units (cents).
  IntColumn get paidAmount => integer().withDefault(const Constant(0))();

  /// Minor units (cents).
  IntColumn get changeAmount => integer().withDefault(const Constant(0))();

  TextColumn get paymentMethod => text().nullable()();

  IntColumn get customerId =>
      integer().references(Customers, #id, onDelete: KeyAction.setNull).nullable()();

  // No SQL default: drift_dev has a codegen issue with enum defaults.
  // Insert code always provides the status explicitly.
  TextColumn get status => textEnum<SaleStatus>()();

  /// Nullable, for future multi-branch deployments.
  IntColumn get branchId => integer().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Customers extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().unique()();

  TextColumn get phone => text().nullable()();

  TextColumn get email => text().nullable()();

  TextColumn get address => text().nullable()();

  TextColumn get notes => text().nullable()();

  /// Credit limit in minor units (cents); 0 means no explicit limit.
  IntColumn get creditLimit => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@TableIndex(name: 'customer_payments_customer_idx', columns: {#customerId})
class CustomerPayments extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get customerId =>
      integer().references(Customers, #id, onDelete: KeyAction.cascade)();

  IntColumn get userId => integer().references(Users, #id).nullable()();

  /// Amount paid towards the account balance (minor units / cents).
  IntColumn get amount => integer()();

  TextColumn get note => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@TableIndex(name: 'sale_items_sale_id_idx', columns: {#saleId})
class SaleItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get saleId =>
      integer().references(Sales, #id, onDelete: KeyAction.cascade)();

  IntColumn get productId =>
      integer().references(Products, #id, onDelete: KeyAction.setNull).nullable()();

  /// Snapshot for history/reprints.
  TextColumn get productName => text()();

  /// Snapshot.
  TextColumn get barcode => text().nullable()();

  IntColumn get quantity => integer()();

  /// Minor units (cents).
  IntColumn get unitPrice => integer()();

  /// Minor units (cents), line discount.
  IntColumn get discount => integer().withDefault(const Constant(0))();

  /// Minor units (cents).
  IntColumn get totalPrice => integer()();

  /// Batch number from offline sale (nullable, populated when synced).
  TextColumn get batchNumber => text().nullable()();
}

class Purchases extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get invoiceNumber => text().unique()();

  IntColumn get supplierId => integer().references(Suppliers, #id)();

  IntColumn get userId => integer().references(Users, #id)();

  /// Minor units (cents).
  IntColumn get totalAmount => integer()();

  DateTimeColumn get purchaseDate => dateTime()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@TableIndex(name: 'purchase_items_purchase_id_idx', columns: {#purchaseId})
class PurchaseItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get purchaseId =>
      integer().references(Purchases, #id, onDelete: KeyAction.cascade)();

  IntColumn get productId =>
      integer().references(Products, #id, onDelete: KeyAction.setNull).nullable()();

  /// Snapshot.
  TextColumn get productName => text()();

  IntColumn get quantity => integer()();

  /// Minor units (cents).
  IntColumn get costPrice => integer()();

  /// Minor units (cents).
  IntColumn get totalCost => integer()();
}

@TableIndex(name: 'stock_adjustments_product_idx', columns: {#productId})
class StockAdjustments extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get productId => integer().references(Products, #id)();

  IntColumn get adjustmentQuantity => integer()();

  TextColumn get reason => text().nullable()();

  /// e.g. 'manual', 'sale:12', 'purchase:34', 'return:5'.
  TextColumn get reference => text().nullable()();

  IntColumn get userId => integer().references(Users, #id).nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@TableIndex(name: 'returns_sale_idx', columns: {#saleId})
class Returns extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get saleId => integer().references(Sales, #id)();

  /// Snapshot of the original invoice.
  TextColumn get invoiceNumber => text()();

  IntColumn get userId => integer().references(Users, #id)();

  /// Minor units (cents).
  IntColumn get totalRefund => integer()();

  TextColumn get reason => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@TableIndex(name: 'return_items_return_idx', columns: {#returnId})
class ReturnItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get returnId =>
      integer().references(Returns, #id, onDelete: KeyAction.cascade)();

  IntColumn get saleItemId =>
      integer().references(SaleItems, #id, onDelete: KeyAction.setNull).nullable()();

  IntColumn get productId =>
      integer().references(Products, #id, onDelete: KeyAction.setNull).nullable()();

  /// Snapshot.
  TextColumn get productName => text()();

  IntColumn get quantity => integer()();

  /// Minor units (cents), refunded unit price.
  IntColumn get unitPrice => integer()();

  /// Minor units (cents).
  IntColumn get totalRefund => integer()();
}

class SalesHolds extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get holdNumber => text().unique()();

  IntColumn get userId => integer().references(Users, #id)();

  /// Serialized cart.
  TextColumn get itemsJson => text()();

  /// Minor units (cents).
  IntColumn get subtotal => integer()();

  /// Minor units (cents).
  IntColumn get discount => integer().withDefault(const Constant(0))();

  TextColumn get discountType => textEnum<DiscountType>().nullable()();

  /// Minor units (cents).
  IntColumn get totalAmount => integer()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Settings extends Table {
  TextColumn get key => text()();

  TextColumn get value => text().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}

class BackupLogs extends Table {
  IntColumn get id => integer().autoIncrement()();

  DateTimeColumn get backupTime => dateTime()();

  TextColumn get filePath => text().nullable()();

  TextColumn get status => textEnum<BackupStatus>()();

  TextColumn get notes => text().nullable()();
}

@TableIndex(name: 'sync_queue_status_idx', columns: {#status})
@TableIndex(name: 'sync_queue_created_at_idx', columns: {#createdAt})
class SyncQueueEntries extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get idempotencyKey => text().unique()();

  /// 'sale', 'customer_payment', 'stock_adjustment', 'return', 'customer'
  TextColumn get entityType => text()();

  /// 'create', 'update', 'delete'
  TextColumn get action => text()();

  /// Serialized JSON payload of the action
  TextColumn get payloadJson => text()();

  /// HMAC-SHA256 signature for integrity validation
  TextColumn get payloadSignature => text()();

  /// 'pending', 'syncing', 'failed', 'synced'
  TextColumn get status => text().withDefault(const Constant('pending'))();

  IntColumn get retryCount => integer().withDefault(const Constant(0))();

  TextColumn get errorMessage => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
}

@DataClassName('StaffProductFeedbackRow')
@TableIndex(name: 'staff_feedbacks_branch_idx', columns: {#branchId})
@TableIndex(name: 'staff_feedbacks_status_idx', columns: {#status})
class StaffProductFeedbacks extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get productId =>
      integer().references(Products, #id, onDelete: KeyAction.cascade).nullable()();

  TextColumn get productName => text()();

  IntColumn get currentStock => integer().withDefault(const Constant(0))();

  IntColumn get staffUserId =>
      integer().references(Users, #id, onDelete: KeyAction.setNull).nullable()();

  TextColumn get staffUsername => text().withDefault(const Constant('Staff'))();

  IntColumn get branchId => integer().withDefault(const Constant(1))();

  /// 'urgent', 'normal', 'high_demand'
  TextColumn get urgency => text().withDefault(const Constant('normal'))();

  IntColumn get suggestedQuantity => integer().withDefault(const Constant(10))();

  TextColumn get notes => text().nullable()();

  /// 'pending', 'ordered', 'dismissed'
  TextColumn get status => text().withDefault(const Constant('pending'))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

