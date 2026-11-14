import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/repositories/settings_repository.dart';
import '../constants/app_constants.dart';

class UpdateInfo {
  final String version;
  final int buildNumber;
  final String releaseDate;
  final String downloadUrl;
  final String htmlUrl;
  final List<String> changelogEn;
  final List<String> changelogAr;

  const UpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.releaseDate,
    required this.downloadUrl,
    required this.htmlUrl,
    required this.changelogEn,
    required this.changelogAr,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    final changelog = json['changelog'] as Map<String, dynamic>? ?? {};
    return UpdateInfo(
      version: json['version'] as String? ?? '1.0.0',
      buildNumber: json['buildNumber'] as int? ?? 1,
      releaseDate: json['releaseDate'] as String? ?? '',
      downloadUrl: json['downloadUrl'] as String? ?? '',
      htmlUrl: json['htmlUrl'] as String? ?? '',
      changelogEn: (changelog['en'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      changelogAr: (changelog['ar'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

enum UpdateStatus {
  updateAvailable,
  upToDate,
  throttled,
  dismissed,
  error,
}

class UpdateCheckResult {
  final UpdateStatus status;
  final UpdateInfo? updateInfo;
  final String? errorMessage;

  const UpdateCheckResult({
    required this.status,
    this.updateInfo,
    this.errorMessage,
  });
}

class UpdateCheckerService {
  final SettingsRepository _settingsRepository;

  UpdateCheckerService(this._settingsRepository);

  static const String _keyLastCheckedDate = 'update.last_checked_date';
  static const String _keyDismissedVersion = 'update.dismissed_version';

  static bool isRemoteNewer(String remote, String current) {
    final rParts = remote.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final cParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (var i = 0; i < 3; i++) {
      final r = i < rParts.length ? rParts[i] : 0;
      final c = i < cParts.length ? cParts[i] : 0;
      if (r > c) return true;
      if (r < c) return false;
    }
    return false;
  }

  /// Checks for available updates returning a detailed result.
  Future<UpdateCheckResult> checkForUpdateResult({
    bool force = false,
    String? gitHubToken,
  }) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);

    if (!force) {
      final lastChecked = await _settingsRepository.getValue(_keyLastCheckedDate);
      if (lastChecked == today) {
        return const UpdateCheckResult(status: UpdateStatus.throttled);
      }
    }

    try {
      final uri = Uri.parse(AppConstants.updateCheckUrl);
      final headers = <String, String>{
        'Accept': 'application/json',
        if (gitHubToken != null && gitHubToken.isNotEmpty)
          'Authorization': 'token $gitHubToken',
      };

      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) {
        return UpdateCheckResult(
          status: UpdateStatus.error,
          errorMessage: 'HTTP ${response.statusCode} (${response.reasonPhrase ?? "Error"})',
        );
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final info = UpdateInfo.fromJson(body);

      // Record check date
      await _settingsRepository.setValue(_keyLastCheckedDate, today);

      final hasUpdate = isRemoteNewer(info.version, AppConstants.appVersion);
      if (!hasUpdate) {
        return const UpdateCheckResult(status: UpdateStatus.upToDate);
      }

      if (!force) {
        final dismissed = await _settingsRepository.getValue(_keyDismissedVersion);
        if (dismissed == info.version) {
          return const UpdateCheckResult(status: UpdateStatus.dismissed);
        }
      }

      return UpdateCheckResult(
        status: UpdateStatus.updateAvailable,
        updateInfo: info,
      );
    } catch (e) {
      debugPrint('UpdateCheckerService check error: $e');
      return UpdateCheckResult(
        status: UpdateStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Checks for available updates.
  /// If [force] is false, throttles checks to once every 24 hours and ignores dismissed versions.
  Future<UpdateInfo?> checkForUpdate({bool force = false}) async {
    final result = await checkForUpdateResult(force: force);
    return result.updateInfo;
  }

  Future<void> dismissVersion(String version) async {
    await _settingsRepository.setValue(_keyDismissedVersion, version);
  }

  /// Opens the release or download URL in default browser
  static Future<void> launchUrl(String url) async {
    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', url]);
      }
    } catch (e) {
      debugPrint('Failed to launch URL: $e');
    }
  }

  /// Downloads the update installer in the background with progress reporting.
  static Future<File> downloadInstaller({
    required String downloadUrl,
    required String savePath,
    void Function(int received, int total)? onProgress,
  }) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw HttpException(
          'HTTP ${response.statusCode}: ${response.reasonPhrase ?? "Error"}',
          uri: Uri.parse(downloadUrl),
        );
      }

      final totalBytes = response.contentLength ?? 0;
      var receivedBytes = 0;

      final file = File(savePath);
      final sink = file.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (onProgress != null) {
          onProgress(receivedBytes, totalBytes);
        }
      }

      await sink.flush();
      await sink.close();

      return file;
    } finally {
      client.close();
    }
  }

  /// Launches the downloaded installer in background update mode and closes the running app.
  static Future<void> launchInstallerAndExit(
    String installerPath, {
    bool silent = true,
  }) async {
    if (!Platform.isWindows) return;
    final file = File(installerPath);
    if (!await file.exists()) {
      throw FileSystemException('Installer not found at path', installerPath);
    }

    final args = <String>[
      '/SP-',
      '/NORESTART',
      '/CLOSEAPPLICATIONS',
      '/RESTARTAPPLICATIONS',
      if (silent) '/SILENT',
    ];

    await Process.start(
      installerPath,
      args,
      mode: ProcessStartMode.detached,
    );

    exit(0);
  }
}
