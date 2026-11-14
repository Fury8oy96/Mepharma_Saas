import 'dart:io';
import 'package:flutter/foundation.dart';

/// Manages Windows startup registration to allow opening MePharma automatically on Windows boot.
class WindowsStartupService {
  static const String _runKeyPath = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const String _valueName = 'MePharma POS';

  /// Checks if MePharma is registered to run on Windows startup.
  static Future<bool> isAutoStartEnabled() async {
    if (!Platform.isWindows) return false;
    try {
      final result = await Process.run('reg', ['query', _runKeyPath, '/v', _valueName]);
      return result.exitCode == 0;
    } catch (e) {
      debugPrint('Error checking Windows startup status: $e');
      return false;
    }
  }

  /// Enables or disables automatic launch on Windows startup.
  static Future<bool> setAutoStartEnabled(bool enable) async {
    if (!Platform.isWindows) return false;
    try {
      if (enable) {
        final exePath = Platform.resolvedExecutable;
        final result = await Process.run('reg', [
          'add',
          _runKeyPath,
          '/v',
          _valueName,
          '/t',
          'REG_SZ',
          '/d',
          '"$exePath"',
          '/f',
        ]);
        return result.exitCode == 0;
      } else {
        final result = await Process.run('reg', [
          'delete',
          _runKeyPath,
          '/v',
          _valueName,
          '/f',
        ]);
        return result.exitCode == 0;
      }
    } catch (e) {
      debugPrint('Error updating Windows startup status: $e');
      return false;
    }
  }
}

