/**
 * TechDaily backend jobs for running OUTSIDE Cloud Functions (GitHub Actions, a laptop, Cloud Shell).
 * Lets the project stay on the free Spark plan: the Firebase project only hosts the web app,
 * Firestore and FCM; the scheduled work runs here.
 *
 * v2 (stories):
 *   npx tsx src/jobs.ts ingest           [--dry-run] [--source=<id,id>] [--concurrency=N] [--cache=file]
 *                                        [--json-out=file] [--stories-out=file] [--max-age-hours=48]
 *   npx tsx src/jobs.ts render           [--out=../build/web] [--cache=file] [--from-json=file] [--site-url=URL]
 *   npx tsx src/jobs.ts daily-brief      [--no-push] [--cache=file]        (Today in 5 from stories + 06:00 push)
 *   npx tsx src/jobs.ts migrate-articles [--dry-run] [--limit=N] [--cache=file] (articles -> stories, articles untouched)
 * v1 (legacy `articles` collection):
 *   npx tsx src/jobs.ts ingest-articles  [--dry-run] [--source=<id>] [--concurrency=N] [--json-out=file]
 *   npx tsx src/jobs.ts purge-seed       [--dry-run]
 *
 * Auth: Google Application Default Credentials. Works with a service-account key, `gcloud auth
 * application-default login`, and Workload Identity Federation (`external_account`) credential files
 * written by google-github-actions/auth. firebase-admin v12 cannot read `external_account` files
 * itself, so this file builds the Firestore client and the FCM access token from google-auth-library.
 *
 * Env: GEMINI_API_KEY (optional; rule-based summaries without it), FIREBASE_PROJECT_ID (default techdaily-prod),
 * GEMINI_MODEL (optional). ADMIN_SECRET is NOT used.
 *
 * functions/src/index.ts (Cloud Functions) is untouched and still deployable on Blaze.
 */
import * as admin from 'firebase-admin';
import { Firestore } from 'firebase-admin/firestore';
import { GoogleAuth } from 'google-auth-library';
import { IngestionEngine, IngestSummary } from './pipeline/ingestion-engine';
import { DailyBriefGenerator, DailyBriefDoc } from './pipeline/daily-brief-generator';
import { AdminService, PurgeResult } from './admin/admin-service';
import { ServerAiSummarizer } from './ai';
import { PushService, DAILY_BRIEF_TOPIC } from './notifications/push-service';
import { getSourceById } from './config/sources';
import { StoryCache, syncCache, loadStoriesJson, writeTodayInFive, docToStory, STORIES } from './stories/story-store';
import { runStoryPipeline, StoryIngestResult } from './stories/story-pipeline';
import { renderSite, RenderResult } from './stories/render/render';
import { migrateArticles, MigrateResult } from './stories/migrate';
import { pickTodayInFive, TodayInFive } from './stories/ranking';
import { StoryWriter } from './stories/story-writer';
import { Timestamp } from 'firebase-admin/firestore';
import { Story } from './stories/types';

export const DEFAULT_PROJECT_ID = 'techdaily-prod';
export const COMMANDS = ['ingest', 'render', 'daily-brief', 'migrate-articles', 'ingest-articles', 'purge-seed'] as const;
export type JobCommand = (typeof COMMANDS)[number];

export interface JobArgs {
  command: JobCommand;
  dryRun: boolean;
  push: boolean;
  source?: string;
  concurrency: number;
  jsonOut?: string;
  /** Story cache JSON (kept between runs with actions/cache to save Firestore reads). */
  cache?: string;
  /** render: output directory (the Flutter web build). */
  out: string;
  /** render: read stories from this JSON file instead of Firestore. */
  fromJson?: string;
  /** ingest: write every known story (cache + new) to this JSON file. */
  storiesOut?: string;
  limit?: number;
  maxAgeHours?: number;
  siteUrl?: string;
}

export function parseArgs(argv: string[]): JobArgs {
  const command = argv.find((a) => !a.startsWith('--')) as JobCommand | undefined;
  if (!command || !COMMANDS.includes(command)) {
    throw new Error(`Unknown or missing command "${command ?? ''}". Use one of: ${COMMANDS.join(', ')}`);
  }
  const val = (name: string) => {
    const hit = argv.find((a) => a.startsWith(`--${name}=`));
    return hit ? hit.slice(name.length + 3) : undefined;
  };
  const int = (name: string) => {
    const n = parseInt(val(name) ?? '', 10);
    return Number.isFinite(n) && n > 0 ? n : undefined;
  };
  return {
    command,
    dryRun: argv.includes('--dry-run'),
    push: !argv.includes('--no-push'),
    source: val('source'),
    concurrency: int('concurrency') ?? (command === 'ingest' ? 6 : 3),
    jsonOut: val('json-out'),
    cache: val('cache'),
    out: val('out') ?? '../build/web',
    fromJson: val('from-json'),
    storiesOut: val('stories-out'),
    limit: int('limit'),
    maxAgeHours: int('max-age-hours'),
    siteUrl: val('site-url'),
  };
}

/** Everything a job touches, injectable for tests. */
export interface JobDeps {
  db?: FirebaseFirestore.Firestore;
  push: Pick<PushService, 'sendToTopic'>;
  engine?: Pick<IngestionEngine, 'runAll' | 'processSource'>;
  briefGenerator?: Pick<DailyBriefGenerator, 'generateDailyBrief'>;
  adminService?: Pick<AdminService, 'purgeSeedArticles'>;
}

export async function sendBriefPush(push: JobDeps['push'], brief: DailyBriefDoc | null): Promise<string | null> {
  if (!brief || brief.items.length === 0) return null;
  const top = brief.items[0];
  return push.sendToTopic(DAILY_BRIEF_TOPIC, {
    title: 'Today in Tech',
    body: top.headline,
    data: { type: 'daily-brief', briefId: brief.id, articleId: top.articleId },
  });
}

export async function runIngest(args: JobArgs, deps: JobDeps): Promise<{ summary: IngestSummary; ok: boolean }> {
  const engine =
    deps.engine ??
    new IngestionEngine(args.dryRun ? undefined : deps.db, undefined, undefined, new ServerAiSummarizer(), undefined, {
      sourceConcurrency: args.concurrency,
      pushService: deps.push as PushService,
    });
  const dry = args.dryRun || !deps.db;
  let summary: IngestSummary;
  if (args.source) {
    const source = getSourceById(args.source);
    if (!source) throw new Error(`Source "${args.source}" not found in trusted registry.`);
    const s = await engine.processSource(source, dry);
    const now = new Date().toISOString();
    summary = {
      startedAt: now,
      completedAt: now,
      sourcesProcessed: 1,
      totalArticlesFound: s.totalFound,
      totalAccepted: s.accepted,
      totalDuplicates: s.duplicates,
      totalRejected: s.rejected,
      totalWithImage: s.withImage,
      sourcesStats: [s],
    };
  } else {
    summary = await engine.runAll(dry);
  }
  // Fail the job only when every source failed (feeds failing individually is normal).
  const ok = summary.sourcesStats.length === 0 || summary.sourcesStats.some((s) => s.status === 'success');
  return { summary, ok };
}

export async function runDailyBrief(
  args: JobArgs,
  deps: JobDeps
): Promise<{ brief: DailyBriefDoc | null; pushId: string | null }> {
  if (!deps.briefGenerator && !deps.db) throw new Error('daily-brief needs Firestore');
  const generator = deps.briefGenerator ?? new DailyBriefGenerator(deps.db as any);
  const brief = await generator.generateDailyBrief();
  const pushId = args.push ? await sendBriefPush(deps.push, brief) : null;
  return { brief, pushId };
}

export async function runPurgeSeed(
  args: JobArgs,
  deps: JobDeps
): Promise<{ result: PurgeResult; briefRegenerated: boolean }> {
  if (!deps.adminService && !deps.db) throw new Error('purge-seed needs Firestore');
  const svc = deps.adminService ?? new AdminService(deps.db as any);
  const result = await svc.purgeSeedArticles(args.dryRun);
  let briefRegenerated = false;
  if (!args.dryRun && result.deleted > 0) {
    try {
      const generator = deps.briefGenerator ?? new DailyBriefGenerator(deps.db as any);
      await generator.generateDailyBrief();
      briefRegenerated = true;
    } catch (e: any) {
      console.warn('[purge-seed] Brief regeneration skipped:', e?.message || e);
    }
  }
  return { result, briefRegenerated };
}

// ---------------------------------------------------------------------------------------------
// v2 stories jobs
// ---------------------------------------------------------------------------------------------

export async function runStoriesIngest(
  args: JobArgs,
  deps: Pick<JobDeps, 'db' | 'push'> & { writer?: StoryWriter; fetchText?: (url: string) => Promise<string> }
): Promise<{ result: StoryIngestResult; ok: boolean; reads: number; cache: StoryCache }> {
  const cache = StoryCache.load(args.cache);
  let reads = 0;
  if (deps.db) reads = await syncCache(deps.db, cache);
  const result = await runStoryPipeline(
    {
      dryRun: args.dryRun,
      concurrency: args.concurrency,
      sourceIds: args.source ? args.source.split(',').map((x) => x.trim()).filter(Boolean) : undefined,
      maxAgeHours: args.maxAgeHours,
      fetchText: deps.fetchText,
      push: deps.push,
    },
    { db: args.dryRun ? undefined : deps.db, writer: deps.writer, cache }
  );
  if (!args.dryRun) cache.save(args.cache);
  const ok = result.feeds.length === 0 || result.feeds.some((f) => f.status === 'ok');
  return { result, ok, reads, cache };
}

export async function runRender(args: JobArgs, deps: Pick<JobDeps, 'db'>): Promise<{ result: RenderResult; reads: number }> {
  let stories: Story[];
  let reads = 0;
  if (args.fromJson) {
    stories = loadStoriesJson(args.fromJson);
  } else {
    if (!deps.db) throw new Error('render needs Firestore or --from-json=<file>');
    const cache = StoryCache.load(args.cache);
    reads = await syncCache(deps.db, cache);
    cache.save(args.cache);
    stories = cache.all();
  }
  const result = renderSite({ outDir: args.out, stories, siteUrl: args.siteUrl });
  return { result, reads };
}

/** 06:00 IST: refresh "Today in 5" from stories and push its lead story. */
export async function runTodayBrief(args: JobArgs, deps: Pick<JobDeps, 'db' | 'push'>): Promise<{ today: TodayInFive; pushId: string | null }> {
  if (!deps.db) throw new Error('daily-brief needs Firestore');
  let stories: Story[];
  if (args.cache) {
    const cache = StoryCache.load(args.cache);
    await syncCache(deps.db, cache);
    cache.save(args.cache);
    stories = cache.all();
  } else {
    const since = Timestamp.fromDate(new Date(Date.now() - 48 * 3600 * 1000));
    const snap = await deps.db.collection(STORIES).where('publishedAt', '>=', since).get();
    stories = snap.docs.map((d) => docToStory(d.data(), d.id));
  }
  const today = pickTodayInFive(stories);
  await writeTodayInFive(deps.db, today);
  let pushId: string | null = null;
  if (args.push && today.items[0]) {
    pushId = await deps.push.sendToTopic(DAILY_BRIEF_TOPIC, {
      title: 'Today in 5',
      body: today.items[0].headline,
      data: { type: 'today-in-5', briefId: today.id, slug: today.items[0].slug, storyId: today.items[0].storyId },
    });
  }
  return { today, pushId };
}

export async function runMigrate(args: JobArgs, deps: Pick<JobDeps, 'db'>): Promise<MigrateResult> {
  if (!deps.db) throw new Error('migrate-articles needs Firestore');
  const cache = StoryCache.load(args.cache);
  await syncCache(deps.db, cache);
  const result = await migrateArticles(deps.db, cache, { dryRun: args.dryRun, limit: args.limit });
  if (!args.dryRun) cache.save(args.cache);
  return result;
}

/** Initializes firebase-admin + Firestore from Application Default Credentials (incl. WIF). */
export function initFirebase(projectId: string): FirebaseFirestore.Firestore {
  const auth = new GoogleAuth({
    projectId,
    scopes: [
      'https://www.googleapis.com/auth/cloud-platform',
      'https://www.googleapis.com/auth/firebase.messaging',
    ],
  });
  const credential: admin.credential.Credential = {
    async getAccessToken() {
      const client = await auth.getClient();
      const res = await client.getAccessToken();
      if (!res.token) throw new Error('ADC returned no access token');
      const expiry = (client as any).credentials?.expiry_date as number | undefined;
      const expires_in = expiry ? Math.max(60, Math.floor((expiry - Date.now()) / 1000)) : 3000;
      return { access_token: res.token, expires_in };
    },
  };
  if (!admin.apps.length) admin.initializeApp({ projectId, credential });
  // @google-cloud/firestore resolves ADC itself via google-auth-library (supports external_account).
  return new Firestore({ projectId, preferRest: true });
}

function writeStepSummary(markdown: string) {
  const file = process.env.GITHUB_STEP_SUMMARY;
  if (!file) return;
  try {
    require('fs').appendFileSync(file, markdown + '\n');
  } catch {
    /* ignore */
  }
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const projectId = process.env.FIREBASE_PROJECT_ID || process.env.GCLOUD_PROJECT || DEFAULT_PROJECT_ID;
  const offline =
    ((args.command === 'ingest' || args.command === 'ingest-articles') && args.dryRun) || (args.command === 'render' && Boolean(args.fromJson));
  const db = offline ? undefined : initFirebase(projectId);
  const push = new PushService();
  const deps: JobDeps = { db, push };
  const fs = require('fs');

  console.log(`[jobs] ${args.command} project=${projectId} dryRun=${args.dryRun} gemini=${Boolean(process.env.GEMINI_API_KEY)}`);

  if (args.command === 'ingest') {
    const { result, ok, reads, cache } = await runStoriesIngest(args, deps);
    console.table(result.feeds.map((f) => ({ feed: f.sourceId, status: f.status, parsed: f.parsed, kept: f.kept, error: f.error ?? '' })));
    const w = result.writer;
    const line =
      `items=${result.itemsFetched} new=${result.itemsNew} clusters=${result.clusters} (multi-source ${result.multiSourceClusters}) ` +
      `created=${result.storiesCreated} updated=${result.storiesUpdated} enriched=${result.storiesEnriched} ` +
      `ai=${w.aiOk}/${w.aiCalls} invalid=${w.aiInvalid} errors=${w.aiErrors} fallback=${w.fallbacks} rateLimited=${w.rateLimited} ` +
      `model=${w.model} reads=${reads} writes=${result.firestoreWrites}`;
    console.log(`Totals: ${line}`);
    console.log('Today in 5:', result.today.items.map((i) => `[${i.category}] ${i.headline}`));
    writeStepSummary(
      `### Ingest stories ${args.dryRun ? '(dry run)' : ''}\n\n${line}\n\nFailed feeds: ${result.feeds.filter((f) => f.status === 'failed').map((f) => f.sourceId).join(', ') || 'none'}\n\n**Today in 5**\n${result.today.items.map((i, n) => `${n + 1}. ${i.headline}`).join('\n')}`
    );
    if (args.jsonOut) fs.writeFileSync(args.jsonOut, JSON.stringify({ ...result, changed: result.changed.length }, null, 2));
    if (args.storiesOut) fs.writeFileSync(args.storiesOut, JSON.stringify({ stories: cache.all() }));
    if (!ok) {
      console.error('[jobs] Every feed failed.');
      process.exitCode = 1;
    }
  } else if (args.command === 'render') {
    const { result, reads } = await runRender(args, deps);
    const line = `storyPages=${result.storyPages} categoryPages=${result.categoryPages} feedStories=${result.feedStories} indexInjected=${result.indexInjected} bytes=${result.bytes} reads=${reads}`;
    console.log(`[jobs] render ${line}`);
    writeStepSummary(`### Render\n\n${line}`);
  } else if (args.command === 'daily-brief') {
    const { today, pushId } = await runTodayBrief(args, deps);
    const line = `Today in 5 ${today.id}: ${today.items.length} stories, push=${pushId ?? 'none'}`;
    console.log(`[jobs] ${line}`);
    writeStepSummary(`### Today in 5\n\n${line}\n\n${today.items.map((i, n) => `${n + 1}. ${i.headline}`).join('\n')}`);
  } else if (args.command === 'migrate-articles') {
    const r = await runMigrate(args, deps);
    const line = `articlesRead=${r.articlesRead} usable=${r.articlesUsable} alreadyInStories=${r.skippedKnown} created=${r.storiesCreated} updated=${r.storiesUpdated} writes=${r.firestoreWrites}`;
    console.log(`[jobs] migrate ${args.dryRun ? '(dry run) ' : ''}${line}`);
    writeStepSummary(`### Migrate articles -> stories ${args.dryRun ? '(dry run)' : ''}\n\n${line}`);
    if (args.jsonOut) fs.writeFileSync(args.jsonOut, JSON.stringify({ ...r, changed: r.changed }, null, 2));
  } else if (args.command === 'ingest-articles') {
    const { summary, ok } = await runIngest(args, deps);
    console.table(
      summary.sourcesStats.map((s) => ({
        source: s.sourceId,
        status: s.status,
        found: s.totalFound,
        accepted: s.accepted,
        dup: s.duplicates,
        rejected: s.rejected,
        pushes: s.breakingPushes,
        error: s.error ?? '',
      }))
    );
    const line = `found=${summary.totalArticlesFound} accepted=${summary.totalAccepted} duplicates=${summary.totalDuplicates} rejected=${summary.totalRejected} withImage=${summary.totalWithImage}`;
    console.log(`Totals: ${line}`);
    writeStepSummary(`### Ingest articles (v1) ${args.dryRun ? '(dry run)' : ''}\n\n${line}`);
    if (args.jsonOut) fs.writeFileSync(args.jsonOut, JSON.stringify(summary, null, 2));
    if (!ok) process.exitCode = 1;
  } else {
    const { result, briefRegenerated } = await runPurgeSeed(args, deps);
    console.log(JSON.stringify(result, null, 2));
    writeStepSummary(
      `### Purge seed ${args.dryRun ? '(dry run)' : ''}\n\nscanned=${result.scanned} matched=${result.matched} deleted=${result.deleted} briefRegenerated=${briefRegenerated}`
    );
  }
}

if (require.main === module) {
  main()
    .then(async () => {
      await Promise.all(admin.apps.map((a) => a?.delete()));
      // Firestore gRPC/REST handles can keep the loop alive; jobs are one-shot.
      process.exit(process.exitCode ?? 0);
    })
    .catch((err) => {
      console.error('[jobs] Fatal:', err?.stack || err);
      process.exit(1);
    });
}
