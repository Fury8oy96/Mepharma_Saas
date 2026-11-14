/// How the receipt printer is connected.
enum PrinterType { none, windows, network }

/// Receipt and document printer configuration, stored as JSON in the settings table.
class PrinterConfig {
  const PrinterConfig({
    this.type = PrinterType.none,
    this.address = '',
    this.port = 9100,
    this.paperSize = '80',
    this.a4PrinterName = '',
  });

  final PrinterType type;

  /// Installed receipt printer name (windows) or host/IP (network).
  final String address;

  /// Raw TCP port, e.g. 9100 (network printers).
  final int port;

  /// Paper width: '58' or '80' (mm).
  final String paperSize;

  /// Installed standard A4 printer name (for invoices, POs, reports).
  final String a4PrinterName;

  factory PrinterConfig.fromJson(Map<String, dynamic> json) {
    return PrinterConfig(
      type: PrinterType.values.where((t) => t.name == json['type']).firstOrNull ??
          PrinterType.none,
      address: (json['address'] as String?) ?? '',
      port: (json['port'] as num?)?.toInt() ?? 9100,
      paperSize: (json['paperSize'] as String?) ?? '80',
      a4PrinterName: (json['a4PrinterName'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'address': address,
      'port': port,
      'paperSize': paperSize,
      'a4PrinterName': a4PrinterName,
    };
  }
}
