import { firestore } from 'firebase-admin';

const STOP_WORDS = new Set([
  'a', 'an', 'the', 'and', 'or', 'of', 'to', 'in', 'on', 'for', 'with', 'at', 'by', 'from', 'is', 'are',
  'was', 'were', 'be', 'its', 'it', 'as', 'that', 'this', 'how', 'why', 'what', 'new', 'now', 'just',
]);

export const NEAR_DUPLICATE_WINDOW_MS = 48 * 60 * 60 * 1000;
export const TITLE_SIMILARITY_THRESHOLD = 0.8;

interface RecentTitle {
  articleId: string;
  tokens: Set<string>;
  normalized: string;
  publishedAtMs: number;
}

export class TitleSimilarity {
  /** Lowercases, strips punctuation/quotes/diacritics-insensitive separators, and collapses whitespace. */
  static normalize(title: string): string {
    return (title || '')
      .normalize('NFKC')
      .toLowerCase()
      .replace(/[\u2018\u2019\u201c\u201d'"`]/g, '')
      .replace(/[^\p{L}\p{N}\s]/gu, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }

  static tokens(title: string): Set<string> {
    const words = this.normalize(title)
      .split(' ')
      .filter((w) => w.length > 1 && !STOP_WORDS.has(w));
    return new Set(words);
  }

  /** Dice coefficient over significant word tokens, 0..1. Identical normalized titles score 1. */
  static similarity(a: string, b: string): number {
    const na = this.normalize(a);
    const nb = this.normalize(b);
    if (!na || !nb) return 0;
    if (na === nb) return 1;
    return this.diceOfSets(this.tokens(a), this.tokens(b));
  }

  static diceOfSets(ta: Set<string>, tb: Set<string>): number {
    if (ta.size === 0 || tb.size === 0) return 0;
    let inter = 0;
    for (const t of ta) if (tb.has(t)) inter++;
    return (2 * inter) / (ta.size + tb.size);
  }
}

export class DuplicateDetector {
  private batchSeenIds = new Set<string>();
  private batchSeenFingerprints = new Set<string>();
  private recentTitles: RecentTitle[] = [];
  private recentTitlesLoaded = false;
  private recentTitlesLoading?: Promise<void>;

  constructor(private db?: firestore.Firestore) {}

  /**
   * Checks whether the article has already been ingested / AI-processed:
   * 1. Checks current in-memory run batch
   * 2. If Firestore is available, checks `articles/{articleId}`
   * Cost Control: If article already has aiProcessed = true, it is skipped to avoid redundant AI costs.
   * When `allowReenrichFallback` is true, articles that were only summarized by the rule-based
   * fallback are NOT treated as duplicates so Gemini can enrich them once a key is available.
   */
  async isDuplicate(
    articleId: string,
    contentFingerprint?: string,
    targetPromptVersion = 'v1',
    allowReenrichFallback = false
  ): Promise<boolean> {
    if (this.batchSeenIds.has(articleId)) {
      return true;
    }
    if (contentFingerprint && this.batchSeenFingerprints.has(contentFingerprint)) {
      return true;
    }

    if (this.db) {
      try {
        const doc = await this.db.collection('articles').doc(articleId).get();
        if (doc.exists) {
          const data = doc.data();
          if (data?.aiProcessed === true) {
            const isFallbackOnly = typeof data?.aiModel === 'string' && data.aiModel.startsWith('techdaily-editorial-engine');
            if (allowReenrichFallback && isFallbackOnly) {
              return false;
            }
            this.recordSeen(articleId, contentFingerprint);
            return true;
          }
          // Exists but not AI processed -> allow AI enrichment
          return false;
        }
      } catch {
        // Firestore read failure (offline / dry-run): rely on batch dedupe
      }
    }

    return false;
  }

  /**
   * Near-duplicate title check: true when another article (stored in Firestore or seen earlier
   * in this run) published within 48h of `publishedAt` has a normalized title similarity
   * >= TITLE_SIMILARITY_THRESHOLD. `excludeArticleId` lets an article match itself during re-enrichment.
   */
  async isNearDuplicateTitle(title: string, publishedAt: Date, excludeArticleId?: string): Promise<boolean> {
    await this.ensureRecentTitlesLoaded();
    const tokens = TitleSimilarity.tokens(title);
    const normalized = TitleSimilarity.normalize(title);
    const ts = publishedAt.getTime();
    for (const r of this.recentTitles) {
      if (excludeArticleId && r.articleId === excludeArticleId) continue;
      if (Math.abs(r.publishedAtMs - ts) > NEAR_DUPLICATE_WINDOW_MS) continue;
      if (r.normalized === normalized) return true;
      if (TitleSimilarity.diceOfSets(tokens, r.tokens) >= TITLE_SIMILARITY_THRESHOLD) return true;
    }
    return false;
  }

  private async ensureRecentTitlesLoaded(): Promise<void> {
    if (this.recentTitlesLoaded || !this.db) return;
    if (!this.recentTitlesLoading) {
      this.recentTitlesLoading = (async () => {
        try {
          const since = new Date(Date.now() - NEAR_DUPLICATE_WINDOW_MS * 2);
          const snap = await this.db!
            .collection('articles')
            .where('publishedAt', '>=', firestore.Timestamp.fromDate(since))
            .select('title', 'publishedAt')
            .limit(2000)
            .get();
          for (const doc of snap.docs) {
            const d = doc.data();
            const pub = d.publishedAt?.toDate?.() ?? new Date(d.publishedAt);
            if (typeof d.title === 'string' && !isNaN(pub.getTime())) {
              this.addRecentTitle(doc.id, d.title, pub);
            }
          }
        } catch (err: any) {
          console.warn('[DuplicateDetector] Could not preload recent titles:', err?.message);
        } finally {
          this.recentTitlesLoaded = true;
        }
      })();
    }
    await this.recentTitlesLoading;
  }

  private addRecentTitle(articleId: string, title: string, publishedAt: Date): void {
    this.recentTitles.push({
      articleId,
      tokens: TitleSimilarity.tokens(title),
      normalized: TitleSimilarity.normalize(title),
      publishedAtMs: publishedAt.getTime(),
    });
  }

  /**
   * Records an article ID, fingerprint and (optionally) its title as seen for the rest of the session.
   */
  recordSeen(articleId: string, contentFingerprint?: string, title?: string, publishedAt?: Date): void {
    this.batchSeenIds.add(articleId);
    if (contentFingerprint) {
      this.batchSeenFingerprints.add(contentFingerprint);
    }
    if (title) {
      this.addRecentTitle(articleId, title, publishedAt ?? new Date());
    }
  }

  clearBatch(): void {
    this.batchSeenIds.clear();
    this.batchSeenFingerprints.clear();
    this.recentTitles = [];
    this.recentTitlesLoaded = false;
    this.recentTitlesLoading = undefined;
  }
}
