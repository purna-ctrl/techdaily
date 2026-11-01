import { createHash } from 'crypto';

export function sha(s: string, len = 12): string {
  return createHash('sha256').update(s).digest('hex').slice(0, len);
}

/** Lowercase, ASCII-folded, hyphenated slug of at most `maxWords` words / 70 chars. */
export function slugify(text: string, maxWords = 10): string {
  const base = (text || '')
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/&/g, ' and ')
    .replace(/['\u2018\u2019]/g, '')
    .replace(/[^a-z0-9]+/g, ' ')
    .trim()
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, maxWords)
    .join('-');
  return base.slice(0, 70).replace(/-+$/g, '');
}

/** Stable story slug: words from the first headline plus a short hash of the story id. */
export function storySlug(headline: string, storyId: string): string {
  const words = slugify(headline) || 'story';
  return `${words}-${sha(storyId, 6)}`;
}

export function storyIdFor(canonicalUrl: string): string {
  return `st-${sha(canonicalUrl, 20)}`;
}

/** Strips publisher suffixes like " - The Verge" / " | Inc42" and squeezes whitespace. */
export function cleanHeadline(title: string, sourceName?: string): string {
  let t = (title || '').replace(/\s+/g, ' ').trim();
  if (sourceName) {
    const esc = sourceName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    t = t.replace(new RegExp(`\\s*[-|–—:]\\s*${esc}\\s*$`, 'i'), '');
  }
  return t.replace(/\s*\|\s*[^|]{2,30}$/, '').trim();
}

export function truncate(text: string, max: number): string {
  const t = (text || '').trim();
  if (t.length <= max) return t;
  const cut = t.slice(0, max - 1);
  const sp = cut.lastIndexOf(' ');
  return `${(sp > max * 0.6 ? cut.slice(0, sp) : cut).replace(/[\s,;:.-]+$/, '')}…`;
}

export function escapeHtml(s: string): string {
  return String(s ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

export function escapeXml(s: string): string {
  return escapeHtml(s).replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/g, '');
}

/** JSON safe to embed inside <script type="application/ld+json">. */
export function jsonForScript(value: unknown): string {
  return JSON.stringify(value)
    .replace(/</g, '\\u003c')
    .replace(/>/g, '\\u003e')
    .replace(/&/g, '\\u0026')
    .replace(/\u2028/g, '\\u2028')
    .replace(/\u2029/g, '\\u2029');
}

/** Words of a text lowercased and stripped of punctuation (for copy detection). */
export function wordList(text: string): string[] {
  return (text || '')
    .toLowerCase()
    .normalize('NFKC')
    .replace(/[\u2018\u2019'"`]/g, '')
    .replace(/[^\p{L}\p{N}]+/gu, ' ')
    .trim()
    .split(' ')
    .filter(Boolean);
}

/**
 * Returns the first run of `n` consecutive words that appears in both `output` and any of `sources`,
 * or null. Used to reject AI text that copies the original articles.
 */
export function findCopiedRun(output: string, sources: string[], n = 10): string | null {
  const grams = new Set<string>();
  for (const s of sources) {
    const w = wordList(s);
    for (let i = 0; i + n <= w.length; i++) grams.add(w.slice(i, i + n).join(' '));
  }
  if (grams.size === 0) return null;
  const o = wordList(output);
  for (let i = 0; i + n <= o.length; i++) {
    const g = o.slice(i, i + n).join(' ');
    if (grams.has(g)) return g;
  }
  return null;
}

/** "2026-11-01" in Asia/Kolkata. */
export function istDate(d: Date): string {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Kolkata',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(d);
  const g = (t: string) => parts.find((p) => p.type === t)?.value ?? '00';
  return `${g('year')}-${g('month')}-${g('day')}`;
}

/** "1 Nov 2026, 8:05 pm IST" */
export function formatIst(iso: string): string {
  const d = new Date(iso);
  if (isNaN(d.getTime())) return '';
  const s = new Intl.DateTimeFormat('en-IN', {
    timeZone: 'Asia/Kolkata',
    day: 'numeric',
    month: 'short',
    year: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
    hour12: true,
  }).format(d);
  return `${s.replace(/\s?(am|pm)$/i, (m) => ' ' + m.trim().toLowerCase())} IST`;
}
