import 'package:flutter_test/flutter_test.dart';
import 'package:mepharma/src/core/utils/pricing_engine.dart';

void main() {
  group('PricingEngine Tests', () {
    test('normalizeMargin converts percentage to decimal fraction', () {
      expect(PricingEngine.normalizeMargin(25.0), equals(0.25));
      expect(PricingEngine.normalizeMargin(30.0), equals(0.30));
      expect(PricingEngine.normalizeMargin(100.0), equals(1.0));
      expect(PricingEngine.normalizeMargin(0.25), equals(0.25));
      expect(PricingEngine.normalizeMargin(0.0), equals(0.0));
      expect(PricingEngine.normalizeMargin(-0.1), equals(0.0));
    });

    test('calculateSellingPrice applies Item Price = Cost + (Cost * Margin)', () {
      // 4,000 cost with 25% (0.25) margin -> 5,000
      expect(PricingEngine.calculateSellingPrice(4000, 0.25), equals(5000));
      // 4,000 cost with 25 entered as whole number 25 -> 5,000
      expect(PricingEngine.calculateSellingPrice(4000, 25.0), equals(5000));
      // 1,000 cost with 0 margin -> 1,000
      expect(PricingEngine.calculateSellingPrice(1000, 0.0), equals(1000));
      // 0 cost -> 0
      expect(PricingEngine.calculateSellingPrice(0, 0.3), equals(0));
      // 3,333 cost with 15% margin -> 3333 * 1.15 = 3832.95 -> 3833
      expect(PricingEngine.calculateSellingPrice(3333, 15.0), equals(3833));
    });
  });
}
