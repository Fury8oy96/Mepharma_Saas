import 'package:flutter_test/flutter_test.dart';
import 'package:mepharma/src/core/utils/money.dart';

void main() {
  group('formatCents', () {
    test('formats whole amounts', () {
      expect(formatCents(12000), '12,000');
      expect(formatCents(0), '0');
      expect(formatCents(500), '500');
    });

    test('handles negative amounts', () {
      expect(formatCents(-1250), '-1,250');
    });

    test('groups thousands when requested', () {
      expect(formatCents(1250000, withSeparator: true), '1,250,000');
    });
  });

  group('parseCents', () {
    test('parses integer strings', () {
      expect(parseCents('12000'), 12000);
      expect(parseCents('12,500'), 12500);
      expect(parseCents('12'), 12);
      expect(parseCents('500'), 500);
    });

    test('parses negative and formatted input', () {
      expect(parseCents('-1250'), -1250);
      expect(parseCents('12,500,000'), 12500000);
    });
  });

  group('round trip', () {
    test('format then parse is stable', () {
      for (final amount in [0, 5, 100, 1250, 12000, 999999]) {
        expect(parseCents(formatCents(amount)), amount);
      }
    });
  });
}
