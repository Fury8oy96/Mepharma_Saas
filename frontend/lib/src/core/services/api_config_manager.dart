import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/models/api_config.dart';

class ApiConfigManager {
  Future<File> _getFile() async {
    try {
      final supportDir = await getApplicationSupportDirectory();
      final userConfigFile = File(p.join(supportDir.path, 'api_config.json'));
      if (await userConfigFile.exists()) {
        return userConfigFile;
      }
    } catch (_) {}

    try {
      final exeDir = File(Platform.resolvedExecutable).parent;
      final installConfigFile = File(p.join(exeDir.path, 'api_config.json'));
      if (await installConfigFile.exists()) {
        return installConfigFile;
      }
    } catch (_) {}

    try {
      final cwdConfigFile = File(p.join(Directory.current.path, 'api_config.json'));
      if (await cwdConfigFile.exists()) {
        return cwdConfigFile;
      }
    } catch (_) {}

    final supportDir = await getApplicationSupportDirectory();
    return File(p.join(supportDir.path, 'api_config.json'));
  }

  static const ApiConfig defaultOfflineConfig = ApiConfig(
    mode: DatabaseMode.local,
    baseUrl: 'http://localhost:8000/api',
    branchId: 1,
    isConfigured: true,
    isLicenseValid: true,
    pharmacyName: 'MePharma Local',
    pharmacyAddress: 'Standalone SQLite Database',
    currency: 'SDG',
    currencySymbol: 'ج.س',
    taxRate: 0.0,
    licensePlan: 'offline_standalone',
    validityDaysRemaining: 365,
  );

  Future<ApiConfig> loadConfig() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) {
        return defaultOfflineConfig;
      }
      final raw = await file.readAsString();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return ApiConfig.fromJson(json);
    } catch (_) {
      return defaultOfflineConfig;
    }
  }

  Future<void> saveConfig(ApiConfig config) async {
    final raw = jsonEncode(config.toJson());
    try {
      final file = await _getFile();
      await file.writeAsString(raw);
    } catch (_) {
      try {
        final supportDir = await getApplicationSupportDirectory();
        final fallback = File(p.join(supportDir.path, 'api_config.json'));
        await fallback.writeAsString(raw);
      } catch (_) {}
    }
  }
}
