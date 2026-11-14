import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../app/providers.dart';
import '../../data/db/enums.dart';
import '../../domain/models/backup_record.dart';
import '../../l10n/generated/app_localizations.dart';
import '../session/session_controller.dart';

class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  bool _busy = false;

  Future<void> _createBackup() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final record =
          await ref.read(backupServiceProvider).createBackup();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(content: Text(l10n.backupCreated(record.filePath ?? ''))),
        );
    } on Exception {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(l10n.backupFailed)));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _restore(BackupRecord record) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.restoreBackup),
        content: Text(
          l10n.confirmRestore(
            p.basename(record.filePath ?? ''),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.restoreBackup),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      final bytes =
          await ref.read(backupServiceProvider).readBackupBytes(record.id);
      // Close the current connection, swap the live file, and only then rebuild
      // the database provider so the new connection opens the restored file.
      await ref.read(databaseProvider).close();
      await ref.read(backupServiceProvider).replaceLiveDatabase(bytes);
      ref.invalidate(databaseProvider);
      ref.read(sessionProvider.notifier).logout();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(l10n.restoreComplete)));
      context.go('/login');
    } on Exception {
      ref.invalidate(databaseProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(l10n.restoreFailed)));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _delete(BackupRecord record) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(
          l10n.confirmDeleteBackup(p.basename(record.filePath ?? '')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(backupServiceProvider).deleteBackup(record.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(l10n.backupDeleted)));
    } on Exception {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(l10n.errorOccurred)));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final historyAsync = ref.watch(backupHistoryProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.backup_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  l10n.backup,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _busy ? null : _createBackup,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload_outlined),
                  label: Text(l10n.createBackup),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.backupsLocation,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: historyAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => Center(child: Text(l10n.errorOccurred)),
                  data: (records) => records.isEmpty
                      ? Center(
                          child: Text(
                            l10n.noBackups,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(8),
                          itemCount: records.length,
                          separatorBuilder: (_, _) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final record = records[index];
                            final success =
                                record.status == BackupStatus.success;
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: success
                                    ? theme.colorScheme.secondaryContainer
                                    : theme.colorScheme.errorContainer,
                                child: Icon(
                                  success
                                      ? Icons.done
                                      : Icons.error_outline,
                                ),
                              ),
                              title: Text(
                                record.filePath == null
                                    ? l10n.backupFailed
                                    : p.basename(record.filePath!),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                DateFormat.yMd(l10n.localeName)
                                    .add_Hm()
                                    .format(record.backupTime),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (success)
                                    TextButton.icon(
                                      onPressed: _busy
                                          ? null
                                          : () => _restore(record),
                                      icon: const Icon(
                                        Icons.settings_backup_restore,
                                        size: 18,
                                      ),
                                      label: Text(l10n.restoreBackup),
                                    ),
                                  IconButton(
                                    tooltip: l10n.delete,
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed:
                                        _busy ? null : () => _delete(record),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
