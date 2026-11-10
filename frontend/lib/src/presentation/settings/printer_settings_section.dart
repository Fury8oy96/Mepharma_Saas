import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/services/thermal_printer_service.dart';
import '../../domain/models/printer_config.dart';
import '../../domain/models/receipt_data.dart';
import '../../domain/models/store_settings.dart';
import '../../l10n/generated/app_localizations.dart';

/// Modal dialog for rapid thermal printer setup across the POS app.
class PrinterSettingsDialog extends StatelessWidget {
  const PrinterSettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const PrinterSettingsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.print_outlined,
                          color: theme.colorScheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.printerSettings,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            l10n.localeName.startsWith('ar') ? 'إعداد وتشخيص طابعة الإيصالات الحرارية' : 'Thermal POS Printer Setup & Diagnostic',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: PrinterSettingsSection(
                    onSaved: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Printer connection settings with auto-discovery and a test-print button.
class PrinterSettingsSection extends ConsumerStatefulWidget {
  const PrinterSettingsSection({super.key, this.onSaved});

  final VoidCallback? onSaved;

  @override
  ConsumerState<PrinterSettingsSection> createState() =>
      _PrinterSettingsSectionState();
}

class _PrinterSettingsSectionState
    extends ConsumerState<PrinterSettingsSection> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _portController = TextEditingController(text: '9100');

  PrinterType _type = PrinterType.none;
  String _paperSize = '80';
  bool _loading = true;
  bool _saving = false;
  bool _testing = false;

  List<String> _detectedPrinters = [];
  bool _discoveringPrinters = false;
  bool _isManualAddress = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _discoverPrinters() {
    if (!Platform.isWindows) return;
    setState(() => _discoveringPrinters = true);
    try {
      final names = ThermalPrinterService.getInstalledWindowsPrinters();
      if (mounted) {
        setState(() {
          _detectedPrinters = names;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _discoveringPrinters = false);
      }
    }
  }

  Future<void> _load() async {
    _discoverPrinters();
    final config =
        await ref.read(settingsRepositoryProvider).getPrinterConfig();
    if (!mounted) {
      return;
    }

    var currentType = config.type;
    var currentAddress = config.address;
    var currentPaperSize = config.paperSize;

    // Smart default: If no printer configured but a POS/thermal printer exists in Windows:
    if ((currentType == PrinterType.none || currentAddress.isEmpty) &&
        _detectedPrinters.isNotEmpty) {
      final posPrinter = _detectedPrinters.firstWhere(
        (p) =>
            p.toUpperCase().contains('POS') ||
            p.toUpperCase().contains('THERMAL') ||
            p.toUpperCase().contains('RECEIPT'),
        orElse: () => '',
      );
      if (posPrinter.isNotEmpty) {
        currentType = PrinterType.windows;
        currentAddress = posPrinter;
        currentPaperSize = posPrinter.contains('58') ? '58' : '80';
      }
    }

    setState(() {
      _type = currentType;
      _addressController.text = currentAddress;
      _portController.text = '${config.port}';
      _paperSize = currentPaperSize;
      _isManualAddress = currentAddress.isNotEmpty &&
          !_detectedPrinters.contains(currentAddress);
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      final config = _buildConfig();
      await ref.read(settingsRepositoryProvider).savePrinterConfig(config);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Text(l10n.saved),
            backgroundColor: Colors.teal.shade800,
          ));
        widget.onSaved?.call();
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

  Future<void> _testPrint() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    setState(() => _testing = true);
    try {
      await ref
          .read(settingsRepositoryProvider)
          .savePrinterConfig(_buildConfig());
      final store = await ref.read(settingsRepositoryProvider).getStoreSettings();
      await ref
          .read(thermalPrinterServiceProvider)
          .printReceipt(_testReceipt(store));
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Text(l10n.testReceiptSent),
            backgroundColor: Colors.teal.shade800,
          ));
      }
    } catch (e) {
      if (mounted) {
        final message = e is PrinterException ? e.message : l10n.printFailedMessage;
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Text(message),
            backgroundColor: Colors.red.shade800,
          ));
      }
    } finally {
      if (mounted) {
        setState(() => _testing = false);
      }
    }
  }

  PrinterConfig _buildConfig() {
    return PrinterConfig(
      type: _type,
      address: _addressController.text.trim(),
      port: int.tryParse(_portController.text.trim()) ?? 9100,
      paperSize: _paperSize,
    );
  }

  ReceiptData _testReceipt(StoreSettings store) {
    final line = ReceiptLine(
      name: store.storeName.isNotEmpty ? (store.receiptStyle == 'arabic' || store.receiptFont == 'Tajawal' ? 'عنصر فحص وتشخيص' : 'Diagnostic Test Item') : 'Diagnostic Test Item',
      quantity: 1,
      unitPrice: 100,
      totalPrice: 100,
    );
    return ReceiptData(
      store: store,
      invoiceNumber: 'TEST-${DateTime.now().millisecondsSinceEpoch % 10000}',
      dateTime: DateTime.now().toString().substring(0, 19),
      cashierName: 'Branch Manager',
      paymentMethod: 'Test Verification',
      lines: [line],
      subtotal: 100,
      discount: 0,
      taxAmount: 0,
      totalAmount: 100,
      paidAmount: 100,
      changeAmount: 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    if (_loading) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(),
      ));
    }

    final isNetwork = _type == PrinterType.network;
    final isWindows = _type == PrinterType.windows;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.print_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                l10n.printerSettings,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (Platform.isWindows && isWindows)
                TextButton.icon(
                  onPressed: _discoveringPrinters ? null : _discoverPrinters,
                  icon: _discoveringPrinters
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 16),
                  label: Text(l10n.localeName.startsWith('ar') ? 'فحص طابعات USB / ويندوز' : 'Scan USB/Windows Printers'),
                ),
            ],
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<PrinterType>(
            initialValue: _type,
            decoration: InputDecoration(
              labelText: l10n.printerType,
              prefixIcon: const Icon(Icons.print_outlined),
            ),
            items: [
              DropdownMenuItem(
                value: PrinterType.none,
                child: Text(l10n.printerNone),
              ),
              DropdownMenuItem(
                value: PrinterType.windows,
                child: Text(l10n.printerWindows),
              ),
              DropdownMenuItem(
                value: PrinterType.network,
                child: Text(l10n.printerNetwork),
              ),
            ],
            onChanged: (type) {
              setState(() {
                _type = type ?? PrinterType.none;
                if (_type == PrinterType.windows &&
                    _addressController.text.isEmpty &&
                    _detectedPrinters.isNotEmpty) {
                  _addressController.text = _detectedPrinters.first;
                }
              });
            },
          ),
          const SizedBox(height: 16),
          if (_type != PrinterType.none) ...[
            // Windows Printers list dropdown when available
            if (isWindows && _detectedPrinters.isNotEmpty && !_isManualAddress) ...[
              DropdownButtonFormField<String>(
                initialValue: _detectedPrinters.contains(_addressController.text)
                    ? _addressController.text
                    : (_detectedPrinters.isNotEmpty ? _detectedPrinters.first : null),
                decoration: InputDecoration(
                  labelText: l10n.localeName.startsWith('ar') ? 'طابعة الفواتير المكتشفة (ويندوز / USB)' : 'Detected Thermal / Windows Printer',
                  helperText: l10n.localeName.startsWith('ar') ? 'اختر تعريف طابعتك الحرارية من أجهزة ويندوز المثبتة' : 'Select your thermal printer driver from installed Windows devices',
                  prefixIcon: const Icon(Icons.usb),
                ),
                items: [
                  for (final name in _detectedPrinters)
                    DropdownMenuItem(
                      value: name,
                      child: Text(
                        name,
                        style: TextStyle(
                          fontWeight: (name.toUpperCase().contains('POS') ||
                                  name.toUpperCase().contains('THERMAL'))
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  DropdownMenuItem(
                    value: '__manual__',
                    child: Text(l10n.localeName.startsWith('ar') ? 'إدخال اسم الطابعة يدوياً...' : 'Enter printer name manually...'),
                  ),
                ],
                onChanged: (val) {
                  if (val == '__manual__') {
                    setState(() {
                      _isManualAddress = true;
                      _addressController.clear();
                    });
                  } else if (val != null) {
                    setState(() {
                      _addressController.text = val;
                      if (val.contains('58')) {
                        _paperSize = '58';
                      } else if (val.contains('80')) {
                        _paperSize = '80';
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
            ] else ...[
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: l10n.printerAddress,
                  hintText: isNetwork
                      ? l10n.printerAddressHintNetwork
                      : l10n.printerAddressHintWindows,
                  prefixIcon: Icon(
                    isNetwork ? Icons.wifi_outlined : Icons.usb,
                  ),
                  suffixIcon: (isWindows && _detectedPrinters.isNotEmpty)
                      ? IconButton(
                          icon: const Icon(Icons.list),
                          tooltip: l10n.localeName.startsWith('ar') ? 'اختيار من الطابعات المكتشفة' : 'Pick from detected printers',
                          onPressed: () {
                            setState(() => _isManualAddress = false);
                          },
                        )
                      : null,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.fieldRequired;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
            ],

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _paperSize,
                    decoration: InputDecoration(
                      labelText: l10n.paperSize,
                      prefixIcon: const Icon(Icons.straighten_outlined),
                    ),
                    items: [
                      DropdownMenuItem(value: '80', child: Text(l10n.localeName.startsWith('ar') ? '80 مم (كاونتر قياسي)' : '80mm (Standard POS)')),
                      DropdownMenuItem(value: '58', child: Text(l10n.localeName.startsWith('ar') ? '58 مم (مدمج متنقل)' : '58mm (Compact POS)')),
                    ],
                    onChanged: (value) {
                      setState(() => _paperSize = value ?? '80');
                    },
                  ),
                ),
                if (isNetwork) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _portController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.printerPort,
                        prefixIcon: const Icon(Icons.numbers),
                      ),
                      validator: (value) {
                        final port = int.tryParse(value?.trim() ?? '');
                        if (port == null || port <= 0 || port > 65535) {
                          return l10n.invalidNumber;
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: _testing ? null : _testPrint,
                  icon: _testing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.print_outlined),
                  label: Text(l10n.testPrint),
                ),
                const SizedBox(width: 12),
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
        ],
      ),
    );
  }
}
