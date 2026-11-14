import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/exceptions/auth_exception.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../domain/models/api_config.dart';
import '../common/language_switcher.dart';
import '../common/theme_mode_switcher.dart';
import '../session/session_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _submitting = false;
  AuthException? _authException;
  bool _showDetails = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _submitting = true;
      _authException = null;
      _showDetails = false;
    });

    try {
      await ref.read(sessionProvider.notifier).login(
            username: _usernameController.text.trim(),
            password: _passwordController.text,
          );
      // The router redirects to the dashboard once the session is set.
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _authException = e);
      }
    } catch (e, stack) {
      if (mounted) {
        setState(() => _authException = AuthException.unknown(
              message: e.toString(),
              details: 'Stack: $stack',
            ));
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  String _getErrorTypeBadge(AuthErrorType type) {
    switch (type) {
      case AuthErrorType.invalidCredentials:
        return 'AUTH_CREDENTIALS_INVALID (401)';
      case AuthErrorType.accountDeactivated:
        return 'ACCOUNT_DEACTIVATED (403)';
      case AuthErrorType.serverUnreachable:
        return 'SERVER_UNREACHABLE';
      case AuthErrorType.timeout:
        return 'NETWORK_TIMEOUT (10s)';
      case AuthErrorType.serverError:
        return 'SERVER_ERROR (${_authException?.statusCode ?? 500})';
      case AuthErrorType.dataParsingError:
        return 'DATA_PARSING_ERROR';
      case AuthErrorType.unknown:
        return 'GENERAL_EXCEPTION';
    }
  }

  IconData _getErrorIcon(AuthErrorType type) {
    switch (type) {
      case AuthErrorType.invalidCredentials:
        return Icons.lock_person_outlined;
      case AuthErrorType.accountDeactivated:
        return Icons.block_outlined;
      case AuthErrorType.serverUnreachable:
        return Icons.cloud_off_outlined;
      case AuthErrorType.timeout:
        return Icons.timer_off_outlined;
      case AuthErrorType.serverError:
        return Icons.dns_outlined;
      case AuthErrorType.dataParsingError:
        return Icons.code_off_outlined;
      case AuthErrorType.unknown:
        return Icons.error_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final apiConfig = ref.watch(apiConfigProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.08),
              theme.colorScheme.secondary.withValues(alpha: 0.04),
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(36),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            ThemeModeSwitcher(),
                            LanguageSwitcher(),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Container(
                            width: 100,
                            height: 100,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.asset(
                                'assets/logo/logo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          apiConfig.pharmacyName ?? AppConstants.appName,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.primary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          apiConfig.pharmacyAddress ?? l10n.appTitle,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Status & License Badges Row
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: apiConfig.mode == DatabaseMode.onlineApi
                                    ? Colors.cyan.withValues(alpha: 0.15)
                                    : Colors.purple.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: apiConfig.mode == DatabaseMode.onlineApi
                                      ? Colors.cyan.withValues(alpha: 0.4)
                                      : Colors.purple.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    apiConfig.mode == DatabaseMode.onlineApi
                                        ? Icons.cloud_outlined
                                        : Icons.storage_outlined,
                                    size: 13,
                                    color: apiConfig.mode == DatabaseMode.onlineApi
                                        ? Colors.cyanAccent
                                        : Colors.purpleAccent,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    apiConfig.mode == DatabaseMode.onlineApi
                                        ? (l10n.localeName.startsWith('ar')
                                            ? 'متصل أونلاين • ${apiConfig.pharmacyDomain}'
                                            : 'ONLINE • ${apiConfig.pharmacyDomain}')
                                        : (l10n.localeName.startsWith('ar')
                                            ? 'محلي • SQLite'
                                            : 'LOCAL • SQLite'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: apiConfig.mode == DatabaseMode.onlineApi
                                          ? Colors.cyanAccent
                                          : Colors.purpleAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (apiConfig.mode == DatabaseMode.onlineApi)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (apiConfig.isLicenseValid
                                          ? const Color(0xFF10B981)
                                          : theme.colorScheme.error)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: (apiConfig.isLicenseValid
                                            ? const Color(0xFF10B981)
                                            : theme.colorScheme.error)
                                        .withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      apiConfig.isLicenseValid
                                          ? Icons.verified_outlined
                                          : Icons.warning_amber_outlined,
                                      size: 13,
                                      color: apiConfig.isLicenseValid
                                          ? const Color(0xFF10B981)
                                          : theme.colorScheme.error,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      apiConfig.isLicenseValid
                                          ? '${apiConfig.validityDaysRemaining ?? 365}d left (${apiConfig.licensePlan?.toUpperCase() ?? "ENTERPRISE"})'
                                          : 'LICENSE INACTIVE',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: apiConfig.isLicenseValid
                                            ? const Color(0xFF10B981)
                                            : theme.colorScheme.error,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (apiConfig.seatNumber != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: theme.colorScheme.outlineVariant),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.point_of_sale_outlined, size: 13),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Seat #${apiConfig.seatNumber}',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _usernameController,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: l10n.username,
                            prefixIcon: const Icon(Icons.person_outline),
                            filled: true,
                            fillColor: theme.colorScheme.surfaceContainerHighest,
                          ),
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
                                  ? l10n.username
                                  : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: l10n.password,
                            prefixIcon: const Icon(Icons.lock_outline),
                            filled: true,
                            fillColor: theme.colorScheme.surfaceContainerHighest,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                          validator: (value) =>
                              (value == null || value.isEmpty) ? l10n.password : null,
                        ),

                        // Error Diagnostic Panel
                        if (_authException != null) ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: theme.colorScheme.error.withValues(alpha: 0.5),
                                width: 1.2,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _getErrorIcon(_authException!.type),
                                      color: theme.colorScheme.error,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _getErrorTypeBadge(_authException!.type),
                                        style: TextStyle(
                                          color: theme.colorScheme.error,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.copy, size: 16),
                                      tooltip: l10n.copyErrorDiagnostics,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(
                                          text: _authException.toString(),
                                        ));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(l10n.diagnosticsCopied),
                                            duration: const Duration(seconds: 2),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _authException!.message,
                                  style: TextStyle(
                                    color: theme.colorScheme.onErrorContainer,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                if (_authException!.technicalDetails != null || _authException!.endpoint != null) ...[
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: () => setState(() => _showDetails = !_showDetails),
                                    child: Row(
                                      children: [
                                        Text(
                                          _showDetails
                                              ? (l10n.localeName.startsWith('ar')
                                                  ? 'إخفاء التفاصيل التقنية'
                                                  : 'Hide technical trace')
                                              : (l10n.localeName.startsWith('ar')
                                                  ? 'عرض التفاصيل التقنية'
                                                  : 'Show technical trace'),
                                          style: TextStyle(
                                            color: theme.colorScheme.primary,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Icon(
                                          _showDetails ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                          size: 16,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_showDetails) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: theme.brightness == Brightness.dark
                                            ? theme.colorScheme.surfaceContainerHighest
                                            : const Color(0xFF0F172A),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: SelectableText(
                                        'Endpoint: ${_authException!.endpoint ?? apiConfig.baseUrl}\n'
                                        'Details: ${_authException!.technicalDetails ?? "N/A"}',
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 11,
                                          color: Color(0xFF38BDF8),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 28),
                        FilledButton.icon(
                          onPressed: _submitting ? null : _submit,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: _submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.login),
                          label: Text(
                            _submitting ? l10n.signingIn : l10n.signIn,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                            onPressed: () => context.go('/setup'),
                            icon: const Icon(Icons.tune_outlined, size: 16),
                            label: Text(
                              l10n.localeName.startsWith('ar')
                                  ? 'إعدادات الاتصال وتفعيل الترخيص أونلاين'
                                  : 'Terminal Setup & License Settings',
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
