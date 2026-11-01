import { firestore } from 'firebase-admin';
import { StructuredLogger } from '../monitoring/logger';

export interface DailyBriefItemDoc {
  rank: number;
  articleId: string;
  headline: string;
  whyItMatters: string;
  category: string;
  sourceName: string;
  sourceUrl: string;
}

export interface DailyBriefDoc {
  id: string;
  date: firestore.Timestamp;
  title: string;
  subtitle: string;
  items: DailyBriefItemDoc[];
  createdAt: firestore.FieldValue;
}

export class DailyBriefGenerator {
  constructor(private db: firestore.Firestore) {}

  /** Brief ids follow the India calendar day because the brief is published at 06:00 Asia/Kolkata. */
  static generateDateId(date: Date, timeZone = 'Asia/Kolkata'): string {
    const parts = new Intl.DateTimeFormat('en-CA', {
      timeZone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }).formatToParts(date);
    const get = (t: string) => parts.find((p) => p.type === t)?.value ?? '00';
    return `brief-${get('year')}-${get('month')}-${get('day')}`;
  }

  /**
   * Generates a Daily Brief strictly from already ingested, verified articles in Firestore.
   * Zero hallucination: Extra claims or fictitious news are strictly prohibited.
   */
  async generateDailyBrief(targetDate = new Date()): Promise<DailyBriefDoc | null> {
    const dateId = DailyBriefGenerator.generateDateId(targetDate);
    StructuredLogger.info('daily_brief_generation_started', `Generating daily brief for ${dateId}`, {
      metadata: { dateId },
    });

    try {
      // Query recent published articles
      const snap = await this.db
        .collection('articles')
        .where('status', '==', 'published')
        .orderBy('publishedAt', 'desc')
        .limit(40)
        .get();

      if (snap.empty) {
        StructuredLogger.warn('daily_brief_empty', 'No published articles found for brief', {
          metadata: { dateId },
        });
        return null;
      }

      const items: DailyBriefItemDoc[] = [];
      const seenSources = new Map<string, number>();

      for (const doc of snap.docs) {
        if (items.length >= 10) break;
        const data = doc.data();

        // Ensure diversity: avoid more than 2 articles from identical source in the top 10
        const sourceCount = seenSources.get(data.sourceName) ?? 0;
        if (sourceCount >= 2 && snap.docs.length > 10) {
          continue;
        }

        seenSources.set(data.sourceName, sourceCount + 1);

        const whyItMatters =
          (data.whyItMatters && data.whyItMatters.trim().length > 10)
            ? data.whyItMatters.trim()
            : (data.simpleExplanation && data.simpleExplanation.trim().length > 10)
            ? data.simpleExplanation.trim()
            : data.summary;

        items.push({
          rank: items.length + 1,
          articleId: doc.id,
          headline: data.title,
          whyItMatters,
          category: data.category || 'Technology',
          sourceName: data.sourceName,
          sourceUrl: data.sourceUrl,
        });
      }

      const briefDoc: DailyBriefDoc = {
        id: dateId,
        date: firestore.Timestamp.fromDate(targetDate),
        title: 'TODAY IN TECH',
        subtitle: `${items.length} essential technology developments curated from verified primary wires.`,
        items,
        createdAt: firestore.FieldValue.serverTimestamp(),
      };

      // Store in dailyBriefs/{dateId}
      await this.db.collection('dailyBriefs').doc(dateId).set(briefDoc, { merge: true });

      StructuredLogger.info('daily_brief_generated', `Generated daily brief with ${items.length} stories`, {
        metadata: { dateId, itemCount: items.length },
      });

      return briefDoc;
    } catch (err: any) {
      StructuredLogger.error('daily_brief_generation_failed', `Failed to generate brief for ${dateId}`, {
        error: err.message,
        metadata: { dateId },
      });
      throw err;
    }
  }
}
