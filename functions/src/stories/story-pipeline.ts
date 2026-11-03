/**
 * v2 hourly pipeline: fetch feeds -> normalise -> cluster into stories -> write cards (one AI call
 * per story, fallback otherwise) -> re-enrich fallback stories -> save -> "Today in 5".
 */
import { Timestamp } from 'firebase-admin/firestore';
import { FeedParser } from '../pipeline/feed-parser';
import { ContentNormalizer } from '../pipeline/content-normalizer';
import { DomainValidator } from '../pipeline/domain-validator';
import { UrlNormalizer } from '../pipeline/url-normalizer';
import { PushService, BREAKING_TOPIC } from '../notifications/push-service';
import { classify, CategoryId } from './categories';
import { clusterItems, Cluster, ClusterSeed } from './clusterer';
import { isLowValueTitle, STORY_FEEDS, StoryFeed } from './feeds';
import { pickTodayInFive, TodayInFive } from './ranking';
import { StoryCache, writeStories, writeTodayInFive } from './story-store';
import { fallbackStory, StoryWriter, WriterInput, WriterSource, WrittenStory, WriterStats } from './story-writer';
import { sha, storyIdFor, storySlug } from './text';
import { NewsItem, Story, StorySource } from './types';
import { ImageCandidate, ImageResolveStats, pickBestImage, resolveMissingImages, storedImageScore, imageScore, SourcedCandidate } from './images';

type Db = FirebaseFirestore.Firestore;
const HOUR = 3600 * 1000;
export const STORY_SOURCES_PRIVATE = 'storySources';

export interface FeedStat {
  sourceId: string;
  status: 'ok' | 'failed';
  parsed: number;
  kept: number;
  error?: string;
}

export interface StoryIngestOptions {
  dryRun?: boolean;
  /** Ignore feed items older than this. */
  maxAgeHours?: number;
  /** Feeds fetched in parallel. */
  concurrency?: number;
  /** Restrict to these feed ids. */
  sourceIds?: string[];
  /** Stop starting AI calls after this long. */
  timeBudgetMs?: number;
  /** Re-enrich fallback stories published within this many hours. */
  enrichWindowHours?: number;
  fetchText?: (url: string) => Promise<string>;
  now?: number;
  feeds?: StoryFeed[];
  push?: Pick<PushService, 'sendToTopic'>;
  /** Max article-page og:image fetches this run (new stories first, then backfill). Default 60. */
  imageFetchBudget?: number;
  /** Override for tests: returns the og:image of a page. */
  fetchOgImage?: (url: string) => Promise<ImageCandidate | undefined>;
}

export interface SourceImageStat {
  /** Feed items kept this run. */
  items: number;
  /** ...of which the feed itself declared a usable image. */
  feedImages: number;
  /** Stories (changed this run) whose lead source is this feed. */
  stories: number;
  /** ...of which have an image after the og:image step. */
  storiesWithImage: number;
}

export interface ImageReport extends ImageResolveStats {
  perSource: Record<string, SourceImageStat>;
  /** Stories changed this run / with an image. */
  storiesChanged: number;
  storiesChangedWithImage: number;
  /** All known stories (cache + new) / with an image. */
  storiesTotal: number;
  storiesTotalWithImage: number;
}

export interface StoryIngestResult {
  startedAt: string;
  completedAt: string;
  feeds: FeedStat[];
  itemsFetched: number;
  itemsNew: number;
  clusters: number;
  multiSourceClusters: number;
  storiesCreated: number;
  storiesUpdated: number;
  storiesEnriched: number;
  writer: WriterStats & { model: string; geminiKey: boolean };
  firestoreWrites: number;
  changed: Story[];
  today: TodayInFive;
  pushes: number;
  images: ImageReport;
}

const UA = 'Mozilla/5.0 (compatible; TechDailyBot/2.0; +https://techdaily-prod.web.app)';

export async function defaultFetchText(url: string): Promise<string> {
  let last: any;
  for (let attempt = 0; attempt < 2; attempt++) {
    try {
      const res = await fetch(url, {
        headers: { 'User-Agent': UA, Accept: 'application/rss+xml, application/atom+xml, application/xml;q=0.9, text/xml;q=0.9, */*;q=0.5' },
        signal: AbortSignal.timeout(15000),
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      return await res.text();
    } catch (e) {
      last = e;
      await new Promise((r) => setTimeout(r, 800));
    }
  }
  throw last;
}

export function canonical(url: string): string {
  try {
    return UrlNormalizer.canonicalize(url);
  } catch {
    return url;
  }
}

/** Parses one feed's XML into normalised, validated, recent items. */
export function itemsFromFeed(feed: StoryFeed, xml: string, now: number, maxAgeHours: number): { parsed: number; items: NewsItem[] } {
  const raw = FeedParser.parse(xml);
  const out: NewsItem[] = [];
  for (const r of raw) {
    if (!r.title || !r.link) continue;
    const link = r.link.trim();
    if (!DomainValidator.validate(link, feed).isValid) continue;
    if (UrlNormalizer.isHubUrl(link)) continue;
    const title = ContentNormalizer.normalizeTitle(r.title);
    if (title.length < 8 || isLowValueTitle(title)) continue;
    const snippet = ContentNormalizer.stripHtml(r.description || '').slice(0, 2000);
    const published = r.pubDate ? ContentNormalizer.normalizeDate(r.pubDate) : new Date(now);
    const t = Math.min(published.getTime(), now);
    if (now - t > maxAgeHours * HOUR) continue;
    if (feed.includePattern && !feed.includePattern.test(title) && !feed.includePattern.test(snippet.slice(0, 400))) continue;
    out.push({
      sourceId: feed.sourceId,
      sourceName: feed.sourceName,
      url: link,
      canonicalUrl: canonical(link),
      title,
      snippet,
      publishedAt: new Date(t).toISOString(),
      region: feed.region === 'IN' ? 'IN' : 'GLOBAL',
      official: Boolean(feed.official),
      defaultCategory: feed.category,
      ...(r.image ? { image: r.image } : {}),
    });
  }
  out.sort((a, b) => b.publishedAt.localeCompare(a.publishedAt));
  return { parsed: raw.length, items: out.slice(0, feed.maxItemsPerRun ?? 12) };
}

export async function fetchAllFeeds(
  feeds: StoryFeed[],
  fetchText: (url: string) => Promise<string>,
  now: number,
  maxAgeHours: number,
  concurrency: number
): Promise<{ stats: FeedStat[]; items: NewsItem[] }> {
  const stats: FeedStat[] = new Array(feeds.length);
  const items: NewsItem[][] = new Array(feeds.length);
  let cursor = 0;
  const worker = async () => {
    while (cursor < feeds.length) {
      const i = cursor++;
      const feed = feeds[i];
      try {
        const xml = await fetchText(feed.feedUrl);
        const r = itemsFromFeed(feed, xml, now, maxAgeHours);
        stats[i] = { sourceId: feed.sourceId, status: r.parsed > 0 ? 'ok' : 'failed', parsed: r.parsed, kept: r.items.length, ...(r.parsed === 0 ? { error: 'no parseable items' } : {}) };
        items[i] = r.items;
      } catch (e: any) {
        stats[i] = { sourceId: feed.sourceId, status: 'failed', parsed: 0, kept: 0, error: String(e?.message || e) };
        items[i] = [];
      }
    }
  };
  await Promise.all(Array.from({ length: Math.max(1, Math.min(concurrency, feeds.length)) }, worker));
  // Same report from two feeds (e.g. The Hindu sections): keep the first.
  const seen = new Set<string>();
  const flat: NewsItem[] = [];
  for (const it of items.flat()) {
    if (seen.has(it.canonicalUrl)) continue;
    seen.add(it.canonicalUrl);
    flat.push(it);
  }
  return { stats, items: flat };
}

/** Firestore-safe map key for a report URL in `storySources/{id}.snippets`. */
export function snippetKey(canonicalUrl: string): string {
  return `u${sha(canonicalUrl, 16)}`;
}

export function outlets(s: { sources: StorySource[] }): number {
  return new Set(s.sources.map((x) => x.name)).size;
}

export function isDeveloping(s: Pick<Story, 'confidence' | 'unconfirmed' | 'sources'>): boolean {
  return s.confidence === 'low' || (s.unconfirmed && outlets(s) < 2);
}

export function toSource(i: NewsItem): StorySource {
  return { sourceId: i.sourceId, name: i.sourceName, url: i.url, title: i.title, publishedAt: i.publishedAt };
}

export function writerSource(i: NewsItem): WriterSource {
  return { sourceName: i.sourceName, title: i.title, snippet: i.snippet, url: i.url, publishedAt: i.publishedAt, official: i.official };
}

export function categoryHintFor(items: NewsItem[]): CategoryId {
  const counts = new Map<CategoryId, number>();
  for (const i of items) counts.set(i.defaultCategory, (counts.get(i.defaultCategory) ?? 0) + 1);
  const def = [...counts.entries()].sort((a, b) => b[1] - a[1])[0]?.[0];
  return classify(items.map((i) => i.title).join(' · '), items.map((i) => i.snippet).join(' '), def).category;
}

function sourced(i: NewsItem): SourcedCandidate | null {
  return i.image ? { candidate: i.image, sourceName: i.sourceName, sourceUrl: i.url } : null;
}

/** Best feed image across a cluster's items (earliest source wins ties). */
export function bestItemImage(items: NewsItem[]) {
  const sorted = [...items].sort((a, b) => a.publishedAt.localeCompare(b.publishedAt));
  return pickBestImage(sorted.map(sourced));
}

/** Keeps the story's image unless a new source brings a clearly better one. */
export function mergeImage(s: Story, items: NewsItem[]): Story['image'] {
  const fresh = bestItemImage(items);
  if (!s.image) return fresh;
  if (!fresh) return s.image;
  const freshCand = items.find((i) => i.image?.url === fresh.url)?.image;
  return freshCand && imageScore(freshCand) > storedImageScore(s.image) * 1.25 ? fresh : s.image;
}

/** Applies written text to a story (keeps id, slug, sources). */
export function applyWritten(base: Story, w: WrittenStory, nowIso: string): Story {
  const s: Story = {
    ...base,
    headline: w.headline,
    category: w.category,
    whatHappened: w.whatHappened,
    affectsWho: w.affectsWho,
    whatToDo: w.whatToDo,
    whatItMeans: w.whatItMeans,
    scam: w.scam,
    confidence: w.confidence,
    unconfirmed: w.unconfirmed,
    aiModel: w.aiModel,
    needsEnrichment: w.needsEnrichment,
    promptVersion: w.promptVersion,
    updatedAt: nowIso,
  };
  s.developing = isDeveloping(s);
  return s;
}

/** Builds a new story from a written card and its source items. */
export function newStory(items: NewsItem[], w: WrittenStory, nowIso: string, takenSlugs: Set<string>): Story {
  const sorted = [...items].sort((a, b) => a.publishedAt.localeCompare(b.publishedAt));
  const id = storyIdFor(sorted[0].canonicalUrl);
  let slug = storySlug(w.headline, id);
  if (takenSlugs.has(slug)) slug = storySlug(w.headline, id + ':' + sorted.length);
  takenSlugs.add(slug);
  const base: Story = {
    id,
    slug,
    headline: w.headline,
    category: w.category,
    publishedAt: sorted[0].publishedAt,
    updatedAt: nowIso,
    sources: sorted.map(toSource),
    whatHappened: '',
    affectsWho: '',
    whatToDo: [],
    whatItMeans: '',
    scam: null,
    confidence: 'low',
    developing: true,
    aiModel: '',
    needsEnrichment: true,
    enrichAttempts: 0,
    region: items.some((i) => i.region === 'IN') ? 'IN' : 'GLOBAL',
    unconfirmed: false,
    promptVersion: w.promptVersion,
    image: bestItemImage(items),
    imageTries: 0,
  };
  return applyWritten(base, w, nowIso);
}

export interface PipelineDeps {
  db?: Db;
  writer?: StoryWriter;
  cache: StoryCache;
}

/** Reads snippets for stories whose reports are no longer in the feeds (private collection). */
async function loadPrivateSnippets(db: Db | undefined, storyId: string): Promise<Record<string, string>> {
  if (!db) return {};
  try {
    const d = await db.collection(STORY_SOURCES_PRIVATE).doc(storyId).get();
    const m = d.exists ? (d.data()?.snippets as Record<string, string>) : undefined;
    return m && typeof m === 'object' ? m : {};
  } catch {
    return {};
  }
}

export async function runStoryPipeline(opts: StoryIngestOptions, deps: PipelineDeps): Promise<StoryIngestResult> {
  const now = opts.now ?? Date.now();
  const nowIso = new Date(now).toISOString();
  const startedAt = new Date().toISOString();
  const dry = Boolean(opts.dryRun) || !deps.db;
  const writer = deps.writer ?? new StoryWriter();
  const cache = deps.cache;
  const deadline = Date.now() + (opts.timeBudgetMs ?? 15 * 60 * 1000);
  let feeds = (opts.feeds ?? STORY_FEEDS).filter((f) => f.enabled);
  if (opts.sourceIds?.length) feeds = feeds.filter((f) => opts.sourceIds!.includes(f.sourceId));

  // 1. Fetch
  const { stats, items } = await fetchAllFeeds(feeds, opts.fetchText ?? defaultFetchText, now, opts.maxAgeHours ?? 48, opts.concurrency ?? 6);
  const snippetByUrl = new Map(items.map((i) => [i.canonicalUrl, i.snippet]));

  // 2. Skip reports already inside a story
  const known = new Map<string, string>();
  for (const s of cache.stories.values()) for (const x of s.sources) known.set(canonical(x.url), s.id);
  const fresh = items.filter((i) => !known.has(i.canonicalUrl));

  // 3. Cluster new reports with each other and onto recent stories
  const windowMs = 48 * HOUR;
  const seeds: ClusterSeed<NewsItem & { key: string; publishedAtMs: number }>[] = [...cache.stories.values()]
    .filter((s) => now - new Date(s.publishedAt).getTime() <= windowMs)
    .map((s) => ({
      storyId: s.id,
      members: s.sources.map((x) => ({ key: canonical(x.url), title: x.title || s.headline, publishedAtMs: new Date(x.publishedAt).getTime() })),
    }));
  const clusterables = fresh.map((i) => ({ ...i, key: i.canonicalUrl, publishedAtMs: new Date(i.publishedAt).getTime() }));
  const clusters: Cluster<(typeof clusterables)[number]>[] = clusterItems(clusterables, seeds);

  const changed = new Map<string, Story>();
  const privateSnippets = new Map<string, Record<string, string>>();
  let created = 0;
  let updated = 0;
  let enriched = 0;
  let pushes = 0;
  const slugs = cache.slugIndex();

  // 3b. Existing stories that gained sources
  const enrichFirst: string[] = [];
  for (const c of clusters.filter((c) => c.storyId)) {
    const s = cache.stories.get(c.storyId!);
    if (!s) continue;
    const merged: Story = { ...s, sources: [...s.sources, ...c.items.map(toSource)], updatedAt: nowIso, image: mergeImage(s, c.items) };
    merged.region = merged.region === 'IN' || c.items.some((i) => i.region === 'IN') ? 'IN' : 'GLOBAL';
    if (merged.confidence === 'medium' && outlets(merged) >= 3) merged.confidence = 'high';
    merged.developing = isDeveloping(merged);
    cache.upsert(merged);
    changed.set(merged.id, merged);
    privateSnippets.set(merged.id, Object.fromEntries(c.items.map((i) => [snippetKey(i.canonicalUrl), i.snippet])));
    updated++;
    if (merged.needsEnrichment) enrichFirst.push(merged.id);
  }

  // 4. New stories, biggest/most local/newest first so the AI budget goes to what matters
  const newClusters = clusters
    .filter((c) => !c.storyId)
    .sort((a, b) => {
      const sa = new Set(a.items.map((i) => i.sourceName)).size;
      const sb = new Set(b.items.map((i) => i.sourceName)).size;
      if (sb !== sa) return sb - sa;
      const ia = a.items.some((i) => i.region === 'IN' || i.official) ? 1 : 0;
      const ib = b.items.some((i) => i.region === 'IN' || i.official) ? 1 : 0;
      if (ib !== ia) return ib - ia;
      const ta = Math.max(...a.items.map((i) => i.publishedAtMs));
      const tb = Math.max(...b.items.map((i) => i.publishedAtMs));
      return tb - ta;
    });

  for (const c of newClusters) {
    const input: WriterInput = {
      storyId: storyIdFor([...c.items].sort((a, b) => a.publishedAtMs - b.publishedAtMs)[0].canonicalUrl),
      sources: c.items.map(writerSource),
      categoryHint: categoryHintFor(c.items),
    };
    // Past the time budget: still create the story, but with the fallback writer (no AI wait).
    const w = Date.now() < deadline ? await writer.write(input, true) : fallbackStory(input);
    if (!w) continue;
    const s = newStory(c.items, w, nowIso, slugs);
    cache.upsert(s);
    changed.set(s.id, s);
    privateSnippets.set(s.id, Object.fromEntries(c.items.map((i) => [snippetKey(i.canonicalUrl), i.snippet])));
    created++;
    if (opts.push && !dry && pushes < 1 && s.scam && !s.developing && outlets(s) >= 2) {
      const id = await opts.push.sendToTopic(BREAKING_TOPIC, {
        title: 'Scam alert',
        body: s.headline,
        data: { type: 'story', storyId: s.id, slug: s.slug },
      });
      if (id) pushes++;
    }
  }

  // 5. Re-enrich fallback stories (newest first) while AI budget and time remain
  const enrichWindow = (opts.enrichWindowHours ?? 72) * HOUR;
  const candidates = [
    ...enrichFirst.map((id) => cache.stories.get(id)!).filter(Boolean),
    ...cache
      .all()
      .filter((s) => s.needsEnrichment && s.enrichAttempts < 3 && now - new Date(s.publishedAt).getTime() <= enrichWindow)
      .filter((s) => !enrichFirst.includes(s.id)),
  ];
  for (const s of candidates) {
    if (!writer.aiAvailable() || Date.now() > deadline) break;
    if (!s.needsEnrichment) continue;
    const stored = privateSnippets.get(s.id) ?? (await loadPrivateSnippets(dry ? undefined : deps.db, s.id));
    const input: WriterInput = {
      storyId: s.id,
      sources: s.sources.map((x) => {
        const key = canonical(x.url);
        return {
          sourceName: x.name,
          title: x.title || s.headline,
          snippet: snippetByUrl.get(key) ?? stored[snippetKey(key)] ?? '',
          url: x.url,
          publishedAt: x.publishedAt,
          official: STORY_FEEDS.some((f) => f.sourceId === x.sourceId && f.official),
        };
      }),
      categoryHint: s.category,
    };
    const w = await writer.write(input, false);
    const next: Story = w ? applyWritten(s, w, nowIso) : { ...s, enrichAttempts: s.enrichAttempts + 1, updatedAt: nowIso };
    if (w) {
      next.enrichAttempts = s.enrichAttempts + 1;
      enriched++;
    }
    cache.upsert(next);
    changed.set(next.id, next);
  }

  // 6. Images: one og:image page fetch per story still without an image (new/changed first,
  //    then backfill of older stories), capped per run. Dry runs fetch too (read-only) for coverage.
  const imgRun = await resolveMissingImages([...changed.values()], cache.all(), {
    budget: opts.imageFetchBudget ?? 60,
    nowIso,
    fetchOg: opts.fetchOgImage,
  });
  for (const s of imgRun.updated) {
    cache.upsert(s);
    changed.set(s.id, s);
  }

  // 7. Save
  const today = pickTodayInFive(cache.all(), now);
  let writes = 0;
  const changedList = [...changed.values()];
  if (!dry && deps.db) {
    writes += await writeStories(deps.db, changedList);
    // Private snippets (input for later re-enrichment; never client-readable).
    const entries = [...privateSnippets.entries()];
    for (let i = 0; i < entries.length; i += 400) {
      const batch = deps.db.batch();
      for (const [id, snippets] of entries.slice(i, i + 400)) {
        batch.set(deps.db.collection(STORY_SOURCES_PRIVATE).doc(id), { snippets, updatedAt: Timestamp.fromDate(new Date(now)) }, { merge: true });
      }
      await batch.commit();
      writes += Math.min(400, entries.length - i);
    }
    await writeTodayInFive(deps.db, today);
    writes += 2;
  }

  // Image coverage report
  const perSource: Record<string, SourceImageStat> = {};
  const stat = (id: string) => (perSource[id] ??= { items: 0, feedImages: 0, stories: 0, storiesWithImage: 0 });
  for (const i of items) {
    const st = stat(i.sourceId);
    st.items++;
    if (i.image) st.feedImages++;
  }
  for (const s of changedList) {
    const lead = s.sources[0];
    if (!lead) continue;
    const st = stat(lead.sourceId || lead.name);
    st.stories++;
    if (s.image) st.storiesWithImage++;
  }
  const allStories = cache.all();
  const images: ImageReport = {
    ...imgRun.stats,
    perSource,
    storiesChanged: changedList.length,
    storiesChangedWithImage: changedList.filter((s) => s.image).length,
    storiesTotal: allStories.length,
    storiesTotalWithImage: allStories.filter((s) => s.image).length,
  };

  return {
    startedAt,
    completedAt: new Date().toISOString(),
    images,
    feeds: stats,
    itemsFetched: items.length,
    itemsNew: fresh.length,
    clusters: clusters.length,
    multiSourceClusters: clusters.filter((c) => new Set(c.members.map((m) => m.key)).size > 1).length,
    storiesCreated: created,
    storiesUpdated: updated,
    storiesEnriched: enriched,
    writer: { ...writer.stats, model: writer.model, geminiKey: writer.hasApiKey() },
    firestoreWrites: writes,
    changed: changedList,
    today,
    pushes,
  };
}
