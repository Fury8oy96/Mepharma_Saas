import 'dart:io';
import '../constants/app_constants.dart';

enum AppEdition {
  standard,
  variant;

  bool get isVariant => this == AppEdition.variant;
  bool get isStandard => this == AppEdition.standard;

  String get editionName => isVariant ? 'variant' : 'standard';
  String get displayName => isVariant ? 'MePharma Variant' : 'MePharma';

  String get defaultManifestUrl => isVariant
      ? 'https://raw.githubusercontent.com/Fury8oy96/Mepharma_Saas/main/version-variant.json'
      : 'https://raw.githubusercontent.com/Fury8oy96/Mepharma_Saas/main/version.json';

  String get targetInstallerFilename =>
      isVariant ? 'mepharma_varient.exe' : 'MePharma_Setup_${AppConstants.appVersion}.exe';

  bool matchesInstallerFilename(String filename) {
    final lower = filename.toLowerCase();
    if (isVariant) {
      return lower.contains('varient') || lower.contains('variant');
    } else {
      return !lower.contains('varient') && !lower.contains('variant');
    }
  }

  List<String> getCandidateManifestUrls({String? backendBaseUrl}) {
    final list = <String>[];
    if (backendBaseUrl != null && backendBaseUrl.trim().isNotEmpty) {
      final cleanBase = backendBaseUrl.trim().replaceAll(RegExp(r'/api/?$'), '');
      list.add('$cleanBase/api/updates/manifest?edition=$editionName');
    }
    list.add(defaultManifestUrl);
    return list;
  }
}

abstract final class AppEditionResolver {
  static AppEdition? _cachedEdition;

  static AppEdition resolve({
    String? configEdition,
    String? pharmacyName,
    String? executablePath,
  }) {
    if (_cachedEdition != null) return _cachedEdition!;

    // 1. Explicit configuration in api_config.json
    if (configEdition != null && configEdition.trim().isNotEmpty) {
      final norm = configEdition.trim().toLowerCase();
      if (norm == 'variant' || norm == 'varient') {
        return _cachedEdition = AppEdition.variant;
      }
      if (norm == 'standard') {
        return _cachedEdition = AppEdition.standard;
      }
    }

    // 2. Pharmacy name / organization hint
    if (pharmacyName != null) {
      final pLower = pharmacyName.toLowerCase();
      if (pLower.contains('variant') || pLower.contains('varient')) {
        return _cachedEdition = AppEdition.variant;
      }
    }

    // 3. Executable binary filename and host directory path
    try {
      final exe = (executablePath ?? Platform.resolvedExecutable).toLowerCase();
      final currentDir = Directory.current.path.toLowerCase();
      if (exe.contains('variant') || exe.contains('varient') ||
          currentDir.contains('variant') || currentDir.contains('varient')) {
        return _cachedEdition = AppEdition.variant;
      }
    } catch (_) {}

    // 4. Compile-time constant fallback
    if (AppConstants.edition == 'variant') {
      return _cachedEdition = AppEdition.variant;
    }

    return _cachedEdition = AppEdition.standard;
  }

  static void resetForTesting() {
    _cachedEdition = null;
  }
}
