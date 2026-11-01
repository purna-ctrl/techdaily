/**
 * TechDaily backend jobs for running OUTSIDE Cloud Functions (GitHub Actions, a laptop, Cloud Shell).
 * Lets the project stay on the free Spark plan: the Firebase project only hosts the web app,
 * Firestore and FCM; the scheduled work runs here.
 *
 *   npx tsx src/jobs.ts ingest      [--dry-run] [--source=<id>] [--concurrency=N] [--json-out=file]
 *   npx tsx src/jobs.ts daily-brief [--no-push]
 *   npx tsx src/jobs.ts purge-seed  [--dry-run]
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

export const DEFAULT_PROJECT_ID = 'techdaily-prod';
export const COMMANDS = ['ingest', 'daily-brief', 'purge-seed'] as const;
export type JobCommand = (typeof COMMANDS)[number];

export interface JobArgs {
  command: JobCommand;
  dryRun: boolean;
  push: boolean;
  source?: string;
  concurrency: number;
  jsonOut?: string;
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
  const conc = parseInt(val('concurrency') ?? '', 10);
  return {
    command,
    dryRun: argv.includes('--dry-run'),
    push: !argv.includes('--no-push'),
    source: val('source'),
    concurrency: Number.isFinite(conc) && conc > 0 ? conc : 3,
    jsonOut: val('json-out'),
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
  const needsDb = !(args.command === 'ingest' && args.dryRun);
  const db = needsDb ? initFirebase(projectId) : undefined;
  const push = new PushService();
  const deps: JobDeps = { db, push };

  console.log(`[jobs] ${args.command} project=${projectId} dryRun=${args.dryRun} gemini=${Boolean(process.env.GEMINI_API_KEY)}`);

  if (args.command === 'ingest') {
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
    writeStepSummary(`### Ingest ${args.dryRun ? '(dry run)' : ''}\n\n${line}\n\nFailed sources: ${summary.sourcesStats.filter((s) => s.status === 'failed').map((s) => s.sourceId).join(', ') || 'none'}`);
    if (args.jsonOut) require('fs').writeFileSync(args.jsonOut, JSON.stringify(summary, null, 2));
    if (!ok) {
      console.error('[jobs] Every source failed.');
      process.exitCode = 1;
    }
  } else if (args.command === 'daily-brief') {
    const { brief, pushId } = await runDailyBrief(args, deps);
    const line = brief ? `brief ${brief.id}: ${brief.items.length} items, push=${pushId ?? 'none'}` : 'no brief (no published articles)';
    console.log(`[jobs] ${line}`);
    writeStepSummary(`### Daily brief\n\n${line}`);
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
