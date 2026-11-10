import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/device_identifier_service.dart';
import '../../domain/models/api_config.dart';
import '../common/language_switcher.dart';
import '../common/theme_mode_switcher.dart';

class SetupWizardPage extends ConsumerStatefulWidget {
  const SetupWizardPage({super.key});

  @override
  ConsumerState<SetupWizardPage> createState() => _SetupWizardPageState();
}

class _SetupWizardPageState extends ConsumerState<SetupWizardPage> {
  final _formKey = GlobalKey<FormState>();
  late DatabaseMode _selectedMode;
  late final TextEditingController _domainController;
  late final TextEditingController _licenseKeyController;

  bool _isActivating = false;
  String? _errorMessage;
  ApiConfig? _activatedConfig;
  String _hardwareId = 'Detecting...';

  @override
  void initState() {
    super.initState();
    final config = ref.read(apiConfigProvider);
    _selectedMode = config.mode;
    _domainController = TextEditingController(text: config.pharmacyDomain);
    _licenseKeyController = TextEditingController(text: config.licenseKey ?? '');
    _initHardwareId();
  }

  Future<void> _initHardwareId() async {
    final hwId = await DeviceIdentifierService.getHardwareId();
    if (mounted) {
      setState(() => _hardwareId = hwId);
    }
  }

  @override
  void dispose() {
    _domainController.dispose();
    _licenseKeyController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data != null && data.text != null && data.text!.trim().isNotEmpty) {
      setState(() {
        _licenseKeyController.text = data.text!.trim();
      });
    }
  }

  Future<void> _handleActivation() async {
    setState(() {
      _isActivating = true;
      _errorMessage = null;
      _activatedConfig = null;
    });

    final notifier = ref.read(apiConfigProvider.notifier);

    final result = await notifier.activateLicense(
      mode: _selectedMode,
      pharmacyDomain: _domainController.text.trim(),
      licenseKey: _licenseKeyController.text.trim(),
    );

    if (!mounted) return;

    setState(() {
      _isActivating = false;
      if (result.success && result.config != null) {
        _activatedConfig = result.config;
      } else {
        _errorMessage = result.error ?? 'Activation failed. Please check inputs.';
      }
    });
  }

  void _proceedToLogin() {
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary.withValues(alpha: 0.08),
              colorScheme.secondary.withValues(alpha: 0.04),
              colorScheme.surface,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(color: colorScheme.outlineVariant, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(36),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Top Switchers Bar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            ThemeModeSwitcher(),
                            LanguageSwitcher(),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Logo & Brand
                        Center(
                          child: Container(
                            width: 80,
                            height: 80,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.primary.withValues(alpha: 0.15),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.asset(
                                'assets/logo/logo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        Text(
                          '${AppConstants.appName} POS Initial Setup',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colorScheme.primary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Configure connection type, register hardware seat, and validate annual license.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Step 1: Mode Selection
                        Text(
                          '1. Setup & Connection Architecture',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SegmentedButton<DatabaseMode>(
                          segments: const [
                            ButtonSegment<DatabaseMode>(
                              value: DatabaseMode.onlineApi,
                              icon: Icon(Icons.cloud_outlined),
                              label: Text('Online Server / Cloud'),
                            ),
                            ButtonSegment<DatabaseMode>(
                              value: DatabaseMode.local,
                              icon: Icon(Icons.storage_outlined),
                              label: Text('Local SQLite (Offline)'),
                            ),
                          ],
                          selected: {_selectedMode},
                          onSelectionChanged: (set) {
                            if (set.isNotEmpty) {
                              setState(() {
                                _selectedMode = set.first;
                                _errorMessage = null;
                                _activatedConfig = null;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 20),

                        // Mode: Offline SQLite Standalone
                        if (_selectedMode == DatabaseMode.local) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: colorScheme.outlineVariant),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.offline_bolt_outlined, color: colorScheme.primary),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Standalone Local Database',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Runs entirely on this computer with an embedded SQLite database. No network server, Docker, or external license server required.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: _isActivating ? null : _handleActivation,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: _isActivating
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.check_circle_outline),
                            label: const Text(
                              'Save Configuration & Proceed to Counter',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                        ] else ...[
                          // Mode: Online Cloud / LAN
                          Text(
                            '2. Pharmacy Domain & Server Endpoint',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _domainController,
                            decoration: InputDecoration(
                              labelText: 'Pharmacy Domain or Base URL',
                              hintText: 'main.localhost:8000',
                              prefixIcon: const Icon(Icons.language_outlined),
                              helperText: 'E.g. main.localhost:8000, pharmacy1.mepharma.io, or LAN IP:port',
                              filled: true,
                              fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 18),

                          Text(
                            '3. Annual Cryptographic License Key',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _licenseKeyController,
                            maxLines: 2,
                            minLines: 1,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12.5,
                              letterSpacing: 0.4,
                            ),
                            decoration: InputDecoration(
                              labelText: 'License Token (LIC-...)',
                              hintText: 'LIC-eyJ...',
                              prefixIcon: const Icon(Icons.key_outlined),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.paste_outlined),
                                tooltip: 'Paste from clipboard',
                                onPressed: _pasteFromClipboard,
                              ),
                              helperText: 'Issued by system provider admin (valid for 1 year with hardware seat locking)',
                              filled: true,
                              fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Terminal Hardware Fingerprint Chip
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.desktop_windows_outlined, size: 18, color: colorScheme.primary),
                                const SizedBox(width: 8),
                                Text(
                                  'Detected Terminal Seat Hardware UUID:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: SelectableText(
                                    _hardwareId,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Color(0xFF38BDF8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Action: Verify License Button
                          FilledButton.icon(
                            onPressed: _isActivating ? null : _handleActivation,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: _isActivating
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                  )
                                : const Icon(Icons.verified_outlined),
                            label: Text(
                              _isActivating ? 'Verifying License & Connecting...' : 'Verify License & Connect',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                        ],

                        // Error Banner
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: colorScheme.errorContainer.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: colorScheme.error.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.error_outline, color: colorScheme.error, size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      color: colorScheme.onErrorContainer,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Success Verified Pharmacy Card
                        if (_activatedConfig != null) ...[
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: const Color(0xFF064E3B).withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF10B981), width: 1.5),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 22),
                                    const SizedBox(width: 10),
                                    Text(
                                      'License Verified & Terminal Registered',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        color: const Color(0xFF10B981),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        _activatedConfig!.licensePlan?.toUpperCase() ?? 'ACTIVE',
                                        style: const TextStyle(
                                          color: Color(0xFF10B981),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                                _infoRow(
                                  Icons.local_pharmacy_outlined,
                                  'Pharmacy Name',
                                  _activatedConfig!.pharmacyName ?? 'Central Pharmacy',
                                ),
                                const SizedBox(height: 8),
                                _infoRow(
                                  Icons.place_outlined,
                                  'Store Address',
                                  _activatedConfig!.pharmacyAddress ?? 'N/A',
                                ),
                                const SizedBox(height: 8),
                                _infoRow(
                                  Icons.phone_outlined,
                                  'Phone & Contact',
                                  _activatedConfig!.pharmacyPhone ?? 'N/A',
                                ),
                                const SizedBox(height: 8),
                                _infoRow(
                                  Icons.monetization_on_outlined,
                                  'Currency & Tax',
                                  '${_activatedConfig!.currency ?? "USD"} (${_activatedConfig!.currencySymbol ?? r"$"}) • Tax: ${_activatedConfig!.taxRate ?? 0}%',
                                ),
                                const SizedBox(height: 8),
                                _infoRow(
                                  Icons.event_available_outlined,
                                  'Annual Validity',
                                  '${_activatedConfig!.validityDaysRemaining ?? 365} Days Remaining',
                                ),
                                const SizedBox(height: 8),
                                _infoRow(
                                  Icons.point_of_sale_outlined,
                                  'Hardware Seat',
                                  'Terminal Seat #${_activatedConfig!.seatNumber ?? 1}',
                                ),
                                const SizedBox(height: 18),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: _proceedToLogin,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF10B981),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: const Icon(Icons.arrow_forward),
                                    label: const Text(
                                      'Proceed to Terminal Login',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white70),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 12.5, color: Colors.white70),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
