import { firestore } from 'firebase-admin';
import { TRUSTED_SOURCE_REGISTRY, TrustedSourceConfig } from '../config/sources';
import { StructuredLogger } from '../monitoring/logger';
import { UrlNormalizer } from '../pipeline/url-normalizer';

export interface PurgeResult {
  scanned: number;
  matched: number;
  deleted: number;
  dryRun: boolean;
  sample: { id: string; reason: string; sourceUrl?: string }[];
}

export interface SourceHealthRecord {
  sourceId: string;
  sourceName: string;
  domain: string;
  feedUrl: string;
  enabled: boolean;
  defaultCategory: string;
  lastSuccessfulFetch?: string;
  lastFailure?: string;
  failureCount: number;
}

export class AdminService {
  private inMemoryHealth: Map<string, SourceHealthRecord> = new Map();

  constructor(private db?: firestore.Firestore) {
    // Initialize health records with defaults from trusted source registry
    for (const src of TRUSTED_SOURCE_REGISTRY) {
      this.inMemoryHealth.set(src.sourceId, {
        sourceId: src.sourceId,
        sourceName: src.sourceName,
        domain: src.domain,
        feedUrl: src.feedUrl,
        enabled: src.enabled,
        defaultCategory: src.defaultCategory,
        failureCount: 0,
      });
    }
  }

  /**
   * Records a successful fetch for a source feed.
   */
  async recordSourceSuccess(sourceId: string): Promise<void> {
    const record = this.inMemoryHealth.get(sourceId);
    if (record) {
      record.lastSuccessfulFetch = new Date().toISOString();
      record.failureCount = 0;
    }

    if (this.db) {
      try {
        await this.db.collection('sourceHealth').doc(sourceId).set(
          {
            lastSuccessfulFetch: firestore.FieldValue.serverTimestamp(),
            failureCount: 0,
            status: 'healthy',
          },
          { merge: true }
        );
      } catch (_) {}
    }

    StructuredLogger.info('source_fetch_success', `Source ${sourceId} fetch succeeded`, {
      sourceId,
    });
  }

  /**
   * Records a failure for a source feed without crashing the pipeline.
   */
  async recordSourceFailure(sourceId: string, error: string): Promise<void> {
    const record = this.inMemoryHealth.get(sourceId);
    if (record) {
      record.lastFailure = error;
      record.failureCount += 1;
    }

    if (this.db) {
      try {
        await this.db.collection('sourceHealth').doc(sourceId).set(
          {
            lastFailure: error,
            lastFailureTime: firestore.FieldValue.serverTimestamp(),
            failureCount: firestore.FieldValue.increment(1),
            status: 'degraded',
          },
          { merge: true }
        );
      } catch (_) {}
    }

    StructuredLogger.error('source_fetch_failed', `Source ${sourceId} failed: ${error}`, {
      sourceId,
      error,
    });
  }

  /**
   * Returns complete ingestion status across all sources.
   */
  async getAllSourcesStatus(): Promise<SourceHealthRecord[]> {
    if (this.db) {
      try {
        const snap = await this.db.collection('sourceHealth').get();
        for (const doc of snap.docs) {
          const data = doc.data();
          const existing = this.inMemoryHealth.get(doc.id);
          if (existing) {
            if (data.lastSuccessfulFetch) {
              existing.lastSuccessfulFetch = data.lastSuccessfulFetch.toDate?.()?.toISOString() ?? String(data.lastSuccessfulFetch);
            }
            if (data.lastFailure) {
              existing.lastFailure = data.lastFailure;
            }
            if (data.failureCount != null) {
              existing.failureCount = data.failureCount;
            }
            if (data.enabled != null) {
              existing.enabled = data.enabled;
            }
          }
        }
      } catch (_) {}
    }

    return Array.from(this.inMemoryHealth.values());
  }

  /**
   * Enables or disables a source.
   */
  async toggleSource(sourceId: string, enabled: boolean): Promise<boolean> {
    const record = this.inMemoryHealth.get(sourceId);
    if (!record) return false;

    record.enabled = enabled;

    if (this.db) {
      await this.db.collection('sourceHealth').doc(sourceId).set(
        { enabled },
        { merge: true }
      );
    }

    StructuredLogger.info('source_toggled', `Source ${sourceId} enabled set to ${enabled}`, {
      sourceId,
      metadata: { enabled },
    });

    return true;
  }

  /**
   * Manually removes or soft-deletes an invalid article.
   */
  async removeArticle(articleId: string, reason: string): Promise<boolean> {
    if (!this.db) {
      StructuredLogger.warn('article_removal_skipped', 'Database not configured for removal', {
        articleId,
      });
      return false;
    }

    try {
      const docRef = this.db.collection('articles').doc(articleId);
      const doc = await docRef.get();
      if (!doc.exists) return false;

      // Soft delete by updating status to 'removed'
      await docRef.update({
        status: 'removed',
        removedAt: firestore.FieldValue.serverTimestamp(),
        removalReason: reason,
      });

      StructuredLogger.warn('article_removed', `Article ${articleId} removed: ${reason}`, {
        articleId,
        metadata: { reason },
      });

      return true;
    } catch (err: any) {
      StructuredLogger.error('article_removal_failed', `Failed to remove article ${articleId}`, {
        articleId,
        error: err.message,
      });
      return false;
    }
  }

  /**
   * Inspects article processing and AI synthesis status.
   */
  async getArticleProcessingStatus(articleId: string): Promise<any | null> {
    if (!this.db) return null;
    const doc = await this.db.collection('articles').doc(articleId).get();
    if (!doc.exists) return null;
    const data = doc.data();
    return {
      articleId,
      title: data?.title,
      category: data?.category,
      sourceName: data?.sourceName,
      status: data?.status ?? 'published',
      aiProcessed: data?.aiProcessed ?? false,
      aiModel: data?.aiModel,
      aiPromptVersion: data?.aiPromptVersion,
      ingestedAt: data?.ingestedAt,
    };
  }

  /**
   * Why an article doc counts as seeded/demo content (or null if it is a real ingested article):
   * - id starts with "demo-" or the doc has `seeded: true`
   * - it was not written by the ingestion engine (no sourceId / ingestedAt)
   * - its sourceUrl is missing, a publisher homepage, or a section hub instead of a post
   */
  static seedReason(id: string, data: Record<string, any>): string | null {
    if (id.startsWith('demo-')) return 'demo id';
    if (data?.seeded === true) return 'seeded flag';
    if (!data?.sourceId || !data?.ingestedAt) return 'not written by ingestion engine';
    if (UrlNormalizer.isHubUrl(data?.sourceUrl)) return 'sourceUrl is a homepage/hub';
    return null;
  }

  /** Deletes seeded/demo articles (and their private source text). Pass dryRun=true to only count. */
  async purgeSeedArticles(dryRun = false): Promise<PurgeResult> {
    const result: PurgeResult = { scanned: 0, matched: 0, deleted: 0, dryRun, sample: [] };
    if (!this.db) return result;

    const pageSize = 300;
    let last: firestore.QueryDocumentSnapshot | undefined;
    while (true) {
      let q = this.db.collection('articles').orderBy(firestore.FieldPath.documentId()).limit(pageSize);
      if (last) q = q.startAfter(last);
      const snap = await q.get();
      if (snap.empty) break;

      const batch = this.db.batch();
      let ops = 0;
      for (const doc of snap.docs) {
        result.scanned++;
        const reason = AdminService.seedReason(doc.id, doc.data());
        if (!reason) continue;
        result.matched++;
        if (result.sample.length < 25) {
          result.sample.push({ id: doc.id, reason, sourceUrl: doc.data()?.sourceUrl });
        }
        if (!dryRun) {
          batch.delete(doc.ref);
          batch.delete(this.db.collection('articleSources').doc(doc.id));
          ops += 2;
        }
      }
      if (!dryRun && ops > 0) {
        await batch.commit();
        result.deleted += ops / 2;
      }
      last = snap.docs[snap.docs.length - 1];
      if (snap.size < pageSize) break;
    }

    StructuredLogger.warn('seed_articles_purged', `Purge seed articles (dryRun=${dryRun})`, {
      metadata: { scanned: result.scanned, matched: result.matched, deleted: result.deleted },
    });
    return result;
  }
}
