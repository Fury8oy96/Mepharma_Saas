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

  /// Checks for available updates.
  /// If [force] is false, throttles checks to once every 24 hours and ignores dismissed versions.
  Future<UpdateInfo?> checkForUpdate({bool force = false}) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);

    if (!force) {
      final lastChecked = await _settingsRepository.getValue(_keyLastCheckedDate);
      if (lastChecked == today) {
        return null; // Already checked today
      }
    }

    try {
      final uri = Uri.parse(AppConstants.updateCheckUrl);
      final response = await http.get(uri).timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) {
        return null;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final info = UpdateInfo.fromJson(body);

      // Record check date
      await _settingsRepository.setValue(_keyLastCheckedDate, today);

      final hasUpdate = isRemoteNewer(info.version, AppConstants.appVersion);
      if (!hasUpdate) {
        return null;
      }

      if (!force) {
        final dismissed = await _settingsRepository.getValue(_keyDismissedVersion);
        if (dismissed == info.version) {
          return null; // User dismissed this version
        }
      }

      return info;
    } catch (e) {
      debugPrint('UpdateCheckerService check non-fatal error: $e');
      return null;
    }
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
}
