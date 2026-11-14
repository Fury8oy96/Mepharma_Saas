import '../../data/db/enums.dart';

/// A recorded backup attempt.
class BackupRecord {
  const BackupRecord({
    required this.id,
    required this.backupTime,
    required this.status,
    this.filePath,
    this.notes,
  });

  final int id;
  final DateTime backupTime;
  final BackupStatus status;
  final String? filePath;
  final String? notes;
}
