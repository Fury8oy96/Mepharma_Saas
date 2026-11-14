/// Standardized Pharmaceutical SKU Generator for Flutter
///
/// Formula: [BRAND_PREFIX]-[GENERIC_PREFIX]-[DOSAGE]
/// Example: "Panadol Extra 500mg" + "Paracetamol" -> "PAN-PAR-500MG"
class SkuGenerator {
  const SkuGenerator._();

  static String cleanChunk(String text) {
    if (text.isEmpty) return '';
    return text
        .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
        .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), ' ')
        .trim();
  }

  static String extractBrandPrefix(String name) {
    final cleaned = cleanChunk(name);
    if (cleaned.isEmpty) return 'MED';

    final words = cleaned
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return 'MED';

    final firstWord = words.first.toUpperCase();
    final lettersOnly = firstWord.replaceAll(RegExp(r'[^A-Z]'), '');

    if (lettersOnly.length >= 3) {
      return lettersOnly.substring(0, lettersOnly.length == 4 ? 4 : 3);
    } else if (firstWord.length >= 3) {
      return firstWord.substring(0, 3);
    } else if (words.length > 1) {
      final combined = words.map((w) => w[0].toUpperCase()).join();
      return '${combined}XXX'.substring(0, 3);
    }

    return '${firstWord}XXX'.substring(0, 3);
  }

  static String extractGenericPrefix(String? genericName, [String? fallbackSecondaryWord]) {
    final cleaned = cleanChunk(genericName ?? fallbackSecondaryWord ?? '');
    if (cleaned.isEmpty) return 'GEN';

    final words = cleaned
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return 'GEN';

    final firstWord = words.first.toUpperCase();
    final lettersOnly = firstWord.replaceAll(RegExp(r'[^A-Z]'), '');

    if (lettersOnly.length >= 3) {
      return lettersOnly.substring(0, lettersOnly.length == 4 ? 4 : 3);
    } else if (firstWord.length >= 3) {
      return firstWord.substring(0, 3);
    }

    return '${firstWord}GEN'.substring(0, 3);
  }

  static String extractDosageChunk(String dosageOrName) {
    if (dosageOrName.isEmpty) return 'STD';

    final text = dosageOrName.trim();

    // Check for common dosage patterns (e.g. 500mg, 1g, 250mg/5ml, 100iu, 5%)
    final complexMatch = RegExp(
      r'(\d+(?:\.\d+)?)\s*(mg|g|mcg|ml|iu|%|pct)(?:\s*\/\s*(\d+(?:\.\d+)?)\s*(ml|mg))?',
      caseSensitive: false,
    ).firstMatch(text);

    if (complexMatch != null) {
      final val1 = complexMatch.group(1);
      final rawUnit1 = complexMatch.group(2) ?? '';
      final unit1 = (rawUnit1 == '%' ? 'PCT' : rawUnit1).toUpperCase();

      final val2 = complexMatch.group(3);
      final rawUnit2 = complexMatch.group(4);

      if (val2 != null && rawUnit2 != null) {
        final unit2 = rawUnit2.toUpperCase();
        return '$val1$unit1-$val2$unit2';
      }
      return '$val1$unit1';
    }

    // Pure digits with optional unit
    final digitMatch = RegExp(r'(\d+)\s*([a-zA-Z]+)?').firstMatch(text);
    if (digitMatch != null) {
      final num = digitMatch.group(1);
      final unit = (digitMatch.group(2) ?? 'MG').toUpperCase();
      final unitTrim = unit.length > 3 ? unit.substring(0, 3) : unit;
      return '$num$unitTrim';
    }

    return 'STD';
  }

  static String generate({
    required String brandName,
    String? genericName,
    String? dosage,
    String? category,
    dynamic suffix,
  }) {
    final brandPart = extractBrandPrefix(brandName);

    String genericPart;
    if (genericName != null && genericName.trim().isNotEmpty) {
      genericPart = extractGenericPrefix(genericName);
    } else {
      final brandWords = cleanChunk(brandName).split(RegExp(r'\s+'));
      if (brandWords.length > 1 && brandWords[1].length >= 3) {
        genericPart = extractGenericPrefix(brandWords[1]);
      } else if (category != null && category.trim().length >= 3) {
        genericPart = extractGenericPrefix(category);
      } else {
        genericPart = 'GEN';
      }
    }

    String dosagePart;
    if (dosage != null && dosage.trim().isNotEmpty) {
      dosagePart = extractDosageChunk(dosage);
    } else {
      dosagePart = extractDosageChunk(brandName);
    }

    var sku = '$brandPart-$genericPart-$dosagePart';

    if (suffix != null && suffix.toString().isNotEmpty) {
      final formattedSuffix = suffix is int
          ? suffix.toString().padLeft(2, '0')
          : suffix.toString();
      sku = '$sku-$formattedSuffix';
    }

    return sku;
  }
}
