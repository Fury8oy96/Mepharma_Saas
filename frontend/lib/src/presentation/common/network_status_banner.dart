import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../core/services/network_monitor.dart';
import '../../l10n/generated/app_localizations.dart';

class NetworkStatusBanner extends ConsumerWidget {
  const NetworkStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final networkMonitor = ref.watch(networkMonitorProvider);
    final syncEngine = ref.watch(syncEngineProvider);
    final pendingCount = syncEngine.pendingCount;

    if (networkMonitor.state == NetworkState.online && pendingCount == 0) {
      return const SizedBox.shrink();
    }

    final isOffline = networkMonitor.isOffline;
    final isSyncing = networkMonitor.isSyncing;
    final lastError = networkMonitor.lastError;
    final hasError = !isOffline && !isSyncing && pendingCount > 0 && lastError != null;

    final bgColor = isOffline
        ? const Color(0xFFFFF4E5)
        : hasError
            ? const Color(0xFFFCE8E8)
            : (isSyncing ? const Color(0xFFE8F4FD) : const Color(0xFFEFF6FF));

    final borderColor = isOffline
        ? const Color(0xFFFFB84D)
        : hasError
            ? const Color(0xFFFCA5A5)
            : (isSyncing ? const Color(0xFF70B6F6) : const Color(0xFF93C5FD));

    final textColor = isOffline
        ? const Color(0xFF995A00)
        : hasError
            ? const Color(0xFF991B1B)
            : (isSyncing ? const Color(0xFF0F5B9E) : const Color(0xFF1E40AF));

    final iconData = isOffline
        ? Icons.cloud_off_rounded
        : hasError
            ? Icons.error_rounded
            : (isSyncing ? Icons.sync_rounded : Icons.cloud_upload_rounded);

    final l10n = AppLocalizations.of(context);

    final title = isOffline
        ? l10n.offlineModeBannerTitle
        : hasError
            ? l10n.syncFailedBannerTitle
            : (isSyncing
                ? l10n.networkRestoredBannerTitle
                : l10n.pendingSyncBannerTitle);

    final subtitle = isOffline
        ? (pendingCount > 0
            ? l10n.offlinePendingTransactions(pendingCount)
            : l10n.offlineModeBannerSubtitle)
        : hasError
            ? lastError
            : (isSyncing
                ? l10n.reconcilingRecordsSubtitle
                : l10n.pendingServerReconciliation(pendingCount));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          bottom: BorderSide(color: borderColor, width: 1.5),
        ),
      ),
      child: Row(
        children: [
          if (isSyncing)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation<Color>(textColor),
              ),
            )
          else
            Icon(iconData, color: textColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.85),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          if (isOffline)
            ElevatedButton.icon(
              onPressed: () async {
                final ok = await networkMonitor.checkConnectivity();
                if (ok) {
                  await syncEngine.triggerSync();
                }
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(l10n.checkConnection),
              style: ElevatedButton.styleFrom(
                backgroundColor: textColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            )
          else if (!isSyncing && pendingCount > 0)
            ElevatedButton.icon(
              onPressed: () async {
                await syncEngine.triggerSync();
              },
              icon: const Icon(Icons.sync_rounded, size: 16),
              label: Text(l10n.syncNow),
              style: ElevatedButton.styleFrom(
                backgroundColor: textColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
