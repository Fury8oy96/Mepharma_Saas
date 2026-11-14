import 'dart:io';

import 'package:flutter/material.dart';
import '../../core/services/update_checker_service.dart';

class UpdateNotificationDialog extends StatefulWidget {
  final UpdateInfo updateInfo;
  final VoidCallback onDismissPermanently;

  const UpdateNotificationDialog({
    super.key,
    required this.updateInfo,
    required this.onDismissPermanently,
  });

  static Future<void> show(
    BuildContext context, {
    required UpdateInfo updateInfo,
    required VoidCallback onDismissPermanently,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => UpdateNotificationDialog(
        updateInfo: updateInfo,
        onDismissPermanently: onDismissPermanently,
      ),
    );
  }

  @override
  State<UpdateNotificationDialog> createState() =>
      _UpdateNotificationDialogState();
}

class _UpdateNotificationDialogState extends State<UpdateNotificationDialog> {
  bool _downloading = false;
  bool _installing = false;
  double _progress = 0.0;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  String? _downloadError;

  Future<void> _startDownload(bool isArabic) async {
    setState(() {
      _downloading = true;
      _downloadError = null;
      _progress = 0.0;
      _receivedBytes = 0;
      _totalBytes = 0;
    });

    final targetUrl = widget.updateInfo.downloadUrl;
    final filename = targetUrl.split('/').last.split('?').first;
    final cleanFilename = filename.endsWith('.exe')
        ? filename
        : 'MePharma_Setup_${widget.updateInfo.version}.exe';
    final tempPath =
        '${Directory.systemTemp.path}${Platform.pathSeparator}$cleanFilename';

    try {
      // 1. Check if local build installer already exists in known paths
      final localCandidates = [
        File('setup${Platform.pathSeparator}Output${Platform.pathSeparator}$cleanFilename'),
        File('d:${Platform.pathSeparator}mepharma${Platform.pathSeparator}setup${Platform.pathSeparator}Output${Platform.pathSeparator}$cleanFilename'),
        if (Platform.environment['USERPROFILE'] != null)
          File('${Platform.environment['USERPROFILE']}${Platform.pathSeparator}Downloads${Platform.pathSeparator}$cleanFilename'),
        File(tempPath),
      ];

      for (final candidate in localCandidates) {
        if (await candidate.exists()) {
          final stat = await candidate.stat();
          if (stat.size > 1024 * 1024) {
            setState(() {
              _progress = 1.0;
              _installing = true;
            });
            await Future.delayed(const Duration(milliseconds: 600));
            await UpdateCheckerService.launchInstallerAndExit(candidate.path);
            return;
          }
        }
      }

      // 2. Stream download from remote URL with chunked progress
      await UpdateCheckerService.downloadInstaller(
        downloadUrl: targetUrl,
        savePath: tempPath,
        onProgress: (received, total) {
          if (mounted) {
            setState(() {
              _receivedBytes = received;
              _totalBytes = total;
              if (total > 0) {
                _progress = received / total;
              }
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _installing = true;
        });
      }

      await Future.delayed(const Duration(milliseconds: 600));

      // 3. Launch installer in background product update mode and exit app
      await UpdateCheckerService.launchInstallerAndExit(tempPath);
    } catch (e) {
      if (mounted) {
        final errStr = e.toString();
        final is404 = errStr.contains('404');
        setState(() {
          _downloading = false;
          _downloadError = is404
              ? (isArabic
                  ? 'لم يتم العثور على حزمة التثبيت على خادم التحديثات (HTTP 404).\nيرجى التأكد من رفع ملف $cleanFilename كملف مرفق في Release v${widget.updateInfo.version} على GitHub.'
                  : 'Installer package not found on release server (HTTP 404).\nPlease ensure $cleanFilename is attached to Release v${widget.updateInfo.version} on GitHub.')
              : errStr;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final changelog = isArabic && widget.updateInfo.changelogAr.isNotEmpty
        ? widget.updateInfo.changelogAr
        : (widget.updateInfo.changelogEn.isNotEmpty
            ? widget.updateInfo.changelogEn
            : widget.updateInfo.changelogAr);

    final title = isArabic
        ? 'يتوفر تحديث جديد لـ MePharma'
        : 'New MePharma Update Available';
    final versionLabel = isArabic
        ? 'الإصدار ${widget.updateInfo.version} جاهز للتثبيت'
        : 'Version ${widget.updateInfo.version} is ready to install';
    final releaseDateLabel = isArabic
        ? 'تاريخ الإصدار: ${widget.updateInfo.releaseDate}'
        : 'Release Date: ${widget.updateInfo.releaseDate}';
    final changelogHeader =
        isArabic ? 'ما الجديد في هذا التحديث:' : "What's New in this update:";
    final downloadButtonText =
        isArabic ? 'تحميل وتثبيت التحديث' : 'Download & Install Now';
    final remindLaterText = isArabic ? 'تذكيري لاحقاً' : 'Remind Me Later';
    final ignoreVersionText =
        isArabic ? 'تخطي هذا الإصدار' : 'Skip this version';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.all(24),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.system_update_alt_rounded,
              color: theme.colorScheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  versionLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.updateInfo.releaseDate.isNotEmpty) ...[
              Text(
                releaseDateLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              changelogHeader,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant
                      .withValues(alpha: 0.5),
                ),
              ),
              padding: const EdgeInsets.all(12),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: changelog.length,
                separatorBuilder: (ctx, index) => const SizedBox(height: 6),
                itemBuilder: (ctx, index) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Icon(
                          Icons.check_circle_outline_rounded,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          changelog[index],
                          style:
                              theme.textTheme.bodyMedium?.copyWith(height: 1.3),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            if (_downloading || _installing) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer
                      .withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _installing
                              ? (isArabic
                                  ? 'اكتمل التحميل! جاري تطبيق التحديث...'
                                  : 'Download complete! Applying update...')
                              : (isArabic
                                  ? 'جاري تحميل التحديث في الخلفية...'
                                  : 'Downloading update in background...'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        if (_totalBytes > 0 && !_installing)
                          Text(
                            '${(_progress * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _installing
                            ? null
                            : (_totalBytes > 0 ? _progress : null),
                        minHeight: 6,
                      ),
                    ),
                    if (_totalBytes > 0 && !_installing) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${(_receivedBytes / (1024 * 1024)).toStringAsFixed(1)} MB / ${(_totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (_downloadError != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline,
                        color: Colors.red.shade800, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _downloadError!,
                        style: TextStyle(
                          color: Colors.red.shade900,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      actions: [
        TextButton(
          onPressed: (_downloading || _installing)
              ? null
              : () {
                  widget.onDismissPermanently();
                  Navigator.of(context).pop();
                },
          child: Text(
            ignoreVersionText,
            style: TextStyle(color: theme.colorScheme.outline),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_installing)
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  _downloading
                      ? (isArabic ? 'إلغاء' : 'Cancel')
                      : remindLaterText,
                ),
              ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: (_downloading || _installing)
                  ? null
                  : () => _startDownload(isArabic),
              icon: _downloading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_rounded, size: 18),
              label: Text(
                _downloadError != null
                    ? (isArabic ? 'إعادة المحاولة' : 'Retry Download')
                    : downloadButtonText,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
