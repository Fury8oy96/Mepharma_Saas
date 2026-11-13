import 'package:flutter_test/flutter_test.dart';
import 'package:mepharma/src/core/services/update_checker_service.dart';

void main() {
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

    test('UpdateInfo parses JSON correctly with bilingual changelogs', () {
      final json = {
        'version': '1.0.2',
        'buildNumber': 3,
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
      expect(info.releaseDate, equals('2026-11-20'));
      expect(info.changelogEn, contains('Feature A'));
      expect(info.changelogAr, contains('ميزة أ'));
    });
  });
}
