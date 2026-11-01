import { decode } from 'html-entities';

export type FetchLike = (url: string, init?: any) => Promise<any>;

export interface OgFetchOptions {
  timeoutMs?: number;
  maxBytes?: number;
  fetchFn?: FetchLike;
}

const IMAGE_EXT_RE = /\.(jpe?g|png|webp|gif|avif)(\?|#|$)/i;
// Common tracking pixels, spacers, avatars and feed badges we never want as a hero image.
const JUNK_IMAGE_RE =
  /(feedburner|feeds\.feedblitz|pixel\.|\/pixel|spacer|blank\.gif|1x1|gravatar\.com|\/avatar|emoji|wp-includes\/images|doubleclick|stats\.wp\.com|\/smilies\/|\/smalll?\.png)/i;

// Site-wide fallback share images (not article-specific): matched against the file name only.
const GENERIC_FILENAME_RE =
  /(^|[-_.])(social[-_]?(image|sharing|share|card)|social[-_]\d|og[-_]?default|share[-_]?default|default[-_]?(og|share|social|image|thumb)|placeholder|no[-_]?image|fallback)|[-_]default\.(png|jpe?g|webp|gif)$/i;

/**
 * Pulls a real, article-specific image out of a feed item or the article page.
 * Never returns stock photos: when nothing trustworthy is found the result is undefined.
 */
export class ImageExtractor {
  /**
   * Normalizes and validates a candidate image URL.
   * - decodes HTML entities (feeds frequently encode `&` as `&#038;` / `&amp;`)
   * - resolves protocol-relative and relative URLs against the article URL
   * - only https URLs are accepted (mixed content breaks the web app)
   */
  static validateImageUrl(raw: unknown, baseUrl?: string): string | undefined {
    if (typeof raw !== 'string') return undefined;
    let candidate = decode(raw.trim());
    if (!candidate || candidate.startsWith('data:')) return undefined;

    let parsed: URL;
    try {
      if (candidate.startsWith('//')) candidate = `https:${candidate}`;
      parsed = baseUrl ? new URL(candidate, baseUrl) : new URL(candidate);
    } catch {
      return undefined;
    }

    if (parsed.protocol !== 'https:') return undefined;
    if (!parsed.hostname || !parsed.hostname.includes('.')) return undefined;
    if (JUNK_IMAGE_RE.test(parsed.href)) return undefined;
    const fileName = decodeURIComponent(parsed.pathname.split('/').pop() || '');
    if (GENERIC_FILENAME_RE.test(fileName)) return undefined;
    return parsed.href;
  }

  /** Returns the first <img src> (or data-src / srcset first entry) found in an HTML fragment. */
  static firstImgFromHtml(html: unknown, baseUrl?: string): string | undefined {
    if (typeof html !== 'string' || !html) return undefined;
    const imgTags = html.match(/<img\b[^>]*>/gi) || [];
    for (const tag of imgTags) {
      // Skip explicit tiny images (tracking pixels / icons)
      const w = /\bwidth=["']?(\d+)/i.exec(tag);
      const h = /\bheight=["']?(\d+)/i.exec(tag);
      if ((w && parseInt(w[1], 10) < 120) || (h && parseInt(h[1], 10) < 90)) continue;

      const attrs = ['src', 'data-src', 'data-lazy-src', 'data-original'];
      for (const attr of attrs) {
        const m = new RegExp(`\\b${attr}=["']([^"']+)["']`, 'i').exec(tag);
        if (m) {
          const valid = this.validateImageUrl(m[1], baseUrl);
          if (valid) return valid;
        }
      }
      const srcset = /\bsrcset=["']([^"']+)["']/i.exec(tag);
      if (srcset) {
        const first = srcset[1].split(',')[0]?.trim().split(/\s+/)[0];
        const valid = this.validateImageUrl(first, baseUrl);
        if (valid) return valid;
      }
    }
    return undefined;
  }

  /**
   * Extracts an image from a parsed RSS/Atom item object (fast-xml-parser output with `@_` attributes).
   * Priority: media:content (image) -> media:group -> media:thumbnail -> enclosure (image/*) -> first <img> in content.
   */
  static fromFeedItem(item: any, articleUrl?: string): string | undefined {
    if (!item || typeof item !== 'object') return undefined;

    const asArray = (v: any): any[] => (v == null ? [] : Array.isArray(v) ? v : [v]);
    const isImageMedia = (m: any): boolean => {
      const medium = String(m?.['@_medium'] || '').toLowerCase();
      const type = String(m?.['@_type'] || '').toLowerCase();
      const url = String(m?.['@_url'] || '');
      if (medium === 'image' || type.startsWith('image/')) return true;
      if (medium === 'video' || type.startsWith('video/') || type.startsWith('audio/')) return false;
      return IMAGE_EXT_RE.test(url) || (!medium && !type);
    };

    const tryList = (list: any[], filter = true): string | undefined => {
      // Prefer the largest declared width when multiple renditions exist
      const sorted = [...list].sort(
        (a, b) => (parseInt(b?.['@_width'] || '0', 10) || 0) - (parseInt(a?.['@_width'] || '0', 10) || 0)
      );
      for (const m of sorted) {
        if (filter && !isImageMedia(m)) continue;
        const valid = this.validateImageUrl(m?.['@_url'], articleUrl);
        if (valid) return valid;
      }
      return undefined;
    };

    const mediaContent = tryList(asArray(item['media:content']));
    if (mediaContent) return mediaContent;

    for (const group of asArray(item['media:group'])) {
      const g = tryList(asArray(group?.['media:content'])) || tryList(asArray(group?.['media:thumbnail']), false);
      if (g) return g;
    }

    const thumb = tryList(asArray(item['media:thumbnail']), false);
    if (thumb) return thumb;

    for (const enc of asArray(item.enclosure)) {
      const type = String(enc?.['@_type'] || '').toLowerCase();
      const url = enc?.['@_url'];
      if (type.startsWith('image/') || (!type && IMAGE_EXT_RE.test(String(url || '')))) {
        const valid = this.validateImageUrl(url, articleUrl);
        if (valid) return valid;
      }
    }

    // Atom <link rel="enclosure" type="image/*">
    for (const l of asArray(item.link)) {
      if (l && typeof l === 'object' && l['@_rel'] === 'enclosure' && String(l['@_type'] || '').startsWith('image/')) {
        const valid = this.validateImageUrl(l['@_href'], articleUrl);
        if (valid) return valid;
      }
    }

    const itunesImage = item['itunes:image']?.['@_href'];
    if (itunesImage) {
      const valid = this.validateImageUrl(itunesImage, articleUrl);
      if (valid) return valid;
    }

    const htmlSources = [item['content:encoded'], item.content, item.description, item.summary];
    for (const src of htmlSources) {
      const html = typeof src === 'string' ? src : src?.['#text'];
      const img = this.firstImgFromHtml(html, articleUrl);
      if (img) return img;
    }

    return undefined;
  }

  /** Parses og:image / og:image:secure_url / twitter:image from an HTML document head. */
  static extractOgImage(html: string, pageUrl?: string): string | undefined {
    if (!html) return undefined;
    const metaTags = html.match(/<meta\b[^>]*>/gi) || [];
    const wanted = ['og:image:secure_url', 'og:image', 'og:image:url', 'twitter:image', 'twitter:image:src'];
    const found: Record<string, string> = {};
    for (const tag of metaTags) {
      const key = /\b(?:property|name)=["']([^"']+)["']/i.exec(tag)?.[1]?.toLowerCase();
      const content = /\bcontent=["']([^"']*)["']/i.exec(tag)?.[1];
      if (key && content && wanted.includes(key) && !found[key]) {
        found[key] = content;
      }
    }
    for (const key of wanted) {
      const valid = this.validateImageUrl(found[key], pageUrl);
      if (valid) return valid;
    }
    // Some sites use <link rel="image_src">
    const linkImg = /<link\b[^>]*rel=["']image_src["'][^>]*href=["']([^"']+)["']/i.exec(html)?.[1];
    return this.validateImageUrl(linkImg, pageUrl);
  }

  /**
   * Fetches the article page (timeout + byte cap, reads only until </head>) and returns its og:image.
   * Never throws.
   */
  static async fetchOgImage(pageUrl: string, opts: OgFetchOptions = {}): Promise<string | undefined> {
    const timeoutMs = opts.timeoutMs ?? 6000;
    const maxBytes = opts.maxBytes ?? 512 * 1024;
    const fetchFn: FetchLike | undefined = opts.fetchFn ?? (globalThis.fetch as any);
    if (!fetchFn) return undefined;

    try {
      const target = new URL(pageUrl);
      if (target.protocol !== 'https:' && target.protocol !== 'http:') return undefined;
    } catch {
      return undefined;
    }

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const res = await fetchFn(pageUrl, {
        signal: controller.signal,
        redirect: 'follow',
        headers: {
          'User-Agent':
            'Mozilla/5.0 (compatible; TechDailyBot/1.0; +https://techdaily-prod.web.app) AppleWebKit/537.36 (KHTML, like Gecko)',
          Accept: 'text/html,application/xhtml+xml;q=0.9,*/*;q=0.5',
        },
      });
      if (!res || !res.ok) return undefined;
      const ctype = String(res.headers?.get?.('content-type') || '');
      if (ctype && !ctype.includes('html')) return undefined;

      let html = '';
      const body = res.body;
      if (body && typeof body.getReader === 'function') {
        const reader = body.getReader();
        const decoder = new TextDecoder('utf-8');
        let received = 0;
        while (true) {
          const { done, value } = await reader.read();
          if (done) break;
          received += value.byteLength;
          html += decoder.decode(value, { stream: true });
          if (received >= maxBytes || /<\/head>/i.test(html)) {
            try {
              await reader.cancel();
            } catch {
              /* ignore */
            }
            break;
          }
        }
      } else if (typeof res.text === 'function') {
        html = String(await res.text()).slice(0, maxBytes);
      }

      const finalUrl = typeof res.url === 'string' && res.url ? res.url : pageUrl;
      return this.extractOgImage(html, finalUrl);
    } catch {
      return undefined;
    } finally {
      clearTimeout(timer);
    }
  }
}
