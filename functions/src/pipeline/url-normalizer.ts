import { createHash } from 'crypto';

export class UrlNormalizer {
  private static readonly TRACKING_PARAMS = new Set([
    'utm_source',
    'utm_medium',
    'utm_campaign',
    'utm_term',
    'utm_content',
    'utm_id',
    'fbclid',
    'gclid',
    'msclkid',
    'mc_eid',
    'mc_cid',
    'ref',
    'ref_src',
    'source',
    'sp_source',
    '_hsenc',
    '_hsmi',
    'action_object_map',
    'action_type_map',
    'action_ref_map',
    'mkt_tok',
  ]);

  /**
   * Cleans a raw article URL into a canonical URL:
   * 1. Strips tracking query parameters (utm_*, fbclid, etc.)
   * 2. Removes trailing slashes on subpaths
   * 3. Drops URL fragments (#...)
   * 4. Lowercases hostname
   */
  static canonicalize(rawUrl: string): string {
    const parsed = new URL(rawUrl.trim());

    // Clean tracking query parameters
    const searchParams = new URLSearchParams(parsed.search);
    const keysToDelete: string[] = [];
    searchParams.forEach((_, key) => {
      const lower = key.toLowerCase();
      if (this.TRACKING_PARAMS.has(lower) || lower.startsWith('utm_')) {
        keysToDelete.push(key);
      }
    });
    for (const key of keysToDelete) {
      searchParams.delete(key);
    }

    parsed.search = searchParams.toString();
    parsed.hash = '';

    // Standardize hostname
    parsed.hostname = parsed.hostname.toLowerCase();

    // Clean trailing slash for paths with length > 1
    let pathname = parsed.pathname;
    if (pathname.length > 1 && pathname.endsWith('/')) {
      pathname = pathname.substring(0, pathname.length - 1);
    }
    parsed.pathname = pathname;

    return parsed.toString();
  }

  /**
   * Generates a deterministic document ID for Firestore based on the canonical URL.
   * Format: "art-" + 24-character SHA-256 hex digest.
   */
  static generateArticleId(canonicalUrl: string): string {
    const hash = createHash('sha256').update(canonicalUrl.trim()).digest('hex');
    return `art-${hash.substring(0, 24)}`;
  }

  /**
   * Generates a secondary content fingerprint for duplicate detection
   * based on normalized title and source.
   */
  static generateContentFingerprint(title: string, sourceName: string): string {
    const cleanTitle = title
      .toLowerCase()
      .replace(/[^\w\s]/g, '')
      .replace(/\s+/g, ' ')
      .trim();
    const cleanSource = sourceName.toLowerCase().trim();
    return createHash('sha256').update(`${cleanSource}:${cleanTitle}`).digest('hex');
  }

  /** Path segments that, on their own, describe a section/hub page rather than a single post. */
  private static readonly HUB_SEGMENTS = new Set([
    '', 'news', 'blog', 'blogs', 'newsroom', 'press', 'press-releases', 'releases', 'technology', 'tech',
    'ai', 'feed', 'rss', 'index', 'index.html', 'home', 'latest', 'category', 'categories', 'tag', 'tags',
    'topics', 'topic', 'section', 'sections', 'stories', 'articles', 'en', 'en-us', 'en-in', 'us', 'in',
    'sci-tech', 'science', 'gadgets', 'startups', 'security', 'cybersecurity', 'cloud', 'software',
    'hardware', 'space', 'aws', 'about', 'all', 'archive', 'page',
  ]);

  /**
   * True when a URL points at a publisher homepage or a section hub (e.g. "https://github.blog",
   * "https://blog.google/technology/ai/") instead of an individual post. Such URLs must never be
   * stored as an article's sourceUrl.
   */
  static isHubUrl(rawUrl: string | undefined | null): boolean {
    if (!rawUrl || typeof rawUrl !== 'string') return true;
    let parsed: URL;
    try {
      parsed = new URL(rawUrl.trim());
    } catch {
      return true;
    }
    const segments = parsed.pathname
      .split('/')
      .map((s) => s.trim().toLowerCase())
      .filter((s) => s.length > 0);
    if (segments.length === 0) {
      // Root path: only a post if a query string identifies it (e.g. ?p=123 or ?PRID=...)
      return parsed.search.length <= 1;
    }
    const allHub = segments.every((s) => this.HUB_SEGMENTS.has(s) || /^\d{1,4}$/.test(s));
    if (!allHub) return false;
    // "/2026/10" style date archives or "/news" style sections -> hub unless a query identifies a post
    return parsed.search.length <= 1;
  }
}

