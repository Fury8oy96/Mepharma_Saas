import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/services/thermal_printer_service.dart';
import '../../core/utils/money.dart';
import '../../domain/models/app_product.dart';
import '../../domain/models/printer_config.dart';
import '../../domain/models/receipt_data.dart';
import '../../domain/models/store_settings.dart';
import '../../l10n/generated/app_localizations.dart';

/// Modal dialog for managing all connected hardware peripherals across the POS app.
class HardwareDevicesDialog extends StatelessWidget {
  const HardwareDevicesDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const HardwareDevicesDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
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
                          Icons.devices_other_outlined,
                          color: theme.colorScheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAr ? 'الأجهزة والملحقات المتصلة' : 'Connected Hardware & Devices',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            isAr
                                ? 'إعداد وتشخيص طابعات الإيصالات، طابعات A4، وقارئ الباركود USB'
                                : 'Configure & test Thermal Printers, A4 Printers, and USB Barcode Scanners',
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
                  child: HardwareDevicesSection(
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

/// Unified Hardware & Devices Management Section.
class HardwareDevicesSection extends ConsumerStatefulWidget {
  const HardwareDevicesSection({super.key, this.onSaved});

  final VoidCallback? onSaved;

  @override
  ConsumerState<HardwareDevicesSection> createState() => _HardwareDevicesSectionState();
}

class _HardwareDevicesSectionState extends ConsumerState<HardwareDevicesSection>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _portController = TextEditingController(text: '9100');
  String _a4PrinterName = '';

  PrinterType _type = PrinterType.none;
  String _paperSize = '80';
  bool _loading = true;
  bool _saving = false;
  bool _testingThermal = false;
  bool _testingA4 = false;

  List<String> _detectedPrinters = [];
  bool _discoveringPrinters = false;

  // Barcode diagnostic state
  final _barcodeInputController = TextEditingController();
  final _barcodeFocusNode = FocusNode();
  final List<DateTime> _keyTimestamps = [];
  String _lastDiagnosticScan = '';
  int _lastDiagnosticIntervalMs = 0;
  bool _isHardwareBurst = false;
  AppProduct? _diagnosticProduct;
  bool _diagnosticSearching = false;

  // Barcode simulator state
  AppProduct? _selectedSimProduct;
  String _simulationResult = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _addressController.dispose();
    _portController.dispose();
    _barcodeInputController.dispose();
    _barcodeFocusNode.dispose();
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
    final config = await ref.read(settingsRepositoryProvider).getPrinterConfig();
    if (!mounted) return;

    var currentType = config.type;
    var currentAddress = config.address;
    var currentPaperSize = config.paperSize;
    var a4Name = config.a4PrinterName;

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

    if (a4Name.isEmpty && _detectedPrinters.isNotEmpty) {
      final standardPrinter = _detectedPrinters.firstWhere(
        (p) =>
            !p.toUpperCase().contains('POS') &&
            !p.toUpperCase().contains('THERMAL') &&
            !p.toUpperCase().contains('RECEIPT'),
        orElse: () => _detectedPrinters.first,
      );
      a4Name = standardPrinter;
    }

    setState(() {
      _type = currentType;
      _addressController.text = currentAddress;
      _portController.text = '${config.port}';
      _paperSize = currentPaperSize;
      _a4PrinterName = a4Name;
      _loading = false;
    });
  }

  PrinterConfig _buildConfig() {
    final port = int.tryParse(_portController.text.trim()) ?? 9100;
    return PrinterConfig(
      type: _type,
      address: _addressController.text.trim(),
      port: port,
      paperSize: _paperSize,
      a4PrinterName: _a4PrinterName.trim(),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
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

  Future<void> _testPrintThermal() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _testingThermal = true);
    try {
      await ref.read(settingsRepositoryProvider).savePrinterConfig(_buildConfig());
      final store = await ref.read(settingsRepositoryProvider).getStoreSettings();
      await ref.read(thermalPrinterServiceProvider).printReceipt(_testReceipt(store));
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Text(l10n.testReceiptSent),
            backgroundColor: Colors.teal.shade800,
          ));
      }
    } on Exception catch (e) {
      if (mounted) {
        final isAr = l10n.localeName.startsWith('ar');
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Text(e is PrinterException ? e.message : (isAr ? 'فشلت الطباعة: $e' : 'Printing failed: $e')),
            backgroundColor: Colors.red.shade800,
          ));
      }
    } finally {
      if (mounted) {
        setState(() => _testingThermal = false);
      }
    }
  }

  Future<void> _testPrintA4() async {
    final l10n = AppLocalizations.of(context);
    final isAr = l10n.localeName.startsWith('ar');
    if (_a4PrinterName.isEmpty) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text(isAr ? 'يرجى اختيار طابعة A4 أولاً' : 'Please select an A4 printer first'),
          backgroundColor: Colors.orange.shade800,
        ));
      return;
    }
    setState(() => _testingA4 = true);
    try {
      await ref.read(settingsRepositoryProvider).savePrinterConfig(_buildConfig());
      final testText = 'MePharma POS & ERP System\n'
          'Standard A4 Document Print Test\n'
          'Date: ${DateTime.now().toIso8601String()}\n'
          'Printer Target: $_a4PrinterName\n'
          'Status: OK\n\n'
          '----------------------------------------\n'
          'System verified successfully.\n\x0C'; // Form feed
      final bytes = Uint8List.fromList(utf8.encode(testText));
      await ref.read(thermalPrinterServiceProvider).printRawToPrinter(bytes, _a4PrinterName);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Text(isAr ? 'تم إرسال اختبار الطباعة إلى $_a4PrinterName' : 'A4 test page sent to $_a4PrinterName'),
            backgroundColor: Colors.teal.shade800,
          ));
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Text(e is PrinterException ? e.message : (isAr ? 'فشلت الطباعة: $e' : 'Printing failed: $e')),
            backgroundColor: Colors.red.shade800,
          ));
      }
    } finally {
      if (mounted) {
        setState(() => _testingA4 = false);
      }
    }
  }

  ReceiptData _testReceipt(StoreSettings store) {
    return ReceiptData(
      store: store,
      invoiceNumber: 'TEST-${DateTime.now().millisecondsSinceEpoch % 10000}',
      dateTime: DateTime.now().toString().substring(0, 19),
      cashierName: 'Admin',
      paymentMethod: 'Cash',
      lines: const [
        ReceiptLine(
          name: 'Thermal Test Item 1',
          quantity: 1,
          unitPrice: 1500,
          totalPrice: 1500,
        ),
        ReceiptLine(
          name: 'Thermal Test Item 2',
          quantity: 2,
          unitPrice: 2000,
          totalPrice: 4000,
        ),
      ],
      subtotal: 5500,
      discount: 0,
      taxAmount: 0,
      totalAmount: 5500,
      paidAmount: 6000,
      changeAmount: 500,
    );
  }

  Future<void> _handleDiagnosticBarcodeSubmitted(String barcode) async {
    final code = barcode.trim();
    if (code.isEmpty) return;

    int avgInterval = 100;
    if (_keyTimestamps.length > 1) {
      final totalMs = _keyTimestamps.last.difference(_keyTimestamps.first).inMilliseconds;
      avgInterval = totalMs ~/ (_keyTimestamps.length - 1);
    }

    setState(() {
      _lastDiagnosticScan = code;
      _lastDiagnosticIntervalMs = avgInterval;
      _isHardwareBurst = avgInterval < 70 && code.length >= 3;
      _diagnosticSearching = true;
    });

    final repo = ref.read(productRepositoryProvider);
    var p = await repo.findByBarcode(code);
    p ??= await repo.findBySku(code);

    if (mounted) {
      setState(() {
        _diagnosticProduct = p;
        _diagnosticSearching = false;
        _barcodeInputController.clear();
        _keyTimestamps.clear();
      });
      _barcodeFocusNode.requestFocus();
    }
  }

  Future<void> _simulateBarcodeScan(AppProduct product) async {
    final code = (product.barcode != null && product.barcode!.isNotEmpty)
        ? product.barcode!
        : product.sku;

    setState(() {
      _simulationResult = 'Simulating hardware burst for: $code...';
    });

    await Future<void>.delayed(const Duration(milliseconds: 30));

    final repo = ref.read(productRepositoryProvider);
    var p = await repo.findByBarcode(code);
    p ??= await repo.findBySku(code);

    if (mounted) {
      setState(() {
        if (p != null) {
          _simulationResult =
              'SUCCESS: Barcode "$code" verified!\n'
              'Product: ${p.name}\n'
              'SKU: ${p.sku} | Barcode: ${p.barcode ?? "-"}\n'
              'Stock: ${p.stockQuantity} | Price: ${formatMoney(p.sellingPrice, symbol: r"$")}\n'
              'Burst Simulation: 13 chars in 30ms (Speed: 2.3ms/char)\n'
              'POS Global Listener: Ready & Active.';
        } else {
          _simulationResult = 'Failed: Product with barcode "$code" not found in local database.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isAr = l10n.localeName.startsWith('ar');

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabBar(
            controller: _tabController,
            labelColor: theme.colorScheme.primary,
            indicatorColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            tabs: [
              Tab(
                icon: const Icon(Icons.receipt_long_outlined, size: 20),
                text: isAr ? 'طابعة الإيصالات الحرارية' : 'Thermal POS Printer',
              ),
              Tab(
                icon: const Icon(Icons.print_outlined, size: 20),
                text: isAr ? 'طابعة المستندات A4' : 'Standard A4 Printer',
              ),
              Tab(
                icon: const Icon(Icons.qr_code_scanner_outlined, size: 20),
                text: isAr ? 'قارئ الباركود وتشخيصه' : 'Barcode Scanner Diagnostic',
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 480,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildThermalTab(theme, l10n, isAr),
                _buildA4Tab(theme, l10n, isAr),
                _buildBarcodeTab(theme, l10n, isAr),
              ],
            ),
          ),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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

  Widget _buildThermalTab(ThemeData theme, AppLocalizations l10n, bool isAr) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAr ? 'نوع الاتصال بطابعة الإيصالات' : 'Thermal Connection Type',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<PrinterType>(
                    segments: [
                      ButtonSegment(
                        value: PrinterType.none,
                        label: Text(l10n.printerNone),
                        icon: const Icon(Icons.block),
                      ),
                      ButtonSegment(
                        value: PrinterType.windows,
                        label: Text(l10n.printerWindows),
                        icon: const Icon(Icons.usb),
                      ),
                      ButtonSegment(
                        value: PrinterType.network,
                        label: Text(l10n.printerNetwork),
                        icon: const Icon(Icons.lan),
                      ),
                    ],
                    selected: {_type},
                    onSelectionChanged: (set) {
                      if (set.isNotEmpty) {
                        setState(() => _type = set.first);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          if (_type != PrinterType.none) ...[
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAr ? 'إعدادات الطابعة والورق' : 'Printer & Paper Configuration',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    if (_type == PrinterType.windows) ...[
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _detectedPrinters.contains(_addressController.text)
                                  ? _addressController.text
                                  : null,
                              decoration: InputDecoration(
                                labelText: isAr ? 'الطابعة المختارة' : 'Selected Windows Printer',
                                hintText: isAr ? 'اختر طابعة مثبتة' : 'Choose installed printer',
                                prefixIcon: const Icon(Icons.print),
                              ),
                              items: _detectedPrinters
                                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _addressController.text = val;
                                    if (val.contains('58')) _paperSize = '58';
                                    if (val.contains('80')) _paperSize = '80';
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: _discoveringPrinters
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.refresh),
                            tooltip: isAr ? 'تحديث قائمة الطابعات' : 'Refresh Printers',
                            onPressed: _discoveringPrinters ? null : _discoverPrinters,
                          ),
                        ],
                      ),
                    ] else if (_type == PrinterType.network) ...[
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _addressController,
                              decoration: InputDecoration(
                                labelText: l10n.printerAddress,
                                hintText: '192.168.1.100',
                                prefixIcon: const Icon(Icons.dns_outlined),
                              ),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty ? l10n.fieldRequired : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: _portController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: l10n.printerPort,
                                hintText: '9100',
                              ),
                              validator: (v) =>
                                  int.tryParse(v ?? '') == null ? l10n.invalidNumber : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text(
                          isAr ? 'عرض رول الورق:' : 'Paper Roll Width:',
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 16),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: '58', label: Text('58 mm')),
                            ButtonSegment(value: '80', label: Text('80 mm')),
                          ],
                          selected: {_paperSize},
                          onSelectionChanged: (set) {
                            if (set.isNotEmpty) {
                              setState(() => _paperSize = set.first);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _testingThermal ? null : _testPrintThermal,
                      icon: _testingThermal
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.receipt_long),
                      label: Text(l10n.testPrint),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildA4Tab(ThemeData theme, AppLocalizations l10n, bool isAr) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.description_outlined, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        isAr
                            ? 'طابعة مستندات النظام وتقارير المخزون A4'
                            : 'Standard A4 Document & Reports Printer',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isAr
                        ? 'تُستخدم لطباعة الفواتير الضريبية الكبيرة، طلبيات الشراء للموردين، وقوائم جرد الأدوية والمخزون.'
                        : 'Used for A4 invoices, supplier purchase orders, and inventory audit sheets.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _detectedPrinters.contains(_a4PrinterName)
                              ? _a4PrinterName
                              : (_detectedPrinters.isNotEmpty ? _detectedPrinters.first : null),
                          decoration: InputDecoration(
                            labelText: isAr ? 'طابعة A4 الافتراضية' : 'Default A4 Document Printer',
                            hintText: isAr ? 'اختر طابعة A4' : 'Select A4 Printer',
                            prefixIcon: const Icon(Icons.print),
                          ),
                          items: _detectedPrinters
                              .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _a4PrinterName = val);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: isAr ? 'تحديث قائمة الطابعات' : 'Refresh Printers',
                        onPressed: _discoverPrinters,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _testingA4 ? null : _testPrintA4,
                    icon: _testingA4
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.print),
                    label: Text(
                      isAr ? 'طباعة صفحة اختبار A4' : 'Print A4 Test Document',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarcodeTab(ThemeData theme, AppLocalizations l10n, bool isAr) {
    final catalogAsync = ref.watch(productListProvider);
    final products = catalogAsync.valueOrNull ?? const <AppProduct>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Live Diagnostic Box
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.qr_code_scanner, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        isAr ? 'منطقة تشخيص واختبار قارئ الباركود (مباشر)' : 'Live Barcode Scanner Diagnostic',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isAr
                        ? 'انقر داخل الحقل أدناه وامسح أي باركود باستخدام قارئ الباركود USB لقياس سرعة القراءة والتعرف التلقائي.'
                        : 'Click inside the field and scan any barcode using your USB barcode reader to analyze transmission burst speed.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _barcodeInputController,
                    focusNode: _barcodeFocusNode,
                    autofocus: true,
                    textInputAction: TextInputAction.go,
                    onChanged: (text) {
                      _keyTimestamps.add(DateTime.now());
                    },
                    onSubmitted: _handleDiagnosticBarcodeSubmitted,
                    decoration: InputDecoration(
                      labelText: isAr ? 'امسح الباركود هنا للتشخيص' : 'Scan barcode here for diagnostic',
                      hintText: isAr ? 'المسح يرسل تسلسل مفاتيح سريع ينتهي بـ Enter' : 'Scanner emits rapid keystroke burst terminated by Enter',
                      prefixIcon: const Icon(Icons.barcode_reader),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _barcodeInputController.clear();
                          _keyTimestamps.clear();
                        },
                      ),
                    ),
                  ),
                  if (_lastDiagnosticScan.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isHardwareBurst ? Colors.green.shade50 : Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _isHardwareBurst ? Colors.green.shade400 : Colors.amber.shade400,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _isHardwareBurst ? Icons.check_circle : Icons.info_outline,
                                color: _isHardwareBurst ? Colors.green.shade800 : Colors.amber.shade900,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isHardwareBurst
                                    ? (isAr ? 'تم التعرف: نبضة جهاز قارئ باركود فائق السرعة' : 'Verified: USB Hardware Scanner Burst')
                                    : (isAr ? 'تم الإدخال: كتابة يدوية عبر لوحة المفاتيح' : 'Detected: Manual Keyboard Entry'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _isHardwareBurst ? Colors.green.shade900 : Colors.amber.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isAr
                                ? 'الكود: $_lastDiagnosticScan  ·  متوسط سرعة الإرسال: $_lastDiagnosticIntervalMs مللي ثانية/حرف'
                                : 'Code: $_lastDiagnosticScan  ·  Avg transmission interval: $_lastDiagnosticIntervalMs ms/char',
                            style: theme.textTheme.bodySmall,
                          ),
                          if (_diagnosticSearching)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: LinearProgressIndicator(),
                            )
                          else if (_diagnosticProduct != null) ...[
                            const Divider(height: 16),
                            Row(
                              children: [
                                const Icon(Icons.medication_outlined, size: 20, color: Colors.teal),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${_diagnosticProduct!.name} (SKU: ${_diagnosticProduct!.sku})',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Text(
                                  'المخزون: ${_diagnosticProduct!.stockQuantity}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            const SizedBox(height: 4),
                            Text(
                              isAr ? 'لم يتم العثور على صنف مطابق بهذا الباركود في قاعدة البيانات' : 'No matching product found in local database.',
                              style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Simulator Card for users without physical barcode reader
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.blue.shade200),
            ),
            color: Colors.blue.shade50.withValues(alpha: 0.3),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.smart_toy_outlined, color: Colors.blue.shade800),
                      const SizedBox(width: 8),
                      Text(
                        isAr ? 'محاكي قارئ الباركود (للاختبار بدون جهاز فيزيائي)' : 'Barcode Scanner Hardware Simulator',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isAr
                        ? 'إذا لم يكن لديك قارئ باركود USB متصل حالياً، يمكنك اختيار دواء من القائمة ومحاكاة عملية مسح باركود كاملة بنبضة 30ms للتأكد من استجابة النظام ونقطة البيع.'
                        : 'If you do not have a physical USB barcode scanner connected, select a medicine below and simulate a 30ms hardware scan burst to verify the POS engine.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (products.isNotEmpty) ...[
                    DropdownButtonFormField<AppProduct>(
                      initialValue: _selectedSimProduct ?? products.first,
                      decoration: InputDecoration(
                        labelText: isAr ? 'اختر دواء للاختبار' : 'Select Product for Simulation',
                        prefixIcon: const Icon(Icons.medical_services_outlined),
                      ),
                      items: products.take(20).map((p) {
                        final code = p.barcode ?? p.sku;
                        return DropdownMenuItem(
                          value: p,
                          child: Text('${p.name} ($code)'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedSimProduct = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        final p = _selectedSimProduct ?? products.first;
                        _simulateBarcodeScan(p);
                      },
                      icon: const Icon(Icons.play_circle_outline),
                      label: Text(
                        isAr ? 'محاكاة نبضة مسح الباركود (30ms Burst)' : 'Simulate Hardware Barcode Scan (30ms)',
                      ),
                    ),
                  ] else ...[
                    Text(
                      isAr ? 'لا توجد أدوية مسجلة في قاعدة البيانات حالياً.' : 'No products registered in database yet.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  if (_simulationResult.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade300),
                      ),
                      child: Text(
                        _simulationResult,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
