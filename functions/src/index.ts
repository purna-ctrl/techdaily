import { onSchedule } from 'firebase-functions/v2/scheduler';
import { onRequest } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';
import * as admin from 'firebase-admin';
import { IngestionEngine } from './pipeline/ingestion-engine';
import { AdminService } from './admin/admin-service';
import { DailyBriefGenerator } from './pipeline/daily-brief-generator';
import { ServerAiSummarizer } from './ai';
import { verifyAdmin } from './admin/verify-admin';
import { PushService, DAILY_BRIEF_TOPIC } from './notifications/push-service';
import {
  ASK_ALLOWED_ORIGINS,
  ArticleQaService,
  FirestoreRateLimiter,
  createAskArticleHandler,
} from './ask/ask-article';

if (!admin.apps.length) {
  admin.initializeApp();
}

/** Secrets (Cloud Secret Manager). Set with `firebase functions:secrets:set <NAME>`. */
const GEMINI_API_KEY = defineSecret('GEMINI_API_KEY');
const ADMIN_SECRET = defineSecret('ADMIN_SECRET');

const REGION = 'us-central1';

let askRateLimiter: FirestoreRateLimiter | undefined;

/** Reads a secret at runtime, falling back to process.env (tests / emulator / CLI). */
function readSecret(secret: { value(): string }, envName: string): string | undefined {
  try {
    const v = secret.value();
    if (v) return v;
  } catch {
    /* not bound in this context */
  }
  return process.env[envName] || undefined;
}

function geminiKey(): string | undefined {
  return readSecret(GEMINI_API_KEY, 'GEMINI_API_KEY');
}

function adminSecret(): string | undefined {
  return readSecret(ADMIN_SECRET, 'ADMIN_SECRET');
}

function buildEngine(): IngestionEngine {
  const db = admin.firestore();
  return new IngestionEngine(db, undefined, undefined, new ServerAiSummarizer({ apiKey: geminiKey() }));
}

/**
 * Scheduled ingestion of all trusted feeds (default every 60 minutes).
 */
export const collectTechNews = onSchedule(
  {
    schedule: process.env.INGESTION_SCHEDULE || 'every 60 minutes',
    timeZone: 'Asia/Kolkata',
    timeoutSeconds: 540,
    memory: '1GiB',
    region: REGION,
    secrets: [GEMINI_API_KEY],
  },
  async () => {
    await buildEngine().runAll(false);
  }
);

/**
 * Morning "Today in Tech" brief at 06:00 India time, plus an FCM push to topic `daily-brief`.
 */
export const scheduleDailyBrief = onSchedule(
  {
    schedule: '0 6 * * *',
    timeZone: 'Asia/Kolkata',
    timeoutSeconds: 120,
    memory: '512MiB',
    region: REGION,
  },
  async () => {
    const generator = new DailyBriefGenerator(admin.firestore());
    const brief = await generator.generateDailyBrief();
    if (brief && brief.items.length > 0) {
      const top = brief.items[0];
      await new PushService().sendToTopic(DAILY_BRIEF_TOPIC, {
        title: 'Today in Tech',
        body: top.headline,
        data: { type: 'daily-brief', briefId: brief.id, articleId: top.articleId },
      });
    }
  }
);

/**
 * Manual ingestion trigger (admin). POST, `Authorization: Bearer <ADMIN_SECRET>`, `?dryRun=true` optional.
 */
export const triggerIngestion = onRequest(
  {
    cors: false,
    timeoutSeconds: 540,
    memory: '1GiB',
    region: REGION,
    secrets: [GEMINI_API_KEY, ADMIN_SECRET],
  },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Method Not Allowed. Use POST.' });
      return;
    }
    if (!verifyAdmin(req, res, adminSecret())) return;

    try {
      const dryRun = req.query.dryRun === 'true';
      const summary = await buildEngine().runAll(dryRun);
      res.status(200).json(summary);
    } catch (err: any) {
      console.error('[triggerIngestion] Error:', err);
      res.status(500).json({ error: err.message || 'Internal Server Error' });
    }
  }
);

/** Admin: ingestion and source status. */
export const getIngestionStatus = onRequest(
  { cors: false, timeoutSeconds: 60, memory: '256MiB', region: REGION, secrets: [ADMIN_SECRET] },
  async (req, res) => {
    if (!verifyAdmin(req, res, adminSecret())) return;
    try {
      const status = await new AdminService(admin.firestore()).getAllSourcesStatus();
      res.status(200).json({ sources: status, count: status.length });
    } catch (err: any) {
      res.status(500).json({ error: err.message || 'Internal Server Error' });
    }
  }
);

/** Admin: enable or disable a source. */
export const manageSource = onRequest(
  { cors: false, timeoutSeconds: 60, memory: '256MiB', region: REGION, secrets: [ADMIN_SECRET] },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Method Not Allowed. Use POST.' });
      return;
    }
    if (!verifyAdmin(req, res, adminSecret())) return;
    try {
      const { sourceId, enabled } = req.body || {};
      if (!sourceId || typeof enabled !== 'boolean') {
        res.status(400).json({ error: 'Missing sourceId or enabled boolean' });
        return;
      }
      const updated = await new AdminService(admin.firestore()).toggleSource(sourceId, enabled);
      res.status(200).json({ success: updated, sourceId, enabled });
    } catch (err: any) {
      res.status(500).json({ error: err.message || 'Internal Server Error' });
    }
  }
);

/** Admin: generate the daily brief on demand (`?push=true` also sends the daily-brief push). */
export const triggerDailyBrief = onRequest(
  { cors: false, timeoutSeconds: 120, memory: '512MiB', region: REGION, secrets: [ADMIN_SECRET] },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Method Not Allowed. Use POST.' });
      return;
    }
    if (!verifyAdmin(req, res, adminSecret())) return;
    try {
      const brief = await new DailyBriefGenerator(admin.firestore()).generateDailyBrief();
      let pushId: string | null = null;
      if (req.query.push === 'true' && brief && brief.items.length > 0) {
        pushId = await new PushService().sendToTopic(DAILY_BRIEF_TOPIC, {
          title: 'Today in Tech',
          body: brief.items[0].headline,
          data: { type: 'daily-brief', briefId: brief.id, articleId: brief.items[0].articleId },
        });
      }
      res.status(200).json({ success: true, brief, pushId });
    } catch (err: any) {
      res.status(500).json({ error: err.message || 'Internal Server Error' });
    }
  }
);

/**
 * Admin: delete seeded/demo articles (demo-* ids, docs not written by ingestion, or whose sourceUrl
 * is a homepage/section hub). POST; `?dryRun=true` only counts. Regenerates today's brief afterwards.
 */
export const purgeSeedArticles = onRequest(
  { cors: false, timeoutSeconds: 300, memory: '512MiB', region: REGION, secrets: [ADMIN_SECRET] },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Method Not Allowed. Use POST.' });
      return;
    }
    if (!verifyAdmin(req, res, adminSecret())) return;
    try {
      const dryRun = req.query.dryRun === 'true';
      const result = await new AdminService(admin.firestore()).purgeSeedArticles(dryRun);
      if (!dryRun && result.deleted > 0) {
        try {
          await new DailyBriefGenerator(admin.firestore()).generateDailyBrief();
        } catch (e: any) {
          console.warn('[purgeSeedArticles] Brief regeneration skipped:', e.message);
        }
      }
      res.status(200).json(result);
    } catch (err: any) {
      res.status(500).json({ error: err.message || 'Internal Server Error' });
    }
  }
);

/**
 * Public: ask a question about one article. Answers ONLY from the article.
 * POST JSON {articleId, question} -> 200 {answer, grounded: 'gemini'|'fallback', articleId}
 */
export const askArticle = onRequest(
  {
    cors: ASK_ALLOWED_ORIGINS,
    timeoutSeconds: 60,
    memory: '256MiB',
    region: REGION,
    secrets: [GEMINI_API_KEY],
    maxInstances: 10,
  },
  async (req, res) => {
    const db = admin.firestore();
    const handler = createAskArticleHandler({
      loadArticle: async (id) => {
        const doc = await db.collection('articles').doc(id).get();
        if (!doc.exists) return null;
        const data = doc.data() || {};
        if (data.status === 'removed') return null;
        return { id: doc.id, ...(data as any) };
      },
      loadSourceText: async (id) => {
        const doc = await db.collection('articleSources').doc(id).get();
        const text = doc.exists ? doc.data()?.text : undefined;
        return typeof text === 'string' ? text : undefined;
      },
      rateLimiter: (askRateLimiter ??= new FirestoreRateLimiter(db)),
      qa: new ArticleQaService(geminiKey()),
    });
    await handler(req, res);
  }
);
