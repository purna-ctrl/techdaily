/**
 * Firestore persistence for stories + a local JSON cache.
 *
 * Spark quota: 50k reads/day. Ingest and render run hourly, so instead of re-reading every story each
 * run they keep a JSON snapshot (persisted between GitHub Actions runs with actions/cache) and only
 * read stories whose `updatedAt` is newer than the snapshot. A cold start reads at most `maxStories`.
 */
import * as fs from 'fs';
import * as path from 'path';
import { Timestamp } from 'firebase-admin/firestore';
import { toCategoryId } from './categories';
import { Confidence, Story, StorySource, STORY_PROMPT_VERSION } from './types';
import { TodayInFive } from './ranking';
import { parseStoryImage } from './images';

export const STORIES = 'stories';
export const STORY_BRIEFS = 'storyBriefs';

type Db = FirebaseFirestore.Firestore;

function toIso(v: any, fallback = new Date(0).toISOString()): string {
  if (!v) return fallback;
  if (typeof v === 'string') {
    const d = new Date(v);
    return isNaN(d.getTime()) ? fallback : d.toISOString();
  }
  if (typeof v.toDate === 'function') return v.toDate().toISOString();
  if (v instanceof Date) return v.toISOString();
  if (typeof v._seconds === 'number') return new Date(v._seconds * 1000).toISOString();
  if (typeof v.seconds === 'number') return new Date(v.seconds * 1000).toISOString();
  return fallback;
}

const ts = (iso: string) => Timestamp.fromDate(new Date(iso));

export function storyToDoc(s: Story): Record<string, unknown> {
  return {
    ...s,
    publishedAt: ts(s.publishedAt),
    updatedAt: ts(s.updatedAt),
    sources: s.sources.map((x) => ({ ...x, publishedAt: ts(x.publishedAt) })),
    sourceCount: s.sources.length,
    // Firestore rejects `undefined`; the image object never carries undefined keys (see images.ts).
    image: s.image ?? null,
    imageTries: s.imageTries ?? 0,
  };
}

export function docToStory(d: Record<string, any>, id?: string): Story {
  const sources: StorySource[] = Array.isArray(d.sources)
    ? d.sources
        .filter((x: any) => x && typeof x.url === 'string')
        .map((x: any) => ({
          sourceId: String(x.sourceId ?? ''),
          name: String(x.name ?? ''),
          url: String(x.url),
          title: String(x.title ?? ''),
          publishedAt: toIso(x.publishedAt),
        }))
    : [];
  const conf: Confidence = d.confidence === 'high' || d.confidence === 'low' ? d.confidence : 'medium';
  return {
    id: String(d.id ?? id ?? ''),
    slug: String(d.slug ?? ''),
    headline: String(d.headline ?? ''),
    category: toCategoryId(d.category),
    publishedAt: toIso(d.publishedAt),
    updatedAt: toIso(d.updatedAt),
    sources,
    whatHappened: String(d.whatHappened ?? ''),
    affectsWho: String(d.affectsWho ?? ''),
    whatToDo: Array.isArray(d.whatToDo) ? d.whatToDo.map(String) : [],
    whatItMeans: String(d.whatItMeans ?? ''),
    scam:
      d.scam && typeof d.scam === 'object'
        ? {
            howItWorks: String(d.scam.howItWorks ?? ''),
            warningSigns: Array.isArray(d.scam.warningSigns) ? d.scam.warningSigns.map(String) : [],
            ifTargeted: Array.isArray(d.scam.ifTargeted) ? d.scam.ifTargeted.map(String) : [],
            advisoryUrl: typeof d.scam.advisoryUrl === 'string' && d.scam.advisoryUrl ? d.scam.advisoryUrl : null,
          }
        : null,
    confidence: conf,
    developing: d.developing === true,
    aiModel: String(d.aiModel ?? ''),
    needsEnrichment: d.needsEnrichment === true,
    enrichAttempts: Number.isFinite(d.enrichAttempts) ? Number(d.enrichAttempts) : 0,
    region: d.region === 'IN' ? 'IN' : 'GLOBAL',
    unconfirmed: d.unconfirmed === true,
    promptVersion: String(d.promptVersion ?? STORY_PROMPT_VERSION),
    image: parseStoryImage(d.image),
    imageTries: Number.isFinite(d.imageTries) ? Number(d.imageTries) : 0,
  };
}

export class StoryCache {
  stories = new Map<string, Story>();
  maxUpdatedAt = '';
  syncedAt = '';

  static load(file?: string): StoryCache {
    const c = new StoryCache();
    if (!file || !fs.existsSync(file)) return c;
    try {
      const raw = JSON.parse(fs.readFileSync(file, 'utf8'));
      const list: any[] = Array.isArray(raw) ? raw : Array.isArray(raw?.stories) ? raw.stories : [];
      for (const s of list) c.upsert(docToStory(s));
      if (typeof raw?.maxUpdatedAt === 'string') c.maxUpdatedAt = raw.maxUpdatedAt;
      if (typeof raw?.syncedAt === 'string') c.syncedAt = raw.syncedAt;
    } catch (e: any) {
      console.warn(`[StoryCache] ignoring unreadable cache ${file}: ${e?.message}`);
    }
    return c;
  }

  save(file?: string): void {
    if (!file) return;
    fs.mkdirSync(path.dirname(path.resolve(file)), { recursive: true });
    fs.writeFileSync(
      file,
      JSON.stringify({ version: 1, syncedAt: this.syncedAt, maxUpdatedAt: this.maxUpdatedAt, stories: this.all() })
    );
  }

  upsert(s: Story): void {
    if (!s.id) return;
    this.stories.set(s.id, s);
    if (s.updatedAt > this.maxUpdatedAt) this.maxUpdatedAt = s.updatedAt;
  }

  all(): Story[] {
    return [...this.stories.values()].sort((a, b) => b.publishedAt.localeCompare(a.publishedAt));
  }

  /** canonical/original URL -> story id, for skipping reports that are already in a story. */
  urlIndex(): Map<string, string> {
    const m = new Map<string, string>();
    for (const s of this.stories.values()) for (const x of s.sources) m.set(x.url, s.id);
    return m;
  }

  slugIndex(): Set<string> {
    return new Set([...this.stories.values()].map((s) => s.slug));
  }

  /** Keeps the newest `max` stories. */
  prune(max: number): void {
    const keep = this.all().slice(0, max);
    this.stories = new Map(keep.map((s) => [s.id, s]));
  }
}

/** Brings the cache up to date with Firestore. Returns the number of documents read. */
export async function syncCache(db: Db, cache: StoryCache, maxStories = 3000): Promise<number> {
  let reads = 0;
  if (cache.stories.size === 0 || !cache.maxUpdatedAt) {
    const snap = await db.collection(STORIES).orderBy('publishedAt', 'desc').limit(maxStories).get();
    for (const d of snap.docs) cache.upsert(docToStory(d.data(), d.id));
    reads = snap.size;
  } else {
    // Runs never overlap (workflow concurrency group), and every write sets updatedAt explicitly,
    // so "newer than the newest story in the cache" is exact.
    const since = new Date(cache.maxUpdatedAt);
    const snap = await db.collection(STORIES).where('updatedAt', '>', Timestamp.fromDate(since)).orderBy('updatedAt', 'asc').get();
    for (const d of snap.docs) cache.upsert(docToStory(d.data(), d.id));
    reads = snap.size;
  }
  cache.syncedAt = new Date().toISOString();
  cache.prune(maxStories);
  return reads;
}

export async function writeStories(db: Db, stories: Story[]): Promise<number> {
  let written = 0;
  for (let i = 0; i < stories.length; i += 400) {
    const batch = db.batch();
    for (const s of stories.slice(i, i + 400)) batch.set(db.collection(STORIES).doc(s.id), storyToDoc(s), { merge: true });
    await batch.commit();
    written += Math.min(400, stories.length - i);
  }
  return written;
}

export async function writeTodayInFive(db: Db, brief: TodayInFive): Promise<void> {
  const doc = { ...brief, generatedAt: Timestamp.fromDate(new Date(brief.generatedAt)) };
  const batch = db.batch();
  batch.set(db.collection(STORY_BRIEFS).doc('latest'), doc);
  batch.set(db.collection(STORY_BRIEFS).doc(brief.date), doc);
  await batch.commit();
}

/** Reads stories from a JSON file: an array, `{stories: [...]}` (cache / ingest output). */
export function loadStoriesJson(file: string): Story[] {
  const raw = JSON.parse(fs.readFileSync(file, 'utf8'));
  const list: any[] = Array.isArray(raw) ? raw : Array.isArray(raw?.stories) ? raw.stories : [];
  return list.map((s) => docToStory(s));
}
