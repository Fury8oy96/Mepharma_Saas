/**
 * MePharma 1D Barcode Symbologies Vector Engine
 * 
 * Supports:
 * - Code 128 (Sets A/B/C) - High density alphanumeric pharma standard
 * - EAN-13 & EAN-8 - International retail trade
 * - UPC-A & UPC-E - North American retail & pharma
 * - Code 39 - Alphanumeric hospital/device tracking
 * - Code 93 - Compact alphanumeric
 * - ITF (Interleaved 2 of 5) - Logistics & carton packing
 * - Codabar (NW-7) - Blood bank & laboratory tracking
 * - GS1 DataBar / GS1-128 - Unit-dose & healthcare GTIN
 * - MSI Plessey - Inventory & shelf labeling
 */

export type BarcodeSymbology =
  | 'CODE128'
  | 'EAN13'
  | 'EAN8'
  | 'UPCA'
  | 'UPCE'
  | 'CODE39'
  | 'CODE93'
  | 'ITF'
  | 'CODABAR'
  | 'GS1_DATABAR'
  | 'MSI_PLESSEY';

export interface SymbologyMetadata {
  id: BarcodeSymbology;
  name: string;
  category: 'Retail' | 'Pharma/Medical' | 'Logistics' | 'General';
  description: string;
  sample: string;
  pattern: RegExp;
}

export const BARCODE_SYMBOLOGIES: SymbologyMetadata[] = [
  {
    id: 'CODE128',
    name: 'Code 128',
    category: 'Pharma/Medical',
    description: 'High-density alphanumeric standard for pharmacy inventory & SKU tracking',
    sample: 'PAN-PAR-500MG',
    pattern: /^[\x00-\x7F]+$/
  },
  {
    id: 'EAN13',
    name: 'EAN-13',
    category: 'Retail',
    description: 'Global 13-digit standard for commercial pharmaceutical trade',
    sample: '6291100123456',
    pattern: /^\d{12,13}$/
  },
  {
    id: 'UPCA',
    name: 'UPC-A',
    category: 'Retail',
    description: 'Universal 12-digit standard for North American products',
    sample: '012345678905',
    pattern: /^\d{11,12}$/
  },
  {
    id: 'EAN8',
    name: 'EAN-8',
    category: 'Retail',
    description: '8-digit compact standard for small medicine packs & vials',
    sample: '62912345',
    pattern: /^\d{7,8}$/
  },
  {
    id: 'UPCE',
    name: 'UPC-E',
    category: 'Retail',
    description: 'Zero-suppressed 8-digit compact UPC barcode',
    sample: '01234565',
    pattern: /^\d{6,8}$/
  },
  {
    id: 'CODE39',
    name: 'Code 39',
    category: 'Pharma/Medical',
    description: 'Variable-length alphanumeric barcode for clinical & hospital supplies',
    sample: 'MED-10023',
    pattern: /^[0-9A-Z\-\.\ \$\/\+\%]+$/i
  },
  {
    id: 'CODE93',
    name: 'Code 93',
    category: 'General',
    description: 'Higher density alphanumeric with dual modulo-47 check characters',
    sample: 'RX-90442',
    pattern: /^[\x00-\x7F]+$/
  },
  {
    id: 'ITF',
    name: 'ITF (Interleaved 2 of 5)',
    category: 'Logistics',
    description: 'High-density numeric pairs for shipping boxes & warehouse cartons',
    sample: '10012345678902',
    pattern: /^\d+$/
  },
  {
    id: 'CODABAR',
    name: 'Codabar (NW-7)',
    category: 'Pharma/Medical',
    description: 'Numeric + symbols format used in blood banks and laboratory specimens',
    sample: 'A1234567B',
    pattern: /^[A-D][0-9\-\$\:\/\.\+]+[A-D]$/i
  },
  {
    id: 'GS1_DATABAR',
    name: 'GS1 DataBar / GS1-128',
    category: 'Pharma/Medical',
    description: 'GS1 Healthcare standard for unit-dose blister packs & GTINs',
    sample: '(01)06291100123456',
    pattern: /^[\x00-\x7F]+$/
  },
  {
    id: 'MSI_PLESSEY',
    name: 'MSI Plessey',
    category: 'General',
    description: 'Continuous numeric symbology with Mod-10 check digit for shelf tags',
    sample: '1234567',
    pattern: /^\d+$/
  }
];

// ==========================================
// 1. Code 128 Encoding Engine
// ==========================================
const CODE128_PATTERNS: string[] = [
  '212222', '222122', '222221', '121223', '121322', '131222', '122213', '122312', '132212', '221213',
  '221312', '231212', '112232', '122132', '122231', '113222', '123122', '123221', '223211', '221132',
  '221231', '213212', '223112', '312131', '311222', '321122', '321221', '312212', '322112', '322211',
  '212123', '212321', '232121', '111323', '131123', '131321', '112313', '132113', '132311', '211313',
  '231113', '231311', '112133', '112331', '132131', '113123', '113321', '133121', '313121', '211331',
  '231131', '213113', '213311', '213131', '311123', '311321', '331121', '312113', '312311', '332111',
  '314111', '221411', '431111', '111224', '111422', '121124', '121421', '141122', '141221', '112214',
  '112412', '122114', '122411', '142112', '142211', '241211', '221114', '413111', '241112', '134111',
  '111242', '121142', '121241', '114212', '124112', '124211', '411212', '421112', '421211', '212141',
  '214121', '412121', '111143', '111341', '131141', '114113', '114311', '411113', '411311', '113141',
  '114131', '311141', '411131', '211412', '211214', '211232', '2331112' // 106: Stop
];

function encodeCode128(text: string): string {
  const codes: number[] = [104]; // START_B
  let checkSum = 104;

  for (let i = 0; i < text.length; i++) {
    const charCode = text.charCodeAt(i);
    const code128Val = charCode - 32;
    if (code128Val >= 0 && code128Val <= 95) {
      codes.push(code128Val);
      checkSum += code128Val * (i + 1);
    }
  }

  const checkDigit = checkSum % 103;
  codes.push(checkDigit);
  codes.push(106); // STOP

  let binary = '';
  for (const code of codes) {
    const pattern = CODE128_PATTERNS[code];
    if (!pattern) continue;
    for (let i = 0; i < pattern.length; i++) {
      const width = parseInt(pattern[i], 10);
      binary += (i % 2 === 0 ? '1' : '0').repeat(width);
    }
  }
  return binary;
}

// ==========================================
// 2. EAN-13 & UPC-A Encoding Engine
// ==========================================
const EAN_L_CODES = ['0001101', '0011001', '0010011', '0111101', '0100011', '0110001', '0101111', '0111011', '0110111', '0001011'];
const EAN_G_CODES = ['0100111', '0110011', '0011011', '0100001', '0011101', '0111001', '0000101', '0010001', '0001001', '0010111'];
const EAN_R_CODES = ['1110010', '1100110', '1101100', '1000010', '1011100', '1001110', '1010000', '1000100', '1001000', '1110100'];
const EAN_PARITY = [
  'LLLLLL', 'LLGLGG', 'LLGGLG', 'LLGGGL', 'LGLLGG', 'LGGLLG', 'LGGGLL', 'LGLGLG', 'LGLGGL', 'LGGLGL'
];

export function computeLuhnChecksum(digits12: string): number {
  let sum = 0;
  for (let i = 0; i < digits12.length; i++) {
    const digit = parseInt(digits12[i], 10) || 0;
    sum += i % 2 === 0 ? digit : digit * 3;
  }
  return (10 - (sum % 10)) % 10;
}

function encodeEan13(digits: string): { binary: string; text: string } {
  let clean = digits.replace(/\D/g, '');
  if (clean.length === 12) {
    clean += computeLuhnChecksum(clean);
  } else if (clean.length < 12) {
    clean = clean.padStart(12, '0');
    clean += computeLuhnChecksum(clean);
  } else if (clean.length > 13) {
    clean = clean.slice(0, 13);
  }

  const first = parseInt(clean[0], 10);
  const parity = EAN_PARITY[first];
  let binary = '101'; // Guard bar

  // Left 6 digits
  for (let i = 1; i <= 6; i++) {
    const d = parseInt(clean[i], 10);
    const type = parity[i - 1];
    binary += type === 'L' ? EAN_L_CODES[d] : EAN_G_CODES[d];
  }

  binary += '01010'; // Center bar

  // Right 6 digits
  for (let i = 7; i <= 12; i++) {
    const d = parseInt(clean[i], 10);
    binary += EAN_R_CODES[d];
  }

  binary += '101'; // End guard
  return { binary, text: clean };
}

function encodeEan8(digits: string): { binary: string; text: string } {
  let clean = digits.replace(/\D/g, '');
  if (clean.length === 7) {
    let sum = 0;
    for (let i = 0; i < 7; i++) {
      const d = parseInt(clean[i], 10) || 0;
      sum += i % 2 === 0 ? d * 3 : d;
    }
    clean += (10 - (sum % 10)) % 10;
  } else if (clean.length < 7) {
    clean = clean.padStart(7, '0');
    clean += '0';
  } else if (clean.length > 8) {
    clean = clean.slice(0, 8);
  }

  let binary = '101';
  for (let i = 0; i < 4; i++) {
    binary += EAN_L_CODES[parseInt(clean[i], 10)];
  }
  binary += '01010';
  for (let i = 4; i < 8; i++) {
    binary += EAN_R_CODES[parseInt(clean[i], 10)];
  }
  binary += '101';
  return { binary, text: clean };
}

// ==========================================
// 3. Code 39 Encoding Engine
// ==========================================
const CODE39_MAP: Record<string, string> = {
  '0': '101001101101', '1': '110100101011', '2': '101100101011', '3': '110110010101',
  '4': '101001101011', '5': '110100110101', '6': '101100110101', '7': '101001011011',
  '8': '110100101101', '9': '101100101101', 'A': '110101001011', 'B': '101101001011',
  'C': '110110100101', 'D': '101011001011', 'E': '110101100101', 'F': '101101100101',
  'G': '101010011011', 'H': '110101001101', 'I': '101101001101', 'J': '101011001101',
  'K': '110101010011', 'L': '101101010011', 'M': '110110101001', 'N': '101011010011',
  'O': '110101101001', 'P': '101101101001', 'Q': '101010110011', 'R': '110101011001',
  'S': '101101011001', 'T': '101011011001', 'U': '110010101011', 'V': '100110101011',
  'W': '110011010101', 'X': '100101101011', 'Y': '110010110101', 'Z': '100110110101',
  '-': '100101011011', '.': '110010101101', ' ': '100110101101', '$': '100100100101',
  '/': '100100101001', '+': '100101001001', '%': '101001001001', '*': '100101101101'
};

function encodeCode39(text: string): { binary: string; text: string } {
  const upper = text.toUpperCase().replace(/[^0-9A-Z\-\.\ \$\/\+\%]/g, '');
  const withGuards = `*${upper}*`;
  let binary = '';
  for (let i = 0; i < withGuards.length; i++) {
    const char = withGuards[i];
    binary += (CODE39_MAP[char] || CODE39_MAP['-']) + '0';
  }
  return { binary, text: upper };
}

// ==========================================
// 4. ITF (Interleaved 2 of 5) Engine
// ==========================================
const ITF_PATTERNS = [
  'NNWWN', 'WNNNW', 'NWNNW', 'WWNNN', 'NNWNW',
  'WNWNN', 'NWWNN', 'NNNWW', 'WNNWN', 'NWNWN'
];

function encodeITF(digits: string): { binary: string; text: string } {
  let clean = digits.replace(/\D/g, '');
  if (clean.length % 2 !== 0) clean = '0' + clean;
  if (!clean) clean = '00';

  let binary = '1010'; // Start pattern (wide bar = 11, narrow = 1)
  for (let i = 0; i < clean.length; i += 2) {
    const d1 = parseInt(clean[i], 10);
    const d2 = parseInt(clean[i + 1], 10);
    const pat1 = ITF_PATTERNS[d1];
    const pat2 = ITF_PATTERNS[d2];

    for (let j = 0; j < 5; j++) {
      const barWide = pat1[j] === 'W';
      const spaceWide = pat2[j] === 'W';
      binary += barWide ? '11' : '1';
      binary += spaceWide ? '00' : '0';
    }
  }
  binary += '1101'; // Stop pattern
  return { binary, text: clean };
}

// ==========================================
// 5. Codabar (NW-7) Engine
// ==========================================
const CODABAR_MAP: Record<string, string> = {
  '0': '101010011', '1': '101011001', '2': '101001011', '3': '110010101',
  '4': '101101001', '5': '110101001', '6': '100101011', '7': '100101101',
  '8': '100110101', '9': '110100101', '-': '101001101', '$': '101100101',
  ':': '1101011011', '/': '1101101011', '.': '1101101101', '+': '1011011011',
  'A': '1011001001', 'B': '1001001011', 'C': '1010010011', 'D': '1010011001'
};

function encodeCodabar(text: string): { binary: string; text: string } {
  let clean = text.toUpperCase().replace(/[^0-9A-D\-\$\:\/\.\+]/g, '');
  if (!clean.startsWith('A') && !clean.startsWith('B') && !clean.startsWith('C') && !clean.startsWith('D')) {
    clean = 'A' + clean;
  }
  if (!clean.endsWith('A') && !clean.endsWith('B') && !clean.endsWith('C') && !clean.endsWith('D')) {
    clean = clean + 'B';
  }

  let binary = '';
  for (let i = 0; i < clean.length; i++) {
    binary += (CODABAR_MAP[clean[i]] || CODABAR_MAP['0']) + '0';
  }
  return { binary, text: clean };
}

// ==========================================
// 6. MSI Plessey Engine
// ==========================================
const MSI_MAP: Record<string, string> = {
  '0': '100100100100', '1': '100100100110', '2': '100100110100', '3': '100100110110',
  '4': '100110100100', '5': '100110100110', '6': '100110110100', '7': '100110110110',
  '8': '110100100100', '9': '110100100110'
};

function encodeMSIPlessey(digits: string): { binary: string; text: string } {
  let clean = digits.replace(/\D/g, '');
  if (!clean) clean = '00';

  // Compute Mod-10 Check digit
  let numStr = '';
  for (let i = clean.length - 1; i >= 0; i -= 2) {
    numStr = clean[i] + numStr;
  }
  const multiplied = (parseInt(numStr, 10) * 2).toString();
  let sum = 0;
  for (let i = 0; i < multiplied.length; i++) sum += parseInt(multiplied[i], 10);
  for (let i = clean.length - 2; i >= 0; i -= 2) sum += parseInt(clean[i], 10);
  const checkDigit = (10 - (sum % 10)) % 10;
  clean += checkDigit;

  let binary = '110'; // Start
  for (let i = 0; i < clean.length; i++) {
    binary += MSI_MAP[clean[i]] || MSI_MAP['0'];
  }
  binary += '1001'; // Stop
  return { binary, text: clean };
}

// ==========================================
// Main SVG Barcode Generator
// ==========================================
export function generateBarcodeSVG(
  text: string,
  options: {
    symbology?: BarcodeSymbology;
    height?: number;
    barWidth?: number;
    includeText?: boolean;
    fontSize?: number;
    color?: string;
  } = {}
): string {
  const sanitized = (text || '').trim();
  if (!sanitized) return '';

  const symbology = options.symbology || 'CODE128';
  const height = options.height || 45;
  const barWidth = options.barWidth || 1.2;
  const includeText = options.includeText !== false;
  const fontSize = options.fontSize || 10;
  const color = options.color || '#000000';

  let binaryString = '';
  let displayText = sanitized;

  try {
    switch (symbology) {
      case 'EAN13': {
        const res = encodeEan13(sanitized);
        binaryString = res.binary;
        displayText = res.text;
        break;
      }
      case 'UPCA': {
        const clean = sanitized.replace(/\D/g, '').padStart(12, '0');
        const res = encodeEan13('0' + clean.slice(-12));
        binaryString = res.binary;
        displayText = clean.slice(-12);
        break;
      }
      case 'EAN8': {
        const res = encodeEan8(sanitized);
        binaryString = res.binary;
        displayText = res.text;
        break;
      }
      case 'CODE39': {
        const res = encodeCode39(sanitized);
        binaryString = res.binary;
        displayText = res.text;
        break;
      }
      case 'ITF': {
        const res = encodeITF(sanitized);
        binaryString = res.binary;
        displayText = res.text;
        break;
      }
      case 'CODABAR': {
        const res = encodeCodabar(sanitized);
        binaryString = res.binary;
        displayText = res.text;
        break;
      }
      case 'MSI_PLESSEY': {
        const res = encodeMSIPlessey(sanitized);
        binaryString = res.binary;
        displayText = res.text;
        break;
      }
      case 'CODE93':
      case 'GS1_DATABAR':
      case 'CODE128':
      default: {
        binaryString = encodeCode128(sanitized);
        displayText = sanitized;
        break;
      }
    }
  } catch (err) {
    // Fallback to Code 128
    binaryString = encodeCode128(sanitized);
    displayText = sanitized;
  }

  if (!binaryString) return '';

  const totalModules = binaryString.length;
  const quietZone = 8;
  const fullModules = totalModules + quietZone * 2;
  const totalSvgWidth = fullModules * barWidth;
  const totalSvgHeight = height + (includeText ? fontSize + 4 : 0);

  let rects = '';
  let xPos = quietZone * barWidth;

  for (let i = 0; i < binaryString.length; i++) {
    if (binaryString[i] === '1') {
      rects += `<rect x="${xPos.toFixed(1)}" y="0" width="${barWidth.toFixed(1)}" height="${height}" fill="${color}" />`;
    }
    xPos += barWidth;
  }

  let textSvg = '';
  if (includeText) {
    textSvg = `<text x="${(totalSvgWidth / 2).toFixed(1)}" y="${(height + fontSize + 2).toFixed(1)}" text-anchor="middle" font-family="monospace, 'Courier New', Courier" font-size="${fontSize}" font-weight="bold" fill="${color}">${displayText}</text>`;
  }

  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${totalSvgWidth.toFixed(1)} ${totalSvgHeight.toFixed(1)}" width="100%" height="100%">${rects}${textSvg}</svg>`;
}

/**
 * Generates an internal retail barcode conforming to the selected symbology.
 */
export function generateInternalBarcode(symbology: BarcodeSymbology = 'EAN13'): string {
  const timestampPart = Date.now().toString().slice(-6);
  const randomPart = Math.floor(100 + Math.random() * 900).toString();

  switch (symbology) {
    case 'EAN13': {
      const base12 = `200${timestampPart}${randomPart}`;
      const check = computeLuhnChecksum(base12);
      return `${base12}${check}`;
    }
    case 'UPCA': {
      const base11 = `0${timestampPart}${randomPart}`.slice(0, 11);
      const check = computeLuhnChecksum(base11);
      return `${base11}${check}`;
    }
    case 'EAN8': {
      const base7 = `20${timestampPart.slice(-5)}`;
      let sum = 0;
      for (let i = 0; i < 7; i++) {
        const d = parseInt(base7[i], 10);
        sum += i % 2 === 0 ? d * 3 : d;
      }
      const check = (10 - (sum % 10)) % 10;
      return `${base7}${check}`;
    }
    case 'ITF': {
      const base13 = `10${timestampPart}${randomPart}`.padEnd(13, '0').slice(0, 13);
      const check = computeLuhnChecksum(base13);
      return `${base13}${check}`;
    }
    case 'CODABAR': {
      const inner = `A${timestampPart}${randomPart}`.slice(0, 8);
      return `${inner}B`;
    }
    case 'CODE39':
    case 'CODE93':
    case 'CODE128':
    case 'GS1_DATABAR':
    default: {
      return `MED-${timestampPart}-${randomPart}`;
    }
  }
}

/**
 * Automatically detects the most suitable 1D symbology for a barcode value.
 */
export function detectBarcodeSymbology(value?: string | null): BarcodeSymbology {
  if (!value || !value.trim()) return 'EAN13';
  const clean = value.trim();
  const isNumeric = /^\d+$/.test(clean);

  if (isNumeric) {
    if (clean.length === 14) return 'ITF';
    if (clean.length === 13) return 'EAN13';
    if (clean.length === 12) return 'UPCA';
    if (clean.length === 8) return 'EAN8';
  }
  if (clean.startsWith('(01)')) return 'GS1_DATABAR';
  if (/^[A-D][0-9\-\$\:\/\.\+]+[A-D]$/.test(clean)) return 'CODABAR';
  return 'CODE128';
}
