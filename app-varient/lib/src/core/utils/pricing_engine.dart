/// Governed Dynamic Pricing Engine for MePharma.
///
/// Implements the system pricing rule:
/// `Selling Price = Purchase (Cost) Price + (Purchase Price * Margin Value)`
abstract final class PricingEngine {
  /// Normalizes a profit margin value.
  ///
  /// If the margin is provided as a whole percentage (e.g., `25` for 25% or `30` for 30%),
  /// it is converted to its decimal fraction (`0.25` or `0.30`).
  /// If provided as a fraction (`0.25`), it is preserved.
  /// Negative values are clamped to `0.0`.
  static double normalizeMargin(double rawMargin) {
    if (rawMargin <= 0.0) return 0.0;
    if (rawMargin > 1.0) {
      return rawMargin / 100.0;
    }
    return rawMargin;
  }

  /// Computes the governed selling price for a medicine.
  ///
  /// Applies: `Selling Price = Cost Price + (Cost Price * Margin)`
  /// Always ensures selling price is never less than cost price.
  static int calculateSellingPrice(int costPrice, double rawMargin) {
    if (costPrice <= 0) return 0;
    final margin = normalizeMargin(rawMargin);
    final selling = (costPrice * (1.0 + margin)).round();
    return selling >= costPrice ? selling : costPrice;
  }
}
