import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/models/api_config.dart';

class ApiConfigManager {
  Future<File> _getFile() async {
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

  Future<ApiConfig> loadConfig() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) {
        return const ApiConfig(
          mode: DatabaseMode.onlineApi,
          baseUrl: 'http://localhost:8000/api',
          branchId: 1,
        );
      }
      final raw = await file.readAsString();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return ApiConfig.fromJson(json);
    } catch (_) {
      return const ApiConfig(
        mode: DatabaseMode.onlineApi,
        baseUrl: 'http://localhost:8000/api',
        branchId: 1,
      );
    }
  }

  Future<void> saveConfig(ApiConfig config) async {
    try {
      final file = await _getFile();
      final raw = jsonEncode(config.toJson());
      await file.writeAsString(raw);
    } catch (_) {
      // Fail silently in production, or log if needed.
    }
  }
}
