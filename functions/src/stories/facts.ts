/**
 * "Key numbers" chips: prices, dates, percentages, user counts and specs found in the reports.
 * Used directly by the rule-based fallback and to check the AI's keyNumbers (every digit group in
 * a chip must appear in the reports, so a chip can never carry an invented number).
 */

export interface KeyNumber {
  /** "₹49,999", "12%", "3 crore", "15 Nov" */
  value: string;
  /** "Price", "Users", "Sale date" */
  label: string;
}

export const MAX_KEY_NUMBERS = 4;

const MONTHS = 'January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sept|Sep|Oct|Nov|Dec';
const SCALE = '(?:lakh crore|crore|lakh|billion|million|bn|mn|cr|trillion)';
const NUM = '\\d[\\d,]*(?:\\.\\d+)?';

interface Rule {
  re: RegExp;
  value: (m: RegExpExecArray) => string;
  label: (m: RegExpExecArray, before: string) => string;
}

const moneyLabel = (before: string): string => {
  const b = before.toLowerCase();
  if (/\b(rais|fund|invest|valu)\w*\s*$|\b(round|funding|investment|valuation)\b[^.]{0,30}$/.test(b)) return 'Funding';
  if (/\b(fine|penalt|fined)\w*/.test(b.slice(-40))) return 'Fine';
  if (/\b(revenue|sales|turnover)\b/.test(b.slice(-40))) return 'Revenue';
  if (/\b(lost|loss|stole|stolen|duped|cheated|fraud|hack|heist|theft|drained)\w*/.test(b.slice(-60))) return 'Money lost';
  if (/\b(plan|recharge|pack|subscription|per month|monthly)\b/.test(b.slice(-40))) return 'Plan price';
  if (/\b(deal|acquir|buy|bought)\w*/.test(b.slice(-40))) return 'Deal size';
  return 'Price';
};

const tidy = (s: string) => s.replace(/\s+/g, ' ').replace(/\bRs\.?\s?/i, '₹').replace(/\bINR\s?/i, '₹').replace(/₹\s+/, '₹').trim();
const scaleWord = (s?: string) => (s ? ' ' + s.toLowerCase().replace(/^bn$/, 'billion').replace(/^mn$/, 'million').replace(/^cr$/, 'crore') : '');

const RULES: Rule[] = [
  {
    re: new RegExp(`(?:₹|\\bRs\\.?|\\bINR)\\s?(${NUM})(?:\\s?(${SCALE}))?`, 'gi'),
    value: (m) => tidy(`₹${m[1]}${scaleWord(m[2])}`),
    label: (_m, before) => moneyLabel(before),
  },
  {
    re: new RegExp(`(?:\\$|\\bUS\\$|\\bUSD\\s?)(${NUM})(?:\\s?(${SCALE}))?`, 'gi'),
    value: (m) => `$${m[1]}${scaleWord(m[2])}`,
    label: (_m, before) => moneyLabel(before),
  },
  {
    re: new RegExp(`(${NUM})\\s?(%|per cent|percent)`, 'gi'),
    value: (m) => `${m[1]}%`,
    label: (_m, before) => {
      const b = before.toLowerCase().slice(-50);
      if (/\b(hike|rise|rais|increase|jump|up|grew|growth|surge|soar)\w*/.test(b)) return 'Increase';
      if (/\b(cut|drop|fall|fell|decline|down|discount|off)\w*/.test(b)) return 'Cut';
      if (/\b(share|market)\b/.test(b)) return 'Market share';
      return 'Change';
    },
  },
  {
    re: new RegExp(
      `(${NUM})\\s?(${SCALE})?\\+?\\s+(users|customers|subscribers|people|downloads|accounts|employees|jobs|devices|vehicles|units|phones|records|students|merchants|transactions)\\b`,
      'gi'
    ),
    value: (m) => `${m[1]}${scaleWord(m[2])}`,
    label: (m) => m[3].charAt(0).toUpperCase() + m[3].slice(1).toLowerCase(),
  },
  {
    re: new RegExp(`\\b(\\d{1,2})(?:st|nd|rd|th)?\\s(${MONTHS})\\b(?:,?\\s(20\\d\\d))?|\\b(${MONTHS})\\.?\\s(\\d{1,2})(?:st|nd|rd|th)?\\b(?:,?\\s(20\\d\\d))?`, 'g'),
    value: (m) => {
      const d = m[1] ?? m[5];
      const mon = (m[2] ?? m[4]).slice(0, 3);
      const y = m[3] ?? m[6];
      return `${parseInt(d, 10)} ${mon}${y ? ' ' + y : ''}`;
    },
    label: (_m, before) => {
      const b = before.toLowerCase().slice(-50);
      if (/\b(sale|available|availability|buy|order|pre-?order|shipping|deliver)\w*/.test(b)) return 'On sale';
      if (/\b(launch|unveil|debut|release|arriv)\w*/.test(b)) return 'Launch';
      if (/\b(deadline|last date|until|till|by|before|from|effective|starting|begin)\b/.test(b)) return 'Date';
      return 'Date';
    },
  },
  {
    re: /(\d[\d,]*)\s?mAh\b/gi,
    value: (m) => `${m[1]} mAh`,
    label: () => 'Battery',
  },
  {
    re: /(\d{2,3})\s?MP\b/g,
    value: (m) => `${m[1]} MP`,
    label: () => 'Camera',
  },
  {
    re: /(\d+(?:\.\d+)?)\s?(?:km|kilometres|kilometers)\b(?=[^.]{0,20}\b(range|per charge|on a single charge)\b)/gi,
    value: (m) => `${m[1]} km`,
    label: () => 'Range',
  },
];

/** Finds up to `max` distinct key numbers in the text (earliest first, one per label). */
export function extractKeyNumbers(text: string, max = MAX_KEY_NUMBERS): KeyNumber[] {
  const found: Array<KeyNumber & { at: number }> = [];
  const t = (text || '').replace(/\s+/g, ' ');
  for (const rule of RULES) {
    rule.re.lastIndex = 0;
    let m: RegExpExecArray | null;
    while ((m = rule.re.exec(t))) {
      const before = t.slice(Math.max(0, m.index - 80), m.index);
      const value = rule.value(m).trim();
      if (!/\d/.test(value) || value.length > 24) continue;
      // A bare year-like number is not a key number.
      if (/^\d{4}$/.test(value)) continue;
      found.push({ value, label: rule.label(m, before), at: m.index });
    }
  }
  found.sort((a, b) => a.at - b.at);
  const out: KeyNumber[] = [];
  const seenValues = new Set<string>();
  const seenLabels = new Map<string, number>();
  for (const f of found) {
    const key = f.value.toLowerCase();
    if (seenValues.has(key)) continue;
    // Two prices (variants) are useful; one of anything else (date, battery, camera) is enough.
    const cap = /price|funding|revenue|money/i.test(f.label) ? 2 : 1;
    if ((seenLabels.get(f.label) ?? 0) >= cap) continue;
    // "2 Nov" and "2 Nov 2026" are the same date.
    if (/^\d{1,2} [A-Z][a-z]{2}/.test(f.value) && out.some((o) => o.value.slice(0, 6) === f.value.slice(0, 6))) continue;
    if (['Date', 'Launch', 'On sale'].includes(f.label) && out.some((o) => ['Date', 'Launch', 'On sale'].includes(o.label))) continue;
    seenValues.add(key);
    seenLabels.set(f.label, (seenLabels.get(f.label) ?? 0) + 1);
    out.push({ value: f.value, label: f.label });
    if (out.length >= max) break;
  }
  return out;
}

/** Digit groups of a string with thousands separators removed ("₹1,49,999" -> ["149999"]). */
function digitGroups(s: string): string[] {
  return (s.match(/\d[\d,]*(?:\.\d+)?/g) ?? []).map((x) => x.replace(/,/g, ''));
}

/**
 * Keeps the AI's key numbers whose every number appears in the reports (dates: day and month
 * both must appear). Drops malformed items; caps the count.
 */
export function checkKeyNumbers(raw: unknown, sourceText: string, max = MAX_KEY_NUMBERS): KeyNumber[] {
  if (!Array.isArray(raw)) return [];
  const srcDigits = new Set(digitGroups(sourceText));
  const lower = sourceText.toLowerCase();
  const out: KeyNumber[] = [];
  for (const item of raw) {
    if (!item || typeof item !== 'object') continue;
    const value = String((item as any).value ?? '').replace(/\s+/g, ' ').trim();
    const label = String((item as any).label ?? '').replace(/\s+/g, ' ').trim();
    if (!value || !label || value.length > 24 || label.length > 28) continue;
    const groups = digitGroups(value);
    if (!groups.length) continue;
    if (!groups.every((g) => srcDigits.has(g) || srcDigits.has(g.replace(/\.0+$/, '')))) continue;
    const mon = value.match(new RegExp(`\\b(${MONTHS})\\b`, 'i'));
    if (mon && !lower.includes(mon[1].toLowerCase().slice(0, 3))) continue;
    if (out.some((o) => o.value.toLowerCase() === value.toLowerCase())) continue;
    out.push({ value, label });
    if (out.length >= max) break;
  }
  return out;
}
