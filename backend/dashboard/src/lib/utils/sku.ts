/**
 * Standardized Pharmaceutical SKU Generator for Web Dashboard
 * 
 * Formula: [BRAND_PREFIX]-[GENERIC_PREFIX]-[DOSAGE]
 * Example: "Panadol Extra 500mg" + "Paracetamol" -> "PAN-PAR-500MG"
 */

function cleanChunk(text: string): string {
  if (!text) return '';
  return text
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-zA-Z0-9\s]/g, ' ')
    .trim();
}

export function extractBrandPrefix(name: string): string {
  const cleaned = cleanChunk(name);
  if (!cleaned) return 'MED';

  const words = cleaned.split(/\s+/).filter(w => w.length > 0);
  if (words.length === 0) return 'MED';

  const firstWord = words[0].toUpperCase();
  const lettersOnly = firstWord.replace(/[^A-Z]/g, '');

  if (lettersOnly.length >= 3) {
    return lettersOnly.slice(0, lettersOnly.length === 4 ? 4 : 3);
  } else if (firstWord.length >= 3) {
    return firstWord.slice(0, 3);
  } else if (words.length > 1) {
    const combined = words.map(w => w[0].toUpperCase()).join('');
    return (combined + 'XXX').slice(0, 3);
  }

  return (firstWord + 'XXX').slice(0, 3);
}

export function extractGenericPrefix(genericName?: string | null, fallbackSecondaryWord?: string): string {
  const cleaned = cleanChunk(genericName || fallbackSecondaryWord || '');
  if (!cleaned) return 'GEN';

  const words = cleaned.split(/\s+/).filter(w => w.length > 0);
  if (words.length === 0) return 'GEN';

  const firstWord = words[0].toUpperCase();
  const lettersOnly = firstWord.replace(/[^A-Z]/g, '');

  if (lettersOnly.length >= 3) {
    return lettersOnly.slice(0, lettersOnly.length === 4 ? 4 : 3);
  } else if (firstWord.length >= 3) {
    return firstWord.slice(0, 3);
  }

  return (firstWord + 'GEN').slice(0, 3);
}

export function extractDosageChunk(dosageOrName: string): string {
  if (!dosageOrName) return 'STD';

  const text = dosageOrName.trim();
  const complexMatch = text.match(/(\d+(?:\.\d+)?)\s*(mg|g|mcg|ml|iu|%|pct)(?:\s*\/\s*(\d+(?:\.\d+)?)\s*(ml|mg))?/i);
  if (complexMatch) {
    const val1 = complexMatch[1];
    const unit1 = (complexMatch[2] === '%' ? 'PCT' : complexMatch[2]).toUpperCase();
    if (complexMatch[3] && complexMatch[4]) {
      const val2 = complexMatch[3];
      const unit2 = complexMatch[4].toUpperCase();
      return `${val1}${unit1}-${val2}${unit2}`;
    }
    return `${val1}${unit1}`;
  }

  const digitMatch = text.match(/(\d+)\s*([a-zA-Z]+)?/);
  if (digitMatch) {
    const num = digitMatch[1];
    const unit = (digitMatch[2] || 'MG').toUpperCase();
    return `${num}${unit.slice(0, 3)}`;
  }

  return 'STD';
}

export interface SkuOptions {
  brandName: string;
  genericName?: string | null;
  dosage?: string | null;
  category?: string | null;
  suffix?: string | number | null;
}

export function generatePharmaceuticalSku(options: SkuOptions): string {
  const brandPart = extractBrandPrefix(options.brandName);

  let genericPart = '';
  if (options.genericName && options.genericName.trim().length > 0) {
    genericPart = extractGenericPrefix(options.genericName);
  } else {
    const brandWords = cleanChunk(options.brandName).split(/\s+/);
    if (brandWords.length > 1 && brandWords[1].length >= 3) {
      genericPart = extractGenericPrefix(brandWords[1]);
    } else if (options.category && options.category.trim().length >= 3) {
      genericPart = extractGenericPrefix(options.category);
    } else {
      genericPart = 'GEN';
    }
  }

  let dosagePart = 'STD';
  if (options.dosage && options.dosage.trim().length > 0) {
    dosagePart = extractDosageChunk(options.dosage);
  } else {
    dosagePart = extractDosageChunk(options.brandName);
  }

  let sku = `${brandPart}-${genericPart}-${dosagePart}`;

  if (options.suffix !== undefined && options.suffix !== null && options.suffix !== '') {
    const formattedSuffix = typeof options.suffix === 'number'
      ? String(options.suffix).padStart(2, '0')
      : String(options.suffix);
    sku += `-${formattedSuffix}`;
  }

  return sku;
}
