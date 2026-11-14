import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../app/providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../session/session_controller.dart';
import '../../domain/models/api_config.dart';

class ServerSettingsSection extends ConsumerStatefulWidget {
  const ServerSettingsSection({super.key});

  @override
  ConsumerState<ServerSettingsSection> createState() =>
      _ServerSettingsSectionState();
}

class _ServerSettingsSectionState extends ConsumerState<ServerSettingsSection> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _branchController = TextEditingController();
  DatabaseMode _mode = DatabaseMode.local;

  bool _loading = true;
  bool _saving = false;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _branchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final config = ref.read(apiConfigProvider);
    setState(() {
      _mode = config.mode;
      _urlController.text = config.baseUrl;
      _branchController.text = '${config.branchId}';
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_mode == DatabaseMode.onlineApi && !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final prevMode = ref.read(apiConfigProvider).mode;
    setState(() => _saving = true);
    try {
      final url = _urlController.text.trim();
      final branchId = int.tryParse(_branchController.text.trim()) ?? 1;

      await ref.read(apiConfigProvider.notifier).updateConfig(
            mode: _mode,
            baseUrl: url,
            branchId: branchId,
            isConfigured: true,
          );

      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(l10n.saved)));
        if (prevMode != _mode) {
          ref.read(sessionProvider.notifier).logout();
          context.go('/login');
        }
      }
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(l10n.errorOccurred)));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _testConnection() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    setState(() => _testing = true);

    try {
      final rawUrl = _urlController.text.trim();
      // Test endpoint: health or status check
      final testUrl = rawUrl.endsWith('/')
          ? '${rawUrl}status'
          : '$rawUrl/status';
      final response = await http
          .get(Uri.parse(testUrl))
          .timeout(const Duration(seconds: 5));

      if (mounted) {
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: Text(l10n.apiConnected),
                backgroundColor: Colors.green,
              ),
            );
        } else {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  'Server responded with error status: ${response.statusCode}',
                ),
                backgroundColor: Colors.orange,
              ),
            );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(l10n.apiConnectionFailed),
              backgroundColor: Colors.red,
            ),
          );
      }
    } finally {
      if (mounted) {
        setState(() => _testing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isArabic = l10n.localeName.startsWith('ar');

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final isLocal = _mode == DatabaseMode.local;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.dns_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                l10n.serverSettings,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isArabic ? 'نمط التشغيل والاتصال' : 'Operation Mode',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<DatabaseMode>(
                    segments: [
                      ButtonSegment<DatabaseMode>(
                        value: DatabaseMode.local,
                        icon: const Icon(Icons.storage_outlined),
                        label: Text(isArabic ? 'محلي SQLite (بدون إنترنت)' : 'Local SQLite (Offline)'),
                      ),
                      ButtonSegment<DatabaseMode>(
                        value: DatabaseMode.onlineApi,
                        icon: const Icon(Icons.cloud_outlined),
                        label: Text(isArabic ? 'خادم سحابي مباشر (API)' : 'Online Server (API)'),
                      ),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (set) {
                      if (set.isNotEmpty) {
                        setState(() => _mode = set.first);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  if (isLocal)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: theme.colorScheme.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isArabic
                                  ? 'الوضع المحلي مفعل: جميع البيانات والمبيعات والمخزون وحسابات الموظفين محفوظة محلياً بأمان في قاعدة بيانات SQLite دون الحاجة لإنترنت أو خادم.'
                                  : 'Standalone Mode Active: All user data, inventory, transactions, and credentials are stored locally in SQLite without requiring internet or a remote server.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.vpn_key_outlined, color: theme.colorScheme.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isArabic
                                  ? 'للربط الكامل بالمنصة السحابية وتفعيل مفتاح الترخيص، يمكنك استخدام معالج التفعيل عبر البوابة.'
                                  : 'For full cloud onboarding and license activation, launch the Online Setup Portal.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () async {
                              await ref.read(apiConfigProvider.notifier).resetConfiguration();
                              ref.read(sessionProvider.notifier).logout();
                              if (context.mounted) {
                                context.go('/setup');
                              }
                            },
                            icon: const Icon(Icons.launch, size: 16),
                            label: Text(isArabic ? 'معالج الربط أونلاين' : 'Online Setup Portal'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (!isLocal) ...[
            const SizedBox(height: 20),
            TextFormField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: l10n.apiUrl,
                hintText: 'http://localhost:8000/api',
                prefixIcon: const Icon(Icons.link_outlined),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.fieldRequired;
                }
                final parsed = Uri.tryParse(value.trim());
                if (parsed == null || !parsed.hasScheme) {
                  return l10n.invalidUrl;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _branchController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.branchId,
                hintText: isArabic ? 'مثال: 1' : 'e.g. 1',
                prefixIcon: const Icon(Icons.store_outlined),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.fieldRequired;
                }
                final parsed = int.tryParse(value.trim());
                if (parsed == null || parsed <= 0) {
                  return l10n.invalidNumber;
                }
                return null;
              },
            ),
          ],
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!isLocal) ...[
                OutlinedButton.icon(
                  onPressed: _testing ? null : _testConnection,
                  icon: _testing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.swap_horiz_outlined),
                  label: Text(l10n.testConnection),
                ),
                const SizedBox(width: 12),
              ],
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(l10n.save),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
