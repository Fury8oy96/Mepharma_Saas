/// Escapes a single CSV cell, quoting it when it contains special characters.
String csvEscape(String value) {
  if (value.contains(',') ||
      value.contains('"') ||
      value.contains('\n') ||
      value.contains('\r')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

/// Joins cells into one CSV line.
String csvLine(List<String> cells) => cells.map(csvEscape).join(',');
