import 'package:barcode/barcode.dart';

enum BarcodeSymbologyType {
  code128('Code 128', 'Alphanumeric high-density pharmacy standard', 'PAN-PAR-500MG'),
  ean13('EAN-13', '13-digit international retail trade', '6291100123456'),
  upcA('UPC-A', '12-digit North American retail standard', '012345678905'),
  ean8('EAN-8', '8-digit small package & vial barcode', '62912345'),
  upcE('UPC-E', 'Compact zero-suppressed 8-digit barcode', '01234565'),
  code39('Code 39', 'Alphanumeric hospital inventory & clinical supplies', 'MED-10023'),
  code93('Code 93', 'High density alphanumeric with dual check digits', 'RX-90442'),
  itf('ITF (Interleaved 2 of 5)', 'Numeric pairs for shipping cartons & cases', '10012345678902'),
  codabar('Codabar (NW-7)', 'Blood bank, lab specimens and medical test tubes', 'A1234567B'),
  gs1DataBar('GS1 DataBar / GS1-128', 'Healthcare unit-dose blister packs & GTINs', '(01)06291100123456'),
  msiPlessey('MSI Plessey', 'Shelf tags and retail warehouse inventory', '1234567');

  const BarcodeSymbologyType(this.name, this.description, this.sample);
  final String name;
  final String description;
  final String sample;

  Barcode toBarcode() {
    switch (this) {
      case BarcodeSymbologyType.code128:
        return Barcode.code128();
      case BarcodeSymbologyType.ean13:
        return Barcode.ean13();
      case BarcodeSymbologyType.upcA:
        return Barcode.upcA();
      case BarcodeSymbologyType.ean8:
        return Barcode.ean8();
      case BarcodeSymbologyType.upcE:
        return Barcode.upcE();
      case BarcodeSymbologyType.code39:
        return Barcode.code39();
      case BarcodeSymbologyType.code93:
        return Barcode.code93();
      case BarcodeSymbologyType.itf:
        return Barcode.itf();
      case BarcodeSymbologyType.codabar:
        return Barcode.codabar();
      case BarcodeSymbologyType.gs1DataBar:
        return Barcode.gs128();
      case BarcodeSymbologyType.msiPlessey:
        return Barcode.code128(); // fallback
    }
  }

  /// Validates and returns a Barcode renderer for [data], falling back gracefully
  /// to an appropriate compatible symbology or Code 128 if the format differs.
  Barcode toSafeBarcode(String data) {
    try {
      final b = toBarcode();
      b.verify(data);
      return b;
    } catch (_) {
      final detected = detect(data);
      try {
        final db = detected.toBarcode();
        db.verify(data);
        return db;
      } catch (_) {
        return Barcode.code128();
      }
    }
  }

  /// Automatically identifies the best matching 1D symbology for a barcode value.
  static BarcodeSymbologyType detect(String? data) {
    if (data == null || data.trim().isEmpty) return BarcodeSymbologyType.ean13;
    final clean = data.trim();
    final isNumeric = RegExp(r'^\d+$').hasMatch(clean);

    if (isNumeric) {
      if (clean.length == 14) return BarcodeSymbologyType.itf;
      if (clean.length == 13) return BarcodeSymbologyType.ean13;
      if (clean.length == 12) return BarcodeSymbologyType.upcA;
      if (clean.length == 8) return BarcodeSymbologyType.ean8;
    }
    if (clean.startsWith('(01)')) return BarcodeSymbologyType.gs1DataBar;
    if (RegExp(r'^[A-D][0-9\-\$\:\/\.\+]+[A-D]$').hasMatch(clean)) {
      return BarcodeSymbologyType.codabar;
    }
    return BarcodeSymbologyType.code128;
  }

  static int computeLuhnChecksum(String digits12) {
    int sum = 0;
    for (int i = 0; i < digits12.length; i++) {
      final digit = int.tryParse(digits12[i]) ?? 0;
      sum += i % 2 == 0 ? digit : digit * 3;
    }
    return (10 - (sum % 10)) % 10;
  }

  String generateInternalCode() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final sub = timestamp.length >= 6 ? timestamp.substring(timestamp.length - 6) : timestamp.padLeft(6, '0');
    final random = (100 + (DateTime.now().microsecond % 900)).toString();

    switch (this) {
      case BarcodeSymbologyType.ean13: {
        final base12 = '200$sub$random';
        final check = computeLuhnChecksum(base12);
        return '$base12$check';
      }
      case BarcodeSymbologyType.upcA: {
        final base11 = ('0$sub$random').substring(0, 11);
        final check = computeLuhnChecksum(base11);
        return '$base11$check';
      }
      case BarcodeSymbologyType.ean8: {
        final base7 = '20${sub.substring(sub.length - 5)}';
        int sum = 0;
        for (int i = 0; i < 7; i++) {
          final d = int.tryParse(base7[i]) ?? 0;
          sum += i % 2 == 0 ? d * 3 : d;
        }
        final check = (10 - (sum % 10)) % 10;
        return '$base7$check';
      }
      case BarcodeSymbologyType.itf: {
        final base13 = '10$sub$random'.padRight(13, '0').substring(0, 13);
        final check = computeLuhnChecksum(base13);
        return '$base13$check';
      }
      case BarcodeSymbologyType.codabar: {
        final inner = 'A$sub$random'.substring(0, 8);
        return '${inner}B';
      }
      case BarcodeSymbologyType.code39:
      case BarcodeSymbologyType.code93:
      case BarcodeSymbologyType.gs1DataBar:
      case BarcodeSymbologyType.msiPlessey:
      case BarcodeSymbologyType.code128:
      default: {
        return 'MED-$sub-$random';
      }
    }
  }
}
