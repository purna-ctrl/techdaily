/**
 * Story images: the publisher's own lead image, hotlinked (URL only — never downloaded or rehosted)
 * and always shown with a visible "Image: <Source>" credit that links to the source article.
 *
 * 1. At ingest each feed item's image is read from the RSS/Atom item (media:content, media:group,
 *    media:thumbnail, enclosure, first <img> in the content), with any declared width/height.
 * 2. The best image across a story's sources is kept (og:image and larger images win).
 * 3. Stories still without an image get ONE article-page fetch per run (5 s timeout, reads only the
 *    <head>) for og:image / twitter:image. The same step backfills older stories, capped per run.
 *
 * Junk is filtered out: non-https URLs, GIF/SVG, logos, icons, avatars, sprites, tracking pixels,
 * placeholders and anything declared smaller than 200x120.
 */
import { decode } from 'html-entities';
import { ImageExtractor, FetchLike } from '../pipeline/image-extractor';
import type { Story, StorySource } from './types';

export type ImageOrigin = 'og' | 'media' | 'thumbnail' | 'enclosure' | 'html';

export interface ImageCandidate {
  url: string;
  width?: number;
  height?: number;
  origin: ImageOrigin;
}

/** What a story stores and the app/static pages show. */
export interface StoryImage {
  url: string;
  /** Publisher the image belongs to (shown as "Image: <sourceName>"). */
  sourceName: string;
  /** The source article the credit links to. */
  sourceUrl: string;
  width?: number;
  height?: number;
}

const MIN_WIDTH = 200;
const MIN_HEIGHT = 120;
const BAD_EXT_RE = /\.(gif|svg|ico|bmp)(\?|#|$)/i;
// Whole path segments / filename tokens that mark site chrome rather than a news photo.
const CHROME_TOKEN_RE =
  /(^|[\/_\-.])(logo|logos|logotype|icon|icons|favicon|apple-touch-icon|avatar|avatars|sprite|sprites|badge|badges|placeholder|default-image|no-image|blank|spacer|1x1|gravatar|authors?|headshot|emoji)([\/_\-.]|$)/i;
const TRACKER_HOST_RE = /(^|\.)(doubleclick\.net|google-analytics\.com|googletagmanager\.com|scorecardresearch\.com|feedburner\.com|feedblitz\.com|stats\.wp\.com|pixel\.[a-z.]+|quantserve\.com|chartbeat\.net)$/i;
// Size hints in query strings (?w=150, &width=96, resize=100,100).
const SIZE_PARAM_RE = /[?&](?:w|width|resize|fit)=(\d{1,4})/i;

function int(v: unknown): number | undefined {
  const n = parseInt(String(v ?? ''), 10);
  return Number.isFinite(n) && n > 0 && n < 20000 ? n : undefined;
}

/**
 * Returns the cleaned https URL when it looks like a real article photo, else undefined.
 * Width/height are the sizes the feed/page declared (when it did).
 */
export function usableImageUrl(raw: unknown, baseUrl?: string, width?: number, height?: number): string | undefined {
  const url = ImageExtractor.validateImageUrl(raw, baseUrl);
  if (!url) return undefined;
  let u: URL;
  try {
    u = new URL(url);
  } catch {
    return undefined;
  }
  if (u.protocol !== 'https:') return undefined;
  if (TRACKER_HOST_RE.test(u.hostname)) return undefined;
  const path = decodeURIComponent(u.pathname).toLowerCase();
  if (BAD_EXT_RE.test(path)) return undefined;
  if (CHROME_TOKEN_RE.test(path)) return undefined;
  if (width !== undefined && width < MIN_WIDTH) return undefined;
  if (height !== undefined && height < MIN_HEIGHT) return undefined;
  const sizeHint = SIZE_PARAM_RE.exec(u.search);
  if (sizeHint && parseInt(sizeHint[1], 10) < MIN_WIDTH) return undefined;
  // WordPress thumbnails: name-150x150.jpg
  const wp = /-(\d{2,4})x(\d{2,4})\.(jpe?g|png|webp|avif)$/i.exec(path);
  if (wp && (parseInt(wp[1], 10) < MIN_WIDTH || parseInt(wp[2], 10) < MIN_HEIGHT)) return undefined;
  return url;
}

function candidate(raw: unknown, base: string | undefined, origin: ImageOrigin, w?: unknown, h?: unknown): ImageCandidate | undefined {
  const width = int(w);
  const height = int(h);
  const url = usableImageUrl(raw, base, width, height);
  if (!url) return undefined;
  return { url, origin, ...(width ? { width } : {}), ...(height ? { height } : {}) };
}

const asArray = (v: any): any[] => (v == null ? [] : Array.isArray(v) ? v : [v]);

function isImageMedia(m: any): boolean {
  const medium = String(m?.['@_medium'] || '').toLowerCase();
  const type = String(m?.['@_type'] || '').toLowerCase();
  if (medium === 'image' || type.startsWith('image/')) return true;
  if (medium || type) return false;
  return true; // undeclared: judged by the URL filters
}

/** Largest usable entry of a media:* list. */
function bestOf(list: any[], origin: ImageOrigin, base?: string, filter = true): ImageCandidate | undefined {
  const found = list
    .filter((m) => !filter || isImageMedia(m))
    .map((m) => candidate(m?.['@_url'], base, origin, m?.['@_width'], m?.['@_height']))
    .filter((c): c is ImageCandidate => Boolean(c));
  return found.sort((a, b) => (b.width ?? 0) - (a.width ?? 0))[0];
}

/** First usable <img> in an HTML fragment (with its declared size). */
export function firstImgCandidate(html: unknown, base?: string): ImageCandidate | undefined {
  if (typeof html !== 'string' || !html) return undefined;
  const tags = html.match(/<img\b[^>]*>/gi) || [];
  for (const tag of tags) {
    const w = /\bwidth=["']?(\d+)/i.exec(tag)?.[1];
    const h = /\bheight=["']?(\d+)/i.exec(tag)?.[1];
    for (const attr of ['data-src', 'data-lazy-src', 'data-original', 'src']) {
      const m = new RegExp(`\\b${attr}=["']([^"']+)["']`, 'i').exec(tag);
      const c = m && candidate(m[1], base, 'html', w, h);
      if (c) return c;
    }
    const srcset = /\bsrcset=["']([^"']+)["']/i.exec(tag)?.[1];
    if (srcset) {
      // Largest srcset entry ("url 1200w").
      const entries = srcset
        .split(',')
        .map((p) => p.trim().split(/\s+/))
        .map(([u, d]) => ({ u, w: int(String(d || '').replace(/w$/, '')) }))
        .sort((a, b) => (b.w ?? 0) - (a.w ?? 0));
      for (const e of entries) {
        const c = candidate(e.u, base, 'html', e.w);
        if (c) return c;
      }
    }
  }
  return undefined;
}

/**
 * Image of one parsed RSS/Atom item (fast-xml-parser output, `@_` attributes).
 * Priority: media:content → media:group → media:thumbnail → enclosure → first <img> in the content.
 */
export function feedImageCandidate(item: any, articleUrl?: string): ImageCandidate | undefined {
  if (!item || typeof item !== 'object') return undefined;
  const media = bestOf(asArray(item['media:content']), 'media', articleUrl);
  if (media) return media;
  for (const g of asArray(item['media:group'])) {
    const c = bestOf(asArray(g?.['media:content']), 'media', articleUrl) || bestOf(asArray(g?.['media:thumbnail']), 'thumbnail', articleUrl, false);
    if (c) return c;
  }
  const thumb = bestOf(asArray(item['media:thumbnail']), 'thumbnail', articleUrl, false);
  if (thumb) return thumb;
  for (const enc of asArray(item.enclosure)) {
    const type = String(enc?.['@_type'] || '').toLowerCase();
    if (type && !type.startsWith('image/')) continue;
    const c = candidate(enc?.['@_url'], articleUrl, 'enclosure');
    if (c) return c;
  }
  for (const l of asArray(item.link)) {
    if (l && typeof l === 'object' && l['@_rel'] === 'enclosure' && String(l['@_type'] || '').startsWith('image/')) {
      const c = candidate(l['@_href'], articleUrl, 'enclosure');
      if (c) return c;
    }
  }
  for (const src of [item['content:encoded'], item.content, item.description, item.summary]) {
    const html = typeof src === 'string' ? src : src?.['#text'];
    const c = firstImgCandidate(typeof html === 'string' ? decodeIfEscaped(html) : html, articleUrl);
    if (c) return c;
  }
  return undefined;
}

/** Some feeds escape the HTML in <description> (&lt;img ...&gt;). */
function decodeIfEscaped(html: string): string {
  return /&lt;img/i.test(html) ? decode(html) : html;
}

/** Reads og:image (+ declared size) / twitter:image from an HTML <head>. */
export function ogImageCandidate(html: string, pageUrl?: string): ImageCandidate | undefined {
  if (!html) return undefined;
  const metas = html.match(/<meta\b[^>]*>/gi) || [];
  const found: Record<string, string> = {};
  for (const tag of metas) {
    const key = /\b(?:property|name|itemprop)=["']([^"']+)["']/i.exec(tag)?.[1]?.toLowerCase();
    const content = /\bcontent=["']([^"']*)["']/i.exec(tag)?.[1];
    if (key && content && !(key in found)) found[key] = content;
  }
  const w = found['og:image:width'];
  const h = found['og:image:height'];
  for (const key of ['og:image:secure_url', 'og:image', 'og:image:url']) {
    const c = candidate(found[key], pageUrl, 'og', w, h);
    if (c) return c;
  }
  for (const key of ['twitter:image', 'twitter:image:src', 'image']) {
    const c = candidate(found[key], pageUrl, 'og');
    if (c) return c;
  }
  return undefined;
}

/** Higher is better: declared width when known, otherwise a typical size for where it came from. */
export function imageScore(c: Pick<ImageCandidate, 'width' | 'height'> & { origin?: ImageOrigin }): number {
  const typical: Record<ImageOrigin, number> = { og: 1200, media: 800, enclosure: 700, html: 600, thumbnail: 320 };
  const w = c.width ?? typical[c.origin ?? 'media'];
  const bonus = c.origin === 'og' ? 50 : 0;
  // Very tall/narrow images crop badly into 16:9 heroes.
  const ratio = c.width && c.height ? c.width / c.height : 1.6;
  const shape = ratio < 0.8 ? 0.6 : 1;
  return Math.min(w, 2400) * shape + bonus;
}

export interface SourcedCandidate {
  candidate: ImageCandidate;
  sourceName: string;
  sourceUrl: string;
}

export function toStoryImage(c: SourcedCandidate): StoryImage {
  return {
    url: c.candidate.url,
    sourceName: c.sourceName,
    sourceUrl: c.sourceUrl,
    ...(c.candidate.width ? { width: c.candidate.width } : {}),
    ...(c.candidate.height ? { height: c.candidate.height } : {}),
  };
}

/** Best image across a cluster's sources; ties go to the earlier (lead) source. */
export function pickBestImage(list: Array<SourcedCandidate | undefined | null>): StoryImage | null {
  let best: SourcedCandidate | null = null;
  for (const c of list) {
    if (!c) continue;
    if (!best || imageScore(c.candidate) > imageScore(best.candidate)) best = c;
  }
  return best ? toStoryImage(best) : null;
}

/** Score of an image already on a story (origin unknown, so typical "media" size). */
export function storedImageScore(img: StoryImage): number {
  return imageScore({ width: img.width, height: img.height, origin: 'media' });
}

/** Normalises an image read back from Firestore / JSON. */
export function parseStoryImage(v: any): StoryImage | null {
  if (!v || typeof v !== 'object') return null;
  const url = usableImageUrl(v.url, undefined, int(v.width), int(v.height));
  if (!url) return null;
  const sourceUrl = typeof v.sourceUrl === 'string' && /^https?:\/\//.test(v.sourceUrl) ? v.sourceUrl : '';
  const sourceName = typeof v.sourceName === 'string' ? v.sourceName : '';
  if (!sourceUrl || !sourceName) return null;
  const width = int(v.width);
  const height = int(v.height);
  return { url, sourceName, sourceUrl, ...(width ? { width } : {}), ...(height ? { height } : {}) };
}

// ---------------------------------------------------------------------------------------------
// Article-page fetch (og:image) for stories without a feed image, and backfill
// ---------------------------------------------------------------------------------------------

const PAGE_UA =
  'Mozilla/5.0 (compatible; TechDailyBot/2.0; +https://techdaily-prod.web.app) AppleWebKit/537.36 (KHTML, like Gecko)';

/** Fetches an article page (reads only up to </head>, 400 KB max) and returns its og:image. Never throws. */
export async function fetchOgImage(pageUrl: string, opts: { timeoutMs?: number; fetchFn?: FetchLike } = {}): Promise<ImageCandidate | undefined> {
  const fetchFn: FetchLike | undefined = opts.fetchFn ?? (globalThis.fetch as any);
  if (!fetchFn) return undefined;
  try {
    const u = new URL(pageUrl);
    if (u.protocol !== 'https:' && u.protocol !== 'http:') return undefined;
  } catch {
    return undefined;
  }
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), opts.timeoutMs ?? 5000);
  try {
    const res = await fetchFn(pageUrl, {
      signal: controller.signal,
      redirect: 'follow',
      headers: { 'User-Agent': PAGE_UA, Accept: 'text/html,application/xhtml+xml;q=0.9,*/*;q=0.5' },
    });
    if (!res || !res.ok) return undefined;
    const ctype = String(res.headers?.get?.('content-type') || '');
    if (ctype && !/html|xml/i.test(ctype)) return undefined;
    let html = '';
    const body = res.body;
    if (body && typeof body.getReader === 'function') {
      const reader = body.getReader();
      const dec = new TextDecoder('utf-8');
      let n = 0;
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        n += value.byteLength;
        html += dec.decode(value, { stream: true });
        if (n >= 400 * 1024 || /<\/head>/i.test(html)) {
          try {
            await reader.cancel();
          } catch {
            /* ignore */
          }
          break;
        }
      }
    } else if (typeof res.text === 'function') {
      html = String(await res.text()).slice(0, 400 * 1024);
    }
    const finalUrl = typeof res.url === 'string' && res.url ? res.url : pageUrl;
    return ogImageCandidate(html, finalUrl);
  } catch {
    return undefined;
  } finally {
    clearTimeout(timer);
  }
}

export interface ImageResolveStats {
  fetches: number;
  hits: number;
  /** Older stories (not otherwise changed this run) that got an image. */
  backfilled: number;
}

/** Which source page to try for a story on its Nth attempt (lead source first, then the others). */
export function sourceToTry(s: Pick<Story, 'sources'>, attempt: number): StorySource | undefined {
  const list = s.sources.filter((x) => /^https?:\/\//.test(x.url));
  return list.length ? list[attempt % list.length] : undefined;
}

export const MAX_IMAGE_TRIES = 3;

/**
 * One og:image fetch per story (no image yet, fewer than MAX_IMAGE_TRIES attempts), newest first,
 * `changed` stories before backfill candidates, at most `budget` fetches. Returns the updated
 * stories (hits get `updatedAt = nowIso`; misses only count the attempt).
 */
export async function resolveMissingImages(
  changed: Story[],
  backlog: Story[],
  opts: { budget: number; nowIso: string; concurrency?: number; timeoutMs?: number; fetchOg?: (url: string) => Promise<ImageCandidate | undefined> }
): Promise<{ updated: Story[]; stats: ImageResolveStats; tried: Map<string, string> }> {
  const need = (s: Story) => !s.image && (s.imageTries ?? 0) < MAX_IMAGE_TRIES && s.sources.length > 0;
  const changedIds = new Set(changed.map((s) => s.id));
  const queue = [
    ...changed.filter(need).sort((a, b) => b.publishedAt.localeCompare(a.publishedAt)),
    ...backlog.filter((s) => !changedIds.has(s.id) && need(s)).sort((a, b) => b.publishedAt.localeCompare(a.publishedAt)),
  ].slice(0, Math.max(0, opts.budget));
  const fetchOg = opts.fetchOg ?? ((url: string) => fetchOgImage(url, { timeoutMs: opts.timeoutMs ?? 5000 }));
  const stats: ImageResolveStats = { fetches: 0, hits: 0, backfilled: 0 };
  const updated: Story[] = [];
  const tried = new Map<string, string>(); // storyId -> sourceId/name tried
  let cursor = 0;
  const worker = async () => {
    while (cursor < queue.length) {
      const s = queue[cursor++];
      const tries = s.imageTries ?? 0;
      const src = sourceToTry(s, tries);
      if (!src) continue;
      stats.fetches++;
      tried.set(s.id, src.sourceId || src.name);
      const c = await fetchOg(src.url);
      if (c) {
        stats.hits++;
        if (!changedIds.has(s.id)) stats.backfilled++;
        updated.push({ ...s, image: toStoryImage({ candidate: c, sourceName: src.name, sourceUrl: src.url }), imageTries: tries + 1, updatedAt: opts.nowIso });
      } else {
        updated.push({ ...s, imageTries: tries + 1 });
      }
    }
  };
  await Promise.all(Array.from({ length: Math.max(1, Math.min(opts.concurrency ?? 6, queue.length || 1)) }, worker));
  return { updated, stats, tried };
}
