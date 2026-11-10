/// Formats an amount as a whole number integer string with optional thousands separator.
///
/// Example: `formatCents(12000)` -> `"12,000"`.
String formatCents(int amount, {bool withSeparator = true}) {
  final sign = amount < 0 ? '-' : '';
  final abs = amount.abs();
  final wholeStr = withSeparator ? _groupThousands(abs) : abs.toString();
  return '$sign$wholeStr';
}

String _groupThousands(int value) {
  final s = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(s[i]);
  }
  return buffer.toString();
}

/// Formats an amount with a currency symbol.
///
/// Example: `formatMoney(12000, symbol: r'$')` -> `"$ 12,000"`.
String formatMoney(
  int amount, {
  required String symbol,
  bool withSeparator = true,
}) {
  final sign = amount < 0 ? '-' : '';
  final sym = symbol.trim().isEmpty ? '' : '${symbol.trim()} ';
  return '$sign$sym${formatCents(amount.abs(), withSeparator: withSeparator)}';
}

/// Converts a plain number string (e.g. `"12000"` or `"12,000"`) to a whole number amount.
///
/// Lenient: malformed input resolves to `0`, comma thousands separators and spaces are stripped.
int parseCents(String input) {
  final normalized = input.trim().replaceAll(',', '').replaceAll(' ', '');
  final value = double.tryParse(normalized);
  if (value == null || !value.isFinite) {
    return 0;
  }
  return value.round();
}

/// Parses a strict non-negative integer into whole units, or returns `null` when [input] is not valid.
///
/// Examples: `tryParseMoney("12000")` -> `12000`, `tryParseMoney("abc")` -> `null`,
/// `tryParseMoney("-5")` -> `null`.
int? tryParseMoney(String input) {
  final value = input.trim().replaceAll(',', '').replaceAll(' ', '');
  if (!RegExp(r'^\d{1,12}$').hasMatch(value)) {
    return null;
  }
  return int.tryParse(value);
}
