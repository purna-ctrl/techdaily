import { firestore } from 'firebase-admin';
import {
  TrustedSourceConfig,
  getAllEnabledSources,
  getSourceRegion,
  DEFAULT_MAX_ITEMS_PER_RUN,
} from '../config/sources';
import { DomainValidator } from './domain-validator';
import { UrlNormalizer } from './url-normalizer';
import { ContentNormalizer } from './content-normalizer';
import { FeedParser, RawFeedItem } from './feed-parser';
import { ICategoryClassifier, KeywordCategoryClassifier } from './category-classifier';
import { DuplicateDetector } from './duplicate-detector';
import { AiSummarizer, ServerAiSummarizer, SUMMARY_PROMPT_VERSION } from '../ai';
import { AdminService } from '../admin/admin-service';
import { DailyBriefGenerator } from './daily-brief-generator';
import { ImageExtractor, FetchLike } from './image-extractor';
import { PushService, BREAKING_TOPIC } from '../notifications/push-service';
import { ArticlePriority, SimpleExplanationTranslations } from '../ai/ai-summarizer';

export interface IngestionEngineOptions {
  /** FCM wrapper; defaults to firebase-admin messaging. */
  pushService?: PushService;
  /** Fetch used to read article pages for og:image. null disables page fetches. */
  pageFetch?: FetchLike | null;
  /** Stop starting new items after this many ms (keeps the scheduled function under its timeout). */
  timeBudgetMs?: number;
  /** How many sources are processed in parallel. */
  sourceConcurrency?: number;
  /** Max breaking pushes per run. */
  maxBreakingPushesPerRun?: number;
}

export interface ItemSample {
  title: string;
  sourceUrl: string;
  imageUrl: string | null;
  imageSource: 'feed' | 'og' | null;
  region: string;
  isBreaking: boolean;
  aiModel: string;
  hasTranslations: boolean;
}

/** Only items published within this window can trigger a breaking push. */
export const BREAKING_PUSH_MAX_AGE_MS = 3 * 60 * 60 * 1000;
/** isBreaking is only stored as true for items published within this window. */
export const BREAKING_FLAG_MAX_AGE_MS = 24 * 60 * 60 * 1000;
const BREAKING_KEYWORDS_RE =
  /\b(breaking|zero[- ]day|0-day|actively exploited|emergency directive|global outage|major outage|massive outage|data breach)\b/i;

/** Rule-based breaking detection used when the AI gives no priority. */
export function detectBreakingByRules(title: string, summary: string): boolean {
  return BREAKING_KEYWORDS_RE.test(title) || /\b(actively exploited|emergency directive)\b/i.test(summary);
}

export interface SourceIngestStats {
  sourceId: string;
  sourceName: string;
  status: 'success' | 'failed';
  totalFound: number;
  accepted: number;
  rejected: number;
  duplicates: number;
  nearDuplicates: number;
  withImage: number;
  imagesFromFeed: number;
  imagesFromOgTag: number;
  skippedTimeBudget: number;
  breakingPushes: number;
  error?: string;
  durationMs: number;
  samples?: ItemSample[];
}

export interface IngestSummary {
  startedAt: string;
  completedAt: string;
  sourcesProcessed: number;
  totalArticlesFound: number;
  totalAccepted: number;
  totalDuplicates: number;
  totalRejected: number;
  totalWithImage: number;
  sourcesStats: SourceIngestStats[];
}

export class IngestionEngine {
  private classifier: ICategoryClassifier;
  private duplicateDetector: DuplicateDetector;
  private aiSummarizer: AiSummarizer;
  private adminService: AdminService;
  private pushService: PushService;
  private pageFetch: FetchLike | null;
  private timeBudgetMs: number;
  private sourceConcurrency: number;
  private maxBreakingPushes: number;
  private breakingPushesSent = 0;
  private runStartedAt = Date.now();

  constructor(
    private db?: firestore.Firestore,
    classifier?: ICategoryClassifier,
    private customFetch?: (url: string) => Promise<string>,
    aiSummarizer?: AiSummarizer,
    adminService?: AdminService,
    options: IngestionEngineOptions = {}
  ) {
    this.classifier = classifier ?? new KeywordCategoryClassifier();
    this.duplicateDetector = new DuplicateDetector(db);
    this.aiSummarizer = aiSummarizer ?? new ServerAiSummarizer();
    this.adminService = adminService ?? new AdminService(db);
    this.pushService = options.pushService ?? new PushService();
    // When a custom feed fetcher is injected (tests), page fetches are off unless explicitly provided.
    this.pageFetch =
      options.pageFetch !== undefined ? options.pageFetch : customFetch ? null : (globalThis.fetch as any) ?? null;
    this.timeBudgetMs = options.timeBudgetMs ?? 480_000;
    this.sourceConcurrency = Math.max(1, options.sourceConcurrency ?? 3);
    this.maxBreakingPushes = options.maxBreakingPushesPerRun ?? 3;
  }

  private canReenrichFallback(): boolean {
    const s: any = this.aiSummarizer;
    return typeof s?.hasApiKey === 'function' ? Boolean(s.hasApiKey()) : false;
  }

  /**
   * Runs the complete news collection pipeline across all enabled sources.
   * Isolates source failures so one failing feed never halts the pipeline.
   */
  async runAll(dryRun = false): Promise<IngestSummary> {
    const startedAt = new Date().toISOString();
    const sources = getAllEnabledSources();
    this.runStartedAt = Date.now();
    this.breakingPushesSent = 0;

    console.log(`[IngestionEngine] Starting collection for ${sources.length} sources (dryRun=${dryRun})`);

    // Bounded-concurrency pool over sources; failures are isolated per source.
    const results: SourceIngestStats[] = new Array(sources.length);
    let cursor = 0;
    const worker = async () => {
      while (cursor < sources.length) {
        const idx = cursor++;
        results[idx] = await this.processSource(sources[idx], dryRun, false);
      }
    };
    await Promise.all(Array.from({ length: Math.min(this.sourceConcurrency, sources.length) }, worker));
    const sourcesStats = results;

    // Auto-generate Daily Brief if in live mode with Firestore
    if (!dryRun && this.db) {
      try {
        const briefGen = new DailyBriefGenerator(this.db);
        await briefGen.generateDailyBrief();
      } catch (err: any) {
        console.warn('[IngestionEngine] Daily brief generation deferred:', err.message);
      }
    }

    const completedAt = new Date().toISOString();
    const summary: IngestSummary = {
      startedAt,
      completedAt,
      sourcesProcessed: sourcesStats.length,
      totalArticlesFound: sourcesStats.reduce((acc, s) => acc + s.totalFound, 0),
      totalAccepted: sourcesStats.reduce((acc, s) => acc + s.accepted, 0),
      totalDuplicates: sourcesStats.reduce((acc, s) => acc + s.duplicates, 0),
      totalRejected: sourcesStats.reduce((acc, s) => acc + s.rejected, 0),
      totalWithImage: sourcesStats.reduce((acc, s) => acc + s.withImage, 0),
      sourcesStats,
    };

    console.log('[IngestionEngine] Run completed:', {
      sources: summary.sourcesProcessed,
      accepted: summary.totalAccepted,
      duplicates: summary.totalDuplicates,
      rejected: summary.totalRejected,
    });

    return summary;
  }

  /**
   * Processes a single trusted source feed through all 10 stages of the pipeline.
   */
  async processSource(source: TrustedSourceConfig, dryRun = false, resetClock = true): Promise<SourceIngestStats> {
    const startTime = Date.now();
    if (resetClock) {
      this.runStartedAt = startTime;
    }
    console.log(`[Source: ${source.sourceId}] Fetch start -> ${source.feedUrl}`);

    const stats: SourceIngestStats = {
      sourceId: source.sourceId,
      sourceName: source.sourceName,
      status: 'success',
      totalFound: 0,
      accepted: 0,
      rejected: 0,
      duplicates: 0,
      nearDuplicates: 0,
      withImage: 0,
      imagesFromFeed: 0,
      imagesFromOgTag: 0,
      skippedTimeBudget: 0,
      breakingPushes: 0,
      durationMs: 0,
      samples: [],
    };

    let xmlData: string;
    try {
      xmlData = await this.fetchFeedWithRetry(source.feedUrl);
    } catch (err: any) {
      stats.status = 'failed';
      stats.error = err.message || String(err);
      stats.durationMs = Date.now() - startTime;
      console.error(`[Source: ${source.sourceId}] Fetch failed: ${stats.error}`);
      await this.adminService.recordSourceFailure(source.sourceId, stats.error || 'Fetch failed');
      return stats;
    }

    // Parse feed items
    const parsedItems = FeedParser.parse(xmlData);
    stats.totalFound = parsedItems.length;
    if (parsedItems.length === 0) {
      stats.status = 'failed';
      stats.error = 'Feed returned no parseable RSS/Atom items';
      stats.durationMs = Date.now() - startTime;
      await this.adminService.recordSourceFailure(source.sourceId, stats.error);
      return stats;
    }

    // Newest first, capped per run to protect AI quota and the function timeout.
    const maxItems = source.maxItemsPerRun ?? DEFAULT_MAX_ITEMS_PER_RUN;
    const rawItems = [...parsedItems]
      .sort((a, b) => ContentNormalizer.normalizeDate(b.pubDate).getTime() - ContentNormalizer.normalizeDate(a.pubDate).getTime())
      .slice(0, maxItems);

    for (const item of rawItems) {
      if (Date.now() - this.runStartedAt > this.timeBudgetMs) {
        stats.skippedTimeBudget++;
        continue;
      }
      try {
        const processed = await this.processItem(item, source, dryRun);
        if (processed.status === 'accepted') {
          stats.accepted++;
          if (processed.imageSource) {
            stats.withImage++;
            if (processed.imageSource === 'feed') stats.imagesFromFeed++;
            else stats.imagesFromOgTag++;
          }
          if (processed.pushed) stats.breakingPushes++;
          if (processed.sample && stats.samples!.length < 3) stats.samples!.push(processed.sample);
        } else if (processed.status === 'duplicate') {
          stats.duplicates++;
          if (processed.reason === 'near-duplicate-title') stats.nearDuplicates++;
        } else {
          stats.rejected++;
          console.log(`[Source: ${source.sourceId}] Rejected "${item.title}": ${processed.reason}`);
        }
      } catch (err: any) {
        stats.rejected++;
        console.warn(`[Source: ${source.sourceId}] Error processing item "${item.title}":`, err.message);
      }
    }

    stats.durationMs = Date.now() - startTime;
    await this.adminService.recordSourceSuccess(source.sourceId);

    console.log(
      `[Source: ${source.sourceId}] Result: ${stats.accepted} accepted, ${stats.duplicates} duplicates, ${stats.rejected} rejected (${stats.durationMs}ms)`
    );

    return stats;
  }

  /**
   * Validates, normalizes, deduplicates, extracts an image, synthesizes via AI, and stores an article.
   */
  private async processItem(
    item: RawFeedItem,
    source: TrustedSourceConfig,
    dryRun: boolean
  ): Promise<{
    status: 'accepted' | 'duplicate' | 'rejected';
    reason?: string;
    imageSource?: 'feed' | 'og' | null;
    pushed?: boolean;
    sample?: ItemSample;
  }> {
    // 1. Validate required fields
    if (!item.title || !item.link) {
      return { status: 'rejected', reason: 'Missing title or link' };
    }

    // The exact post URL from the item. Never substitute the publisher homepage / section hub.
    const postUrl = item.link.trim();

    // 2. Validate source domain (Anti-spoofing check)
    const domainCheck = DomainValidator.validate(postUrl, source);
    if (!domainCheck.isValid) {
      return { status: 'rejected', reason: domainCheck.reason };
    }
    if (UrlNormalizer.isHubUrl(postUrl)) {
      return { status: 'rejected', reason: `Item link is a homepage/section hub, not a post: ${postUrl}` };
    }

    // 3. Normalize URL and generate deterministic ID (hash of canonical URL)
    const canonicalUrl = UrlNormalizer.canonicalize(postUrl);
    const articleId = UrlNormalizer.generateArticleId(canonicalUrl);
    const fingerprint = UrlNormalizer.generateContentFingerprint(item.title, source.sourceName);

    // 4. Exact duplicate detection & cost control
    const isDup = await this.duplicateDetector.isDuplicate(
      articleId,
      fingerprint,
      SUMMARY_PROMPT_VERSION,
      this.canReenrichFallback()
    );
    if (isDup) {
      return { status: 'duplicate', reason: 'same-url' };
    }

    // 5. Content normalization
    const cleanTitle = ContentNormalizer.normalizeTitle(item.title);
    if (!cleanTitle) {
      return { status: 'rejected', reason: 'Empty title after normalization' };
    }
    const cleanSummary = ContentNormalizer.normalizeSummary(item.description || '', cleanTitle);
    const publishedAt = ContentNormalizer.normalizeDate(item.pubDate);
    const plainContent = ContentNormalizer.stripHtml(item.description || '').slice(0, 8000);

    // 5b. Near-duplicate title within 48h (same story re-published or syndicated under another URL)
    if (await this.duplicateDetector.isNearDuplicateTitle(cleanTitle, publishedAt, articleId)) {
      this.duplicateDetector.recordSeen(articleId, fingerprint);
      return { status: 'duplicate', reason: 'near-duplicate-title' };
    }

    // 6. Image: feed media first, then the post page's og:image. No stock images.
    let imageUrl: string | undefined = ImageExtractor.validateImageUrl(item.imageUrl, postUrl);
    let imageSource: 'feed' | 'og' | null = imageUrl ? 'feed' : null;
    if (!imageUrl && this.pageFetch) {
      imageUrl = await ImageExtractor.fetchOgImage(postUrl, { fetchFn: this.pageFetch, timeoutMs: 6000, maxBytes: 512 * 1024 });
      if (imageUrl) imageSource = 'og';
    }

    // 7. Baseline fallback classification and editorial structuring
    const fallbackCategory = this.classifier.classify(cleanTitle, cleanSummary, source.defaultCategory);
    const fallbackEditorial = ContentNormalizer.structureEditorial(cleanTitle, cleanSummary, source.sourceName);

    // 8. AI Article Processing & Synthesis
    let finalSummary = cleanSummary;
    let finalWhatHappened = fallbackEditorial.whatHappened;
    let finalWhyItMatters = fallbackEditorial.whyItMatters;
    let finalSimpleExplanation = fallbackEditorial.simpleExplanation;
    let finalKeyPoints = fallbackEditorial.keyPoints;
    let finalCategory = fallbackCategory;
    let translations: SimpleExplanationTranslations | undefined;
    let priority: ArticlePriority | undefined;
    let aiProcessed = false;
    let aiModel = 'none';
    let aiPromptVersion = SUMMARY_PROMPT_VERSION;

    try {
      const aiOutput = await this.aiSummarizer.summarize({
        articleId,
        title: cleanTitle,
        rawContent: plainContent.length >= 15 ? plainContent : cleanTitle,
        sourceName: source.sourceName,
        sourceUrl: postUrl,
        publishedAt: publishedAt.toISOString(),
        categoryHint: fallbackCategory,
      });

      finalSummary = aiOutput.summary;
      finalWhatHappened = aiOutput.whatHappened;
      finalWhyItMatters = aiOutput.whyItMatters;
      finalSimpleExplanation = aiOutput.simpleExplanation;
      finalKeyPoints = aiOutput.keyPoints;
      finalCategory = aiOutput.category;
      translations = aiOutput.simpleExplanationTranslations;
      priority = aiOutput.priority;
      aiProcessed = true;
      aiModel = aiOutput.aiModel;
      aiPromptVersion = aiOutput.aiPromptVersion;
    } catch (err: any) {
      console.warn(
        `[Source: ${source.sourceId}] AI summarization skipped for "${cleanTitle}": ${err.message}. Retaining normalized fallback editorial.`
      );
    }

    // 9. Breaking classification (AI priority, else conservative keyword rules) + recency gate
    const ageMs = Date.now() - publishedAt.getTime();
    const flagged = priority ? priority === 'breaking' : detectBreakingByRules(cleanTitle, finalSummary);
    const isBreaking = flagged && ageMs <= BREAKING_FLAG_MAX_AGE_MS;
    if (!priority) priority = flagged ? 'breaking' : 'normal';
    const region = getSourceRegion(source);

    // 10. Store Firestore document if not dryRun
    let pushed = false;
    if (!dryRun && this.db) {
      const docRef = this.db.collection('articles').doc(articleId);
      const articleDoc: Record<string, any> = {
        id: articleId,
        title: cleanTitle,
        summary: finalSummary,
        simpleExplanation: finalSimpleExplanation,
        simpleExplanationTranslations: translations ?? null,
        category: finalCategory,
        sourceName: source.sourceName,
        sourceUrl: postUrl,
        imageUrl: imageUrl ?? null,
        imageSource,
        publishedAt: firestore.Timestamp.fromDate(publishedAt),
        keyPoints: finalKeyPoints,
        isBreaking,
        priority,
        region,
        whatHappened: finalWhatHappened,
        whyItMatters: finalWhyItMatters,
        createdAt: firestore.FieldValue.serverTimestamp(),
        updatedAt: firestore.FieldValue.serverTimestamp(),
        // Source & Ingestion Metadata
        sourceId: source.sourceId,
        canonicalUrl,
        ingestedAt: firestore.FieldValue.serverTimestamp(),
        processingVersion: 'v5.0.0',
        status: 'published',
        // AI Processing Metadata
        aiProcessed,
        aiModel,
        aiPromptVersion,
        aiProcessedAt: aiProcessed ? firestore.FieldValue.serverTimestamp() : null,
      };

      await docRef.set(articleDoc, { merge: true });

      // Private grounding text for askArticle (not client-readable; see firestore.rules)
      if (plainContent.length > 0) {
        try {
          await this.db.collection('articleSources').doc(articleId).set(
            {
              articleId,
              sourceUrl: postUrl,
              text: plainContent,
              updatedAt: firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );
        } catch (err: any) {
          console.warn(`[Source: ${source.sourceId}] Could not store article source text: ${err.message}`);
        }
      }

      // 11. Breaking push (fresh items only, capped per run, never throws)
      if (isBreaking && ageMs <= BREAKING_PUSH_MAX_AGE_MS && this.breakingPushesSent < this.maxBreakingPushes) {
        this.breakingPushesSent++;
        const id = await this.pushService.sendToTopic(BREAKING_TOPIC, {
          title: `Breaking: ${source.sourceName}`,
          body: cleanTitle,
          imageUrl: imageUrl ?? null,
          data: { articleId, url: postUrl, type: 'breaking' },
        });
        pushed = Boolean(id);
      }
    }

    // Mark as seen for subsequent items in the batch
    this.duplicateDetector.recordSeen(articleId, fingerprint, cleanTitle, publishedAt);

    return {
      status: 'accepted',
      imageSource,
      pushed,
      sample: {
        title: cleanTitle,
        sourceUrl: postUrl,
        imageUrl: imageUrl ?? null,
        imageSource,
        region,
        isBreaking,
        aiModel,
        hasTranslations: Boolean(translations),
      },
    };
  }

  /**
   * Fetches feed with timeout, User-Agent header, and at most 1 retry.
   */
  private async fetchFeedWithRetry(url: string, retries = 1): Promise<string> {
    if (this.customFetch) {
      return this.customFetch(url);
    }

    let lastError: any;
    for (let attempt = 0; attempt <= retries; attempt++) {
      try {
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), 15000); // 15-second timeout

        const response = await fetch(url, {
          signal: controller.signal,
          headers: {
            'User-Agent': 'Mozilla/5.0 (compatible; TechDailyBot/1.0; +https://techdaily-prod.web.app)',
            Accept: 'application/rss+xml, application/atom+xml, application/xml, text/xml;q=0.9, */*;q=0.5',
          },
        });

        clearTimeout(timeout);

        if (!response.ok) {
          throw new Error(`HTTP ${response.status} ${response.statusText}`);
        }

        return await response.text();
      } catch (err: any) {
        lastError = err;
        if (attempt < retries) {
          // Backoff before retry
          await new Promise((res) => setTimeout(res, 1000));
        }
      }
    }

    throw lastError || new Error(`Failed to fetch ${url}`);
  }
}
