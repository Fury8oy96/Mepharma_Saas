import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/db/app_database.dart';
import '../../data/db/enums.dart';
import '../../domain/models/backup_record.dart';

/// Resolves where backups are stored and where the live database lives.
class BackupPaths {
  const BackupPaths({
    required this.backupsDirectory,
    required this.liveDatabaseFile,
  });

  /// Directory that will hold created backup files.
  final Future<Directory> Function() backupsDirectory;

  /// The on-disk SQLite file currently used by the app.
  final Future<File> Function() liveDatabaseFile;

  /// Default locations: backups under the documents folder, the live database
  /// where the app actually stores it (Documents directory — see
  /// `defaultDatabaseFilePath`).
  static const BackupPaths defaults = BackupPaths(
    backupsDirectory: _defaultBackupsDirectory,
    liveDatabaseFile: defaultDatabaseFilePath,
  );

  static Future<Directory> _defaultBackupsDirectory() async {
    // Priority 1: D:\MePharma Backups
    try {
      final dDrive = Directory(r'D:\MePharma Backups');
      if (Directory(r'D:\').existsSync()) {
        if (!dDrive.existsSync()) {
          dDrive.createSync(recursive: true);
        }
        return dDrive;
      }
    } catch (_) {}

    // Priority 2: C:\MePharma Backups
    try {
      final cDrive = Directory(r'C:\MePharma Backups');
      if (!cDrive.existsSync()) {
        cDrive.createSync(recursive: true);
      }
      return cDrive;
    } catch (_) {}

    // Fallback: Documents/MePharma Backups
    final documents = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(documents.path, 'MePharma Backups'));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }
}

/// Creates and restores database backups. File locations are injectable so the
/// service is testable; a copy of every attempt is recorded in [AppDatabase.backupLogs].
class BackupService {
  BackupService(this._db, {BackupPaths paths = BackupPaths.defaults})
      : _paths = paths;

  final AppDatabase _db;
  final BackupPaths _paths;

  /// Returns the resolved directory where backups are stored.
  Future<Directory> getBackupsDirectory() => _paths.backupsDirectory();

  /// Copies the live database to the backups folder and records the attempt.
  /// The database must be the primary connection so a WAL checkpoint flushes
  /// all data into the .sqlite file first.
  Future<BackupRecord> createBackup({String? customFileName}) async {
    final now = DateTime.now();
    try {
      await _db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
      final liveFile = await _paths.liveDatabaseFile();
      if (!await liveFile.exists()) {
        throw StateError('Database file not found: ${liveFile.path}');
      }
      final backupsDir = await _paths.backupsDirectory();
      await backupsDir.create(recursive: true);

      final fileName = customFileName ?? 'backup${_dayStamp(now)}.db';
      final target = File(p.join(backupsDir.path, fileName));
      if (await target.exists()) {
        await target.delete();
      }
      await liveFile.copy(target.path);

      final id = await _db.into(_db.backupLogs).insert(
            BackupLogsCompanion.insert(
              backupTime: now,
              filePath: Value(target.path),
              status: BackupStatus.success,
              notes: const Value(null),
            ),
          );
      return await _getRecord(id);
    } catch (e) {
      try {
        await _db.into(_db.backupLogs).insert(
              BackupLogsCompanion.insert(
                backupTime: now,
                filePath: const Value(null),
                status: BackupStatus.failed,
                notes: Value(e.toString()),
              ),
            );
      } catch (_) {
        // Logging the failure is best-effort.
      }
      rethrow;
    }
  }

  /// Automatically creates a daily backup if one hasn't been created yet today.
  /// Returns the created BackupRecord, or null if today's backup already exists.
  Future<BackupRecord?> createDailyAutoBackupIfNeeded() async {
    final now = DateTime.now();
    final dayStamp = _dayStamp(now);
    final targetName = 'backup$dayStamp.db';

    final backupsDir = await _paths.backupsDirectory();
    final targetFile = File(p.join(backupsDir.path, targetName));

    if (await targetFile.exists()) {
      // Already backed up today! Prevent duplicate work.
      return null;
    }

    return await createBackup(customFileName: targetName);
  }

  /// Restores a backup from a local file directly.
  Future<void> restoreFromFile(File file) async {
    if (!await file.exists()) {
      throw StateError('Backup file not found.');
    }
    final bytes = await file.readAsBytes();
    if (bytes.length < 16 ||
        String.fromCharCodes(bytes.sublist(0, 16)) != 'SQLite format 3\x00') {
      throw StateError('The selected file is not a valid MePharma database backup.');
    }
    await replaceLiveDatabase(bytes);
  }

  /// Verifies the backup file and returns its bytes ready to replace the live
  /// database.
  Future<Uint8List> readBackupBytes(int logId) async {
    final record = await _getRecord(logId);
    final path = record.filePath;
    if (path == null || !await File(path).exists()) {
      throw StateError('Backup file not found.');
    }
    final bytes = await File(path).readAsBytes();
    if (bytes.length < 16 ||
        String.fromCharCodes(bytes.sublist(0, 16)) != 'SQLite format 3\x00') {
      throw StateError('Backup file is not a valid database.');
    }
    return bytes;
  }

  /// Overwrites the live database file with [bytes], dropping any WAL sidecars.
  /// The live connection must be closed before calling this. The new file is
  /// written to a temporary sibling first so a mid-write failure cannot leave a
  /// truncated database behind.
  Future<void> replaceLiveDatabase(Uint8List bytes) async {
    final liveFile = await _paths.liveDatabaseFile();
    final wal = File('${liveFile.path}-wal');
    final shm = File('${liveFile.path}-shm');
    for (final sidecar in [wal, shm]) {
      if (await sidecar.exists()) {
        await sidecar.delete();
      }
    }
    final temp = File('${liveFile.path}.tmp');
    await temp.writeAsBytes(bytes, flush: true);
    if (await liveFile.exists()) {
      await liveFile.delete();
    }
    await temp.rename(liveFile.path);
  }

  /// Removes a log entry and its backup file if it still exists. The log row is
  /// removed first so a file-deletion failure cannot leave a stale history
  /// entry pointing at a missing file.
  Future<void> deleteBackup(int id) async {
    final record = await _getRecord(id);
    await (_db.delete(_db.backupLogs)..where((l) => l.id.equals(id))).go();
    final path = record.filePath;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Stream<List<BackupRecord>> watchLogs() {
    final query = _db.select(_db.backupLogs)
      ..orderBy([(l) => OrderingTerm.desc(l.backupTime)]);
    return query.watch().map((rows) => rows.map(_map).toList());
  }

  Future<BackupRecord> _getRecord(int id) async {
    final row = await (_db.select(_db.backupLogs)
          ..where((l) => l.id.equals(id)))
        .getSingle();
    return _map(row);
  }

  BackupRecord _map(BackupLog row) {
    return BackupRecord(
      id: row.id,
      backupTime: row.backupTime,
      filePath: row.filePath,
      status: row.status,
      notes: row.notes,
    );
  }

  static String _dayStamp(DateTime time) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${time.year}${two(time.month)}${two(time.day)}';
  }
}
