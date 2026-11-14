import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
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
      : super(
          executor ??
              driftDatabase(
                name: AppConstants.databaseName,
                native: DriftNativeOptions(
                  databaseDirectory: getApplicationDocumentsDirectory,
                ),
              ),
        );

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
          await m.addColumn(sales, sales.transactionReference);
          await m.addColumn(purchases, purchases.transactionReference);
        }
      },
    );
  }
}

