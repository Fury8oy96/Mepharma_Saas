import 'package:flutter/material.dart';
import '../../core/services/update_checker_service.dart';

class UpdateNotificationDialog extends StatelessWidget {
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
      barrierDismissible: true,
      builder: (ctx) => UpdateNotificationDialog(
        updateInfo: updateInfo,
        onDismissPermanently: onDismissPermanently,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final changelog = isArabic && updateInfo.changelogAr.isNotEmpty
        ? updateInfo.changelogAr
        : (updateInfo.changelogEn.isNotEmpty ? updateInfo.changelogEn : updateInfo.changelogAr);

    final title = isArabic ? 'يتوفر تحديث جديد لـ MePharma' : 'New MePharma Update Available';
    final versionLabel = isArabic
        ? 'الإصدار ${updateInfo.version} جاهز للتثبيت'
        : 'Version ${updateInfo.version} is ready to install';
    final releaseDateLabel = isArabic
        ? 'تاريخ الإصدار: ${updateInfo.releaseDate}'
        : 'Release Date: ${updateInfo.releaseDate}';
    final changelogHeader = isArabic ? 'ما الجديد في هذا التحديث:' : "What's New in this update:";
    final downloadButtonText = isArabic ? 'تحميل وتثبيت التحديث' : 'Download & Install Now';
    final remindLaterText = isArabic ? 'تذكيري لاحقاً' : 'Remind Me Later';
    final ignoreVersionText = isArabic ? 'تخطي هذا الإصدار' : 'Skip this version';

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
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (updateInfo.releaseDate.isNotEmpty) ...[
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
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
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
                          style: theme.textTheme.bodyMedium?.copyWith(height: 1.3),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      actions: [
        TextButton(
          onPressed: () {
            onDismissPermanently();
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
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(remindLaterText),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () {
                final targetUrl = updateInfo.downloadUrl.isNotEmpty
                    ? updateInfo.downloadUrl
                    : updateInfo.htmlUrl;
                UpdateCheckerService.launchUrl(targetUrl);
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.download_rounded, size: 18),
              label: Text(downloadButtonText),
            ),
          ],
        ),
      ],
    );
  }
}
