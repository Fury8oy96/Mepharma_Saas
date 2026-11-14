import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/csv_export.dart';
import '../utils/money.dart';

/// An in-memory snapshot of one product row for CSV export.
class ProductCsvRow {
  const ProductCsvRow({
    required this.sku,
    required this.name,
    this.barcode,
    required this.categoryName,
    required this.supplierName,
    required this.costPrice,
    required this.sellingPrice,
    required this.stockQuantity,
    required this.lowStockThreshold,
    this.expiryDate,
    this.description,
  });

  final String sku;
  final String name;
  final String? barcode;
  final String categoryName;
  final String supplierName;
  final int costPrice;
  final int sellingPrice;
  final int stockQuantity;
  final int lowStockThreshold;
  final DateTime? expiryDate;
  final String? description;

  /// All cells as a CSV data line (no trailing newline).
  List<String> toCells() => [
    sku,
    name,
    barcode ?? '',
    categoryName,
    supplierName,
    formatCents(costPrice),
    formatCents(sellingPrice),
    '$stockQuantity',
    '$lowStockThreshold',
    expiryDate == null ? '' : DateFormat('yyyy-MM-dd').format(expiryDate!),
    description ?? '',
  ];
}

/// A parsed row ready to be upserted.
class ProductImportRow {
  const ProductImportRow({
    required this.sku,
    required this.name,
    this.barcode,
    required this.categoryName,
    required this.supplierName,
    required this.costPrice,
    required this.sellingPrice,
    required this.stockQuantity,
    required this.lowStockThreshold,
    this.expiryDate,
    this.description,
  });

  final String sku;
  final String name;
  final String? barcode;
  final String categoryName;
  final String supplierName;
  final int costPrice;
  final int sellingPrice;
  final int stockQuantity;
  final int lowStockThreshold;
  final DateTime? expiryDate;
  final String? description;
}

class ProductImportResult {
  const ProductImportResult({required this.rows, required this.errors});

  final List<ProductImportRow> rows;

  /// `(line, message)` pairs for unparsable lines.
  final List<(int, String)> errors;
}

/// Shared CSV columns for products. The header is written on export and must be
/// present on import.
const List<String> productCsvHeader = [
  'sku',
  'name',
  'barcode',
  'category',
  'supplier',
  'cost',
  'selling_price',
  'stock',
  'low_stock',
  'expiry',
  'description',
];

/// Writes [rows] to a CSV file in Documents/MePharmaExports and opens a save
/// dialog (Windows). Returns the written file path or null when cancelled.
Future<String?> exportProductsCsv(
  List<ProductCsvRow> rows, {
  String? suggestedName,
}) async {
  final documents = await getApplicationDocumentsDirectory();
  final exportsDir = p.join(documents.path, 'MePharmaExports');
  final name = suggestedName ?? 'products_${_stamp()}';

  final buffer = StringBuffer()..writeln(csvLine(productCsvHeader));
  for (final row in rows) {
    buffer.writeln(csvLine(row.toCells()));
  }

  const type = XTypeGroup(
    label: 'CSV',
    extensions: ['csv'],
    uniformTypeIdentifiers: ['public.comma-separated-values-text'],
    mimeTypes: ['text/csv'],
  );
  final location = await getSaveLocation(
    suggestedName: '$name.csv',
    acceptedTypeGroups: [type],
  );
  if (location == null) {
    return null;
  }
  // Only create the exports directory once the user has actually picked a
  // location, so cancelling the dialog leaves nothing behind.
  await Directory(exportsDir).create(recursive: true);
  final file = XFile.fromData(
    utf8.encode(buffer.toString()),
    mimeType: 'text/csv',
    name: '$name.csv',
  );
  await file.saveTo(location.path);
  return location.path;
}

/// Opens a file picker, parses a products CSV and returns the import rows.
Future<ProductImportResult?> importProductsCsv() async {
  const type = XTypeGroup(
    label: 'CSV',
    extensions: ['csv'],
    uniformTypeIdentifiers: ['public.comma-separated-values-text'],
    mimeTypes: ['text/csv'],
  );
  final file = await openFile(acceptedTypeGroups: [type]);
  if (file == null) {
    return null;
  }
  final content = await file.readAsString();
  return parseProductsCsv(content);
}

/// Parses a products CSV. The first line is expected to be the header; header
/// names are matched case-insensitively.
ProductImportResult parseProductsCsv(String content) {
  // Strip a UTF-8 BOM that some spreadsheet exports prepend.
  final cleaned = content.startsWith('\uFEFF') ? content.substring(1) : content;
  final lines = const LineSplitter()
      .convert(cleaned.replaceAll('\r\n', '\n'))
      .where((line) => line.trim().isNotEmpty)
      .toList();
  final rows = <ProductImportRow>[];
  final errors = <(int, String)>[];
  if (lines.isEmpty) {
    return ProductImportResult(rows: rows, errors: errors);
  }

  final header = _splitCsv(lines.first);
  final index = <String, int>{};
  for (var i = 0; i < header.length; i++) {
    index[header[i].trim().toLowerCase()] = i;
  }
  // The file must at least identify products by sku and name.
  if (!index.containsKey('sku') || !index.containsKey('name')) {
    errors.add((1, 'Missing required header columns: sku, name'));
    return ProductImportResult(rows: rows, errors: errors);
  }

  final seenSkus = <String>{};
  for (var i = 1; i < lines.length; i++) {
    final lineNumber = i + 1;
    final cells = _splitCsv(lines[i]);
    String cell(String name) {
      final idx = index[name];
      if (idx == null || idx >= cells.length) {
        return '';
      }
      return cells[idx].trim();
    }

    try {
      final sku = cell('sku');
      final name = cell('name');
      if (sku.isEmpty || name.isEmpty) {
        errors.add((lineNumber, 'Missing sku or name'));
        continue;
      }
      if (!seenSkus.add(sku.toLowerCase())) {
        errors.add((lineNumber, 'Duplicate sku: $sku'));
        continue;
      }
      final barcode = cell('barcode');
      final expiryRaw = cell('expiry');
      final cost = parseCents(cell('cost'));
      final selling = parseCents(cell('selling_price'));
      final stock = int.tryParse(cell('stock')) ?? 0;
      final low = int.tryParse(cell('low_stock')) ?? 10;
      rows.add(
        ProductImportRow(
          sku: sku,
          name: name,
          barcode: barcode.isEmpty ? null : barcode,
          categoryName: cell('category'),
          supplierName: cell('supplier'),
          costPrice: cost < 0 ? 0 : cost,
          sellingPrice: selling < 0 ? 0 : selling,
          stockQuantity: stock < 0 ? 0 : stock,
          lowStockThreshold: low < 0 ? 0 : low,
          expiryDate: expiryRaw.isEmpty ? null : DateTime.tryParse(expiryRaw),
          description: cell('description').isEmpty ? null : cell('description'),
        ),
      );
    } catch (_) {
      errors.add((lineNumber, 'Unparsable line'));
    }
  }
  return ProductImportResult(rows: rows, errors: errors);
}

List<String> _splitCsv(String line) {
  final cells = <String>[];
  final buffer = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final char = line[i];
    if (inQuotes) {
      if (char == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        buffer.write(char);
      }
    } else if (char == '"') {
      inQuotes = true;
    } else if (char == ',') {
      cells.add(buffer.toString());
      buffer.clear();
    } else {
      buffer.write(char);
    }
  }
  cells.add(buffer.toString());
  return cells;
}

String _stamp() {
  final now = DateTime.now();
  return '${now.year}${_two(now.month)}${_two(now.day)}_'
      '${_two(now.hour)}${_two(now.minute)}${_two(now.second)}';
}

String _two(int value) => value.toString().padLeft(2, '0');
