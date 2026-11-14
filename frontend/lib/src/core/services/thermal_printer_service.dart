import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:win32/win32.dart' as win32;

import '../../domain/models/printer_config.dart';
import '../../domain/models/receipt_data.dart';
import '../../domain/repositories/settings_repository.dart';

/// Thrown when a receipt cannot be sent to the printer.
class PrinterException implements Exception {
  const PrinterException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Localized labels rendered on a receipt. Defaults to English so the printer
/// works even when no UI locale is available.
class ReceiptLabels {
  const ReceiptLabels({
    this.invoice = 'Invoice:',
    this.cashier = 'Cashier:',
    this.customer = 'Customer:',
    this.subtotal = 'Subtotal',
    this.discount = 'Discount',
    this.tax = 'Tax',
    this.total = 'TOTAL',
    this.paid = 'Paid',
    this.change = 'Change',
    this.onAccount = 'On account',
    this.thanks = 'Thank you for your purchase!',
  });

  final String invoice;
  final String cashier;
  final String customer;
  final String subtotal;
  final String discount;
  final String tax;
  final String total;
  final String paid;
  final String change;
  final String onAccount;
  final String thanks;
}

/// Generates ESC/POS bytes for receipts and sends them to a thermal printer,
/// either through the Windows print spooler (USB / installed drivers) or
/// directly over raw TCP (port 9100).
class ThermalPrinterService {
  ThermalPrinterService(this._settingsRepository);

  final SettingsRepository _settingsRepository;

  /// Returns the name of the default Windows printer, or empty string if none.
  static String getDefaultWindowsPrinter() {
    if (!Platform.isWindows) return '';
    final arena = Arena();
    try {
      final pcchBuffer = arena<win32.DWORD>()..value = 0;
      win32.GetDefaultPrinter(win32.PWSTR(nullptr), pcchBuffer);
      if (pcchBuffer.value > 0) {
        final pszBuffer = arena<Uint16>(pcchBuffer.value);
        final success = win32.GetDefaultPrinter(win32.PWSTR(pszBuffer.cast()), pcchBuffer);
        if (success) {
          return pszBuffer.cast<Utf16>().toDartString();
        }
      }
    } catch (_) {
    } finally {
      arena.releaseAll();
    }
    return '';
  }

  /// Lists all printers installed on this Windows machine.
  static List<String> getInstalledWindowsPrinters() {
    if (!Platform.isWindows) return const [];
    final arena = Arena();
    try {
      final pcbNeeded = arena<win32.DWORD>()..value = 0;
      final pcReturned = arena<win32.DWORD>()..value = 0;
      const flags = win32.PRINTER_ENUM_LOCAL | win32.PRINTER_ENUM_CONNECTIONS;
      win32.EnumPrinters(flags, win32.PCWSTR(nullptr), 2, nullptr, 0, pcbNeeded, pcReturned);
      if (pcbNeeded.value > 0) {
        final pBuffer = arena<Uint8>(pcbNeeded.value);
        final ok = win32.EnumPrinters(flags, win32.PCWSTR(nullptr), 2, pBuffer, pcbNeeded.value, pcbNeeded, pcReturned);
        if (ok.value) {
          final pPrinters = pBuffer.cast<win32.PRINTER_INFO_2>();
          final list = <String>[];
          for (var i = 0; i < pcReturned.value; i++) {
            list.add(pPrinters[i].pPrinterName.toDartString());
          }
          return list;
        }
      }
    } catch (_) {
    } finally {
      arena.releaseAll();
    }
    return const [];
  }

  /// Builds and sends the receipt. No-op when no printer is configured.
  Future<void> printReceipt(
    ReceiptData receipt, {
    ReceiptLabels labels = const ReceiptLabels(),
  }) async {
    var config = await _settingsRepository.getPrinterConfig();

    // Auto-discovery fallback: If no printer is explicitly configured yet,
    // or address is empty, detect installed Windows POS/thermal printers (e.g. POS-80) automatically.
    if ((config.type == PrinterType.none || config.address.trim().isEmpty) && Platform.isWindows) {
      final installed = getInstalledWindowsPrinters();
      final defaultPrinter = getDefaultWindowsPrinter();

      // Look for a thermal/POS printer first
      var detected = installed.firstWhere(
        (p) =>
            p.toUpperCase().contains('POS') ||
            p.toUpperCase().contains('THERMAL') ||
            p.toUpperCase().contains('RECEIPT'),
        orElse: () => '',
      );

      // If none found with POS keyword, but default printer is present, use default
      if (detected.isEmpty && defaultPrinter.isNotEmpty) {
        detected = defaultPrinter;
      }

      if (detected.isNotEmpty) {
        config = PrinterConfig(
          type: PrinterType.windows,
          address: detected,
          paperSize: detected.contains('58') ? '58' : '80',
        );
        // Save detected printer to local DB so subsequent prints are instantaneous
        await _settingsRepository.savePrinterConfig(config);
      }
    }

    if (config.type == PrinterType.none || config.address.trim().isEmpty) {
      return;
    }
    final bytes = await buildReceiptBytes(
      receipt,
      paperSize: config.paperSize,
      labels: labels,
    );
    switch (config.type) {
      case PrinterType.windows:
        await _printViaSpooler(bytes, config.address);
      case PrinterType.network:
        await _printViaNetwork(bytes, config.address, config.port);
      case PrinterType.none:
        break;
    }
  }

  /// Renders a receipt to raw ESC/POS bytes.
  ///
  /// Text is restricted to the printer's Latin-1-safe range; non-encodable
  /// characters are replaced (Arabic receipt glyphs need a CP1256 code page and
  /// are handled in a later phase).
  Future<Uint8List> buildReceiptBytes(
    ReceiptData receipt, {
    required String paperSize,
    ReceiptLabels labels = const ReceiptLabels(),
  }) async {
    final size = paperSize == '58' ? PaperSize.mm58 : PaperSize.mm80;
    final profile = await CapabilityProfile.load();
    final g = Generator(size, profile);
    final out = BytesBuilder();
    final store = receipt.store;
    final symbol = store.currencySymbol.isEmpty ? 'ج.س' : store.currencySymbol;

    String money(int cents) => _sanitize(_money(cents, symbol));

    out.add(g.reset());
    out.add(g.text(
      _sanitize(store.storeName.isEmpty ? 'Receipt' : store.storeName),
      styles: PosStyles(
        bold: true,
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    ));
    if (store.storeAddress.isNotEmpty) {
      out.add(g.text(
        _sanitize(store.storeAddress),
        styles: const PosStyles(align: PosAlign.center),
      ));
    }
    if (store.storePhone.isNotEmpty) {
      out.add(g.text(
        _sanitize('Tel: ${store.storePhone}'),
        styles: const PosStyles(align: PosAlign.center),
      ));
    }
    if (store.storeTaxId.isNotEmpty) {
      out.add(g.text(
        _sanitize('Tax ID: ${store.storeTaxId}'),
        styles: const PosStyles(align: PosAlign.center),
      ));
    }
    out.add(g.feed(1));
    out.add(g.hr());
    out.add(g.row([
      PosColumn(
        text: _sanitize('${labels.invoice} ${receipt.invoiceNumber}'),
        width: 6,
        styles: const PosStyles(bold: true),
      ),
      PosColumn(
        text: _sanitize(receipt.dateTime),
        width: 6,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]));
    out.add(g.row([
      PosColumn(
        text: _sanitize('${labels.cashier} ${receipt.cashierName}'),
        width: 6,
      ),
      PosColumn(
        text: _sanitize(receipt.paymentMethod),
        width: 6,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]));
    if (receipt.transactionReference != null && receipt.transactionReference!.isNotEmpty) {
      out.add(g.text(
        _sanitize('Txn Ref: ${receipt.transactionReference}'),
        styles: const PosStyles(align: PosAlign.left),
      ));
    }
    if (receipt.customerName != null && receipt.customerName!.isNotEmpty) {
      out.add(g.text(
        _sanitize('${labels.customer} ${receipt.customerName}'),
      ));
    }
    out.add(g.hr());
    for (final line in receipt.lines) {
      out.add(g.text(
        _sanitize(line.name),
        styles: const PosStyles(bold: true),
      ));
      out.add(g.row([
        PosColumn(
          text: _sanitize('${line.quantity} x ${_money(line.unitPrice, symbol)}'),
          width: 8,
        ),
        PosColumn(
          text: money(line.totalPrice),
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]));
    }
    out.add(g.hr());
    out.add(g.row([
      PosColumn(
        text: _sanitize(labels.subtotal),
        width: 6,
      ),
      PosColumn(
        text: money(receipt.subtotal),
        width: 6,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]));
    if (receipt.discount > 0) {
      out.add(g.row([
        PosColumn(
          text: _sanitize(labels.discount),
          width: 6,
        ),
        PosColumn(
          text: _sanitize('-${_money(receipt.discount, symbol)}'),
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]));
    }
    if (receipt.taxAmount > 0) {
      out.add(g.row([
        PosColumn(
          text: _sanitize(labels.tax),
          width: 6,
        ),
        PosColumn(
          text: money(receipt.taxAmount),
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]));
    }
    out.add(g.row([
      PosColumn(
        text: _sanitize(labels.total),
        width: 6,
        styles: PosStyles(bold: true),
      ),
      PosColumn(
        text: money(receipt.totalAmount),
        width: 6,
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]));
    if (receipt.paidAmount > 0) {
      out.add(g.row([
        PosColumn(
          text: _sanitize(labels.paid),
          width: 6,
        ),
        PosColumn(
          text: money(receipt.paidAmount),
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]));
      out.add(g.row([
        PosColumn(
          text: _sanitize(labels.change),
          width: 6,
        ),
        PosColumn(
          text: money(receipt.changeAmount),
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]));
    }
    // A credit sale shows the amount charged to the account instead of
    // Paid / Change.
    if (receipt.paidAmount <= 0 && receipt.totalAmount > 0) {
      out.add(g.row([
        PosColumn(
          text: _sanitize(labels.onAccount),
          width: 6,
        ),
        PosColumn(
          text: money(receipt.totalAmount),
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]));
    }
    out.add(g.feed(1));
    if (store.receiptFooter.isNotEmpty) {
      final footer = _sanitize(store.receiptFooter);
      if (footer.isNotEmpty) {
        out.add(g.text(
          footer,
          styles: const PosStyles(align: PosAlign.center),
        ));
      }
    }
    final thanks = _sanitize(labels.thanks);
    out.add(g.text(
      thanks.isNotEmpty ? thanks : 'Thank you for your purchase!',
      styles: const PosStyles(align: PosAlign.center),
    ));
    out.add(g.feed(3));
    out.add(g.cut());
    return out.toBytes();
  }

  @visibleForTesting
  static String formatMoneyForTest(int amount, String symbol) {
    final sign = amount < 0 ? '-' : '';
    final abs = amount.abs();
    final digits = abs.toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buf.write(',');
      }
      buf.write(digits[i]);
    }
    final cleanSymbol = symbol.trim();
    return cleanSymbol.isEmpty ? '$sign$buf' : '$sign$cleanSymbol $buf';
  }

  String _money(int amount, String symbol) =>
      formatMoneyForTest(amount, symbol);

  String _sanitize(String value) {
    if (value.isEmpty) return '';
    var text = value
        .replaceAll('٠', '0')
        .replaceAll('١', '1')
        .replaceAll('٢', '2')
        .replaceAll('٣', '3')
        .replaceAll('٤', '4')
        .replaceAll('٥', '5')
        .replaceAll('٦', '6')
        .replaceAll('٧', '7')
        .replaceAll('٨', '8')
        .replaceAll('٩', '9')
        .replaceAll('نقداً', 'Cash')
        .replaceAll('نقد', 'Cash')
        .replaceAll('بطاقة', 'Card')
        .replaceAll('تحويل بنكي', 'Bank Transfer')
        .replaceAll('رقم العملية:', 'Txn Ref:')
        .replaceAll('رقم العملية', 'Txn Ref')
        .replaceAll('ج.س', 'SDG')
        .replaceAll('على الحساب', 'On Account')
        .replaceAll('المجموع الفرعي', 'Subtotal')
        .replaceAll('المجموع', 'Total')
        .replaceAll('الخصم', 'Discount')
        .replaceAll('الضريبة', 'Tax')
        .replaceAll('الإجمالي', 'TOTAL')
        .replaceAll('الاجمالي', 'TOTAL')
        .replaceAll('المدفوع', 'Paid')
        .replaceAll('المتبقي', 'Change')
        .replaceAll('فاتورة:', 'Invoice:')
        .replaceAll('فاتورة', 'Invoice')
        .replaceAll('الكاشير:', 'Cashier:')
        .replaceAll('الكاشير', 'Cashier')
        .replaceAll('العميل:', 'Customer:')
        .replaceAll('العميل', 'Customer')
        .replaceAll('شكراً لتعاملكم معنا!', 'Thank you for your purchase!')
        .replaceAll('شكراً', 'Thank you');

    return text.replaceAll(RegExp(r'[^\x20-\x7E]'), '');
  }

  Future<void> _printViaSpooler(Uint8List bytes, String printerName) async {
    final name = printerName.trim();
    if (name.isEmpty) {
      throw const PrinterException('No printer selected.');
    }
    try {
      final arena = Arena();
      try {
        final phPrinter = arena<Pointer>();
        final opened = win32.OpenPrinter(
          win32.PCWSTR(arena.pcwstr(name)),
          phPrinter,
          nullptr,
        );
        if (!opened.value || phPrinter.value == nullptr) {
          throw PrinterException('Cannot open printer "$name" (Error ${opened.error}).');
        }
        final handle = win32.PRINTER_HANDLE(phPrinter.value);
        try {
          final docInfo = arena<win32.DOC_INFO_1>();
          docInfo.ref.pDocName = win32.PWSTR(arena.pwstr('MePharma Receipt'));
          docInfo.ref.pDatatype = win32.PWSTR(arena.pwstr('RAW'));
          docInfo.ref.pOutputFile = win32.PWSTR(arena.pwstr(''));
          final jobId = win32.StartDocPrinter(handle, 1, docInfo);
          if (jobId == 0) {
            throw PrinterException('Failed to start print job (Error ${win32.GetLastError()}).');
          }
          try {
            win32.StartPagePrinter(handle);
            final written = arena<Uint32>();
            final buffer = arena<Uint8>(bytes.length);
            buffer.asTypedList(bytes.length).setAll(0, bytes);
            final ok = win32.WritePrinter(
              handle,
              buffer,
              bytes.length,
              written,
            );
            win32.EndPagePrinter(handle);
            if (!ok) {
              throw const PrinterException('Failed to write to printer.');
            }
          } finally {
            win32.EndDocPrinter(handle);
          }
        } finally {
          win32.ClosePrinter(handle);
        }
      } finally {
        arena.releaseAll();
      }
    } on win32.WindowsException catch (e) {
      throw PrinterException('Printing failed: ${e.message}');
    }
  }

  Future<void> _printViaNetwork(
    Uint8List bytes,
    String host,
    int port,
  ) async {
    final address = host.trim();
    if (address.isEmpty) {
      throw const PrinterException('No printer address configured.');
    }
    try {
      final socket = await Socket.connect(
        address,
        port,
        timeout: const Duration(seconds: 10),
      );
      socket.add(bytes);
      await socket.flush();
      await socket.close();
    } on SocketException catch (e) {
      throw PrinterException('Cannot reach printer at $address:$port (${e.message}).');
    }
  }
}
