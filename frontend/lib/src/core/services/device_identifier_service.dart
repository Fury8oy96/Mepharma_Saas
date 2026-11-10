import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// Service that discovers and derives a persistent hardware fingerprint for the desktop terminal.
class DeviceIdentifierService {
  static String? _cachedHardwareId;
  static String? _cachedTerminalName;

  /// Returns a persistent, tamper-resistant SHA-256 terminal hardware signature.
  static Future<String> getHardwareId() async {
    if (_cachedHardwareId != null) return _cachedHardwareId!;

    String rawSeed = '';

    if (Platform.isWindows) {
      try {
        final result = await Process.run('reg', [
          'query',
          r'HKLM\SOFTWARE\Microsoft\Cryptography',
          '/v',
          'MachineGuid',
        ]);
        if (result.exitCode == 0 && result.stdout is String) {
          final output = result.stdout as String;
          final match = RegExp(r'MachineGuid\s+REG_SZ\s+([a-fA-F0-9\-]+)').firstMatch(output);
          if (match != null && match.group(1) != null) {
            rawSeed = match.group(1)!.trim();
          }
        }
      } catch (_) {}
    }

    // Fallback if registry query is blocked or non-Windows
    if (rawSeed.isEmpty) {
      final compName = Platform.environment['COMPUTERNAME'] ?? '';
      final procId = Platform.environment['PROCESSOR_IDENTIFIER'] ?? '';
      final host = Platform.localHostname;
      rawSeed = '${compName}_${procId}_$host';
    }

    final hash = sha256.convert(utf8.encode(rawSeed)).toString().toUpperCase();
    _cachedHardwareId = 'TERM-WIN-${hash.substring(0, 16)}';
    return _cachedHardwareId!;
  }

  /// Returns a human-friendly name for this counter terminal.
  static String getTerminalName() {
    if (_cachedTerminalName != null) return _cachedTerminalName!;
    final name = Platform.environment['COMPUTERNAME'] ?? Platform.localHostname;
    _cachedTerminalName = name.isNotEmpty ? name : 'Windows POS Terminal';
    return _cachedTerminalName!;
  }
}
