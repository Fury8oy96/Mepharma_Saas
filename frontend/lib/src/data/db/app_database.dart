import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/constants/app_constants.dart';
import 'enums.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// Resolves the on-disk SQLite file the app uses. This is the single source of
/// truth for the database location so the connection and the backup service
/// always agree (drift_flutter defaults to the Documents directory).
Future<File> defaultDatabaseFilePath() async {
  final documents = await getApplicationDocumentsDirectory();
  return File(p.join(documents.path, '${AppConstants.databaseName}.sqlite'));
}

QueryExecutor _openConnection() {
  return LazyDatabase(() async {
    final file = await defaultDatabaseFilePath();
    return NativeDatabase.createInBackground(file);
  });
}

@DriftDatabase(
  tables: [
    Users,
    Categories,
    Suppliers,
    Products,
    Sales,
    SaleItems,
    Purchases,
    PurchaseItems,
    StockAdjustments,
    Returns,
    ReturnItems,
    SalesHolds,
    Settings,
    BackupLogs,
    Customers,
    CustomerPayments,
    SyncQueueEntries,
    StaffProductFeedbacks,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) => m.createAll(),
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          await m.createTable(customers);
          await m.createTable(customerPayments);
          await m.addColumn(sales, sales.customerId);
        }
        if (from < 3) {
          await m.createTable(syncQueueEntries);
        }
        if (from < 4) {
          await m.createTable(staffProductFeedbacks);
        }
        if (from < 5) {
          await m.addColumn(purchases, purchases.status);
          await m.addColumn(purchases, purchases.notes);
          await m.addColumn(sales, sales.transactionReference);
          await m.addColumn(purchases, purchases.transactionReference);
        }
      },
    );
  }

  /// Completely wipes all operational tables and resets to an empty database state.
  Future<void> wipeAndReset() async {
    await transaction(() async {
      await delete(saleItems).go();
      await delete(sales).go();
      await delete(salesHolds).go();
      await delete(purchaseItems).go();
      await delete(purchases).go();
      await delete(stockAdjustments).go();
      await delete(customerPayments).go();
      await delete(customers).go();
      await delete(products).go();
      await delete(categories).go();
      await delete(suppliers).go();
      await delete(staffProductFeedbacks).go();
      await delete(syncQueueEntries).go();
      await delete(backupLogs).go();
      await delete(settings).go();
      await delete(users).go();
    });
  }
}

