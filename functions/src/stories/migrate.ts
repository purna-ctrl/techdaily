/**
 * One-off: converts the v1 `articles` collection into v2 `stories` (clustered, rule-based fallback
 * cards marked needsEnrichment). `articles` is only read, never changed. Re-running is safe:
 * articles whose URL is already in a story are skipped.
 */
import { Timestamp } from 'firebase-admin/firestore';
import { toCategoryId } from './categories';
import { clusterItems } from './clusterer';
import { isLowValueTitle, STORY_FEEDS } from './feeds';
import { pickTodayInFive } from './ranking';
import { StoryCache, writeStories, writeTodayInFive } from './story-store';
import { fallbackStory } from './story-writer';
import { canonical, categoryHintFor, isDeveloping, newStory, outlets, snippetKey, STORY_SOURCES_PRIVATE, toSource, writerSource } from './story-pipeline';
import { storyIdFor } from './text';
import { NewsItem, Story } from './types';

type Db = FirebaseFirestore.Firestore;

export interface MigrateResult {
  articlesRead: number;
  articlesUsable: number;
  skippedKnown: number;
  storiesCreated: number;
  storiesUpdated: number;
  firestoreWrites: number;
  changed: Story[];
}

function iso(v: any): string {
  if (!v) return new Date().toISOString();
  if (typeof v.toDate === 'function') return v.toDate().toISOString();
  const d = new Date(v);
  return isNaN(d.getTime()) ? new Date().toISOString() : d.toISOString();
}

/** Maps one v1 article document to a feed item. */
export function articleToItem(d: Record<string, any>): NewsItem | null {
  const url = typeof d.sourceUrl === 'string' ? d.sourceUrl.trim() : '';
  const title = typeof d.title === 'string' ? d.title.trim() : '';
  if (!url || !/^https?:\/\//.test(url) || title.length < 8 || isLowValueTitle(title)) return null;
  if (d.status && d.status !== 'published') return null;
  const feed = STORY_FEEDS.find((f) => f.sourceId === d.sourceId);
  const snippet = [d.summary, d.whatHappened].filter((x) => typeof x === 'string').join(' ').slice(0, 2000);
  return {
    sourceId: String(d.sourceId ?? ''),
    sourceName: feed?.sourceName ?? String(d.sourceName ?? 'Source'),
    url,
    canonicalUrl: canonical(url),
    title,
    snippet,
    publishedAt: iso(d.publishedAt),
    region: d.region === 'IN' || feed?.region === 'IN' ? 'IN' : 'GLOBAL',
    official: Boolean(feed?.official),
    defaultCategory: feed?.category ?? toCategoryId(d.category),
  };
}

export async function migrateArticles(
  db: Db,
  cache: StoryCache,
  opts: { dryRun?: boolean; limit?: number; now?: number } = {}
): Promise<MigrateResult> {
  const now = opts.now ?? Date.now();
  const nowIso = new Date(now).toISOString();
  let q: FirebaseFirestore.Query = db.collection('articles').orderBy('publishedAt', 'desc');
  if (opts.limit) q = q.limit(opts.limit);
  const snap = await q.get();
  const items = snap.docs.map((d) => articleToItem(d.data())).filter((x): x is NewsItem => Boolean(x));

  const known = new Set<string>();
  for (const s of cache.stories.values()) for (const x of s.sources) known.add(canonical(x.url));
  const fresh = items.filter((i) => !known.has(i.canonicalUrl));

  const seeds = [...cache.stories.values()].map((s) => ({
    storyId: s.id,
    members: s.sources.map((x) => ({ key: canonical(x.url), title: x.title || s.headline, publishedAtMs: new Date(x.publishedAt).getTime() })),
  }));
  const clusters = clusterItems(
    fresh.map((i) => ({ ...i, key: i.canonicalUrl, publishedAtMs: new Date(i.publishedAt).getTime() })),
    seeds
  );

  const changed = new Map<string, Story>();
  const snippets = new Map<string, Record<string, string>>();
  const slugs = cache.slugIndex();
  let created = 0;
  let updated = 0;
  for (const c of clusters) {
    if (c.storyId) {
      const s = cache.stories.get(c.storyId);
      if (!s) continue;
      const merged: Story = { ...s, sources: [...s.sources, ...c.items.map(toSource)], updatedAt: nowIso };
      if (merged.confidence === 'medium' && outlets(merged) >= 3) merged.confidence = 'high';
      merged.developing = isDeveloping(merged);
      cache.upsert(merged);
      changed.set(merged.id, merged);
      updated++;
    } else {
      const sorted = [...c.items].sort((a, b) => a.publishedAtMs - b.publishedAtMs);
      const w = fallbackStory({ storyId: storyIdFor(sorted[0].canonicalUrl), sources: c.items.map(writerSource), categoryHint: categoryHintFor(c.items) });
      const s = newStory(c.items, w, nowIso, slugs);
      cache.upsert(s);
      changed.set(s.id, s);
      created++;
    }
    snippets.set(
      c.storyId ?? storyIdFor([...c.items].sort((a, b) => a.publishedAtMs - b.publishedAtMs)[0].canonicalUrl),
      Object.fromEntries(c.items.map((i) => [snippetKey(i.canonicalUrl), i.snippet]))
    );
  }

  let writes = 0;
  const list = [...changed.values()];
  if (!opts.dryRun) {
    writes += await writeStories(db, list);
    const entries = [...snippets.entries()];
    for (let i = 0; i < entries.length; i += 400) {
      const batch = db.batch();
      for (const [id, sn] of entries.slice(i, i + 400)) {
        batch.set(db.collection(STORY_SOURCES_PRIVATE).doc(id), { snippets: sn, updatedAt: Timestamp.fromDate(new Date(now)) }, { merge: true });
      }
      await batch.commit();
      writes += Math.min(400, entries.length - i);
    }
    await writeTodayInFive(db, pickTodayInFive(cache.all(), now));
    writes += 2;
  }
  return {
    articlesRead: snap.size,
    articlesUsable: items.length,
    skippedKnown: items.length - fresh.length,
    storiesCreated: created,
    storiesUpdated: updated,
    firestoreWrites: writes,
    changed: list,
  };
}
