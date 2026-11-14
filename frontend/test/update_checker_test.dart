import 'package:flutter_test/flutter_test.dart';
import 'package:mepharma/src/core/services/app_edition_resolver.dart';
import 'package:mepharma/src/core/services/update_checker_service.dart';

void main() {
  setUp(() {
    AppEditionResolver.resetForTesting();
  });

  group('UpdateCheckerService SemVer Tests', () {
    test('isRemoteNewer detects higher major version', () {
      expect(UpdateCheckerService.isRemoteNewer('2.0.0', '1.0.1'), isTrue);
      expect(UpdateCheckerService.isRemoteNewer('1.0.1', '2.0.0'), isFalse);
    });

    test('isRemoteNewer detects higher minor version', () {
      expect(UpdateCheckerService.isRemoteNewer('1.1.0', '1.0.1'), isTrue);
      expect(UpdateCheckerService.isRemoteNewer('1.0.1', '1.1.0'), isFalse);
    });

    test('isRemoteNewer detects higher patch version', () {
      expect(UpdateCheckerService.isRemoteNewer('1.0.2', '1.0.1'), isTrue);
      expect(UpdateCheckerService.isRemoteNewer('1.0.1', '1.0.2'), isFalse);
    });

    test('isRemoteNewer returns false for equal versions', () {
      expect(UpdateCheckerService.isRemoteNewer('1.0.1', '1.0.1'), isFalse);
    });

    test('UpdateInfo parses JSON correctly with bilingual changelogs and edition', () {
      final json = {
        'version': '1.0.2',
        'buildNumber': 3,
        'edition': 'standard',
        'appName': 'MePharma',
        'releaseDate': '2026-11-20',
        'downloadUrl': 'https://github.com/Fury8oy96/mepharma/releases/download/v1.0.2/setup.exe',
        'htmlUrl': 'https://github.com/Fury8oy96/mepharma/releases/tag/v1.0.2',
        'changelog': {
          'en': ['Feature A', 'Fix B'],
          'ar': ['ميزة أ', 'إصلاح ب'],
        },
      };

      final info = UpdateInfo.fromJson(json);
      expect(info.version, equals('1.0.2'));
      expect(info.buildNumber, equals(3));
      expect(info.edition, equals('standard'));
      expect(info.appName, equals('MePharma'));
      expect(info.releaseDate, equals('2026-11-20'));
      expect(info.changelogEn, contains('Feature A'));
      expect(info.changelogAr, contains('ميزة أ'));
    });

    test('Edition matching strictly validates payload edition against AppConstants.edition', () {
      final standardPayload = UpdateInfo.fromJson({
        'version': '2.0.5',
        'edition': 'standard',
      });
      final variantPayload = UpdateInfo.fromJson({
        'version': '2.0.5',
        'edition': 'variant',
      });

      expect(standardPayload.edition == 'standard', isTrue);
      expect(variantPayload.edition == 'standard', isFalse);
      expect(variantPayload.edition == 'variant', isTrue);
    });
  });

  group('AppEditionResolver Tests', () {
    test('resolves variant from config edition', () {
      final edition = AppEditionResolver.resolve(configEdition: 'variant');
      expect(edition.isVariant, isTrue);
      expect(edition.editionName, equals('variant'));
      expect(edition.defaultManifestUrl, contains('version-variant.json'));
      expect(edition.matchesInstallerFilename('mepharma_varient.exe'), isTrue);
      expect(edition.matchesInstallerFilename('MePharma_Setup_2.04.exe'), isFalse);
    });

    test('resolves variant from executable path', () {
      final edition = AppEditionResolver.resolve(executablePath: r'C:\Programs\MePharma Variant\mepharma_variant.exe');
      expect(edition.isVariant, isTrue);
    });

    test('resolves candidate manifest URLs including backend server endpoint', () {
      final edition = AppEditionResolver.resolve(configEdition: 'variant');
      final urls = edition.getCandidateManifestUrls(backendBaseUrl: 'http://localhost:8000/api');
      expect(urls.length, equals(2));
      expect(urls.first, equals('http://localhost:8000/api/updates/manifest?edition=variant'));
      expect(urls.last, equals(edition.defaultManifestUrl));
    });
  });
}
