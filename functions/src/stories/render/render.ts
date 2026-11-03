/**
 * `render` job: writes the static, crawlable site into the Flutter web build output (build/web):
 *   /story/<slug>/index.html, /c/<category>/index.html, /sitemap.xml, /robots.txt, /rss.xml,
 *   /data/feed.json (what the Flutter app reads — no Firestore reads per visitor),
 *   and a pre-rendered "Today in 5" + latest block inside /index.html.
 * Firebase Hosting serves these static files before the `** -> /index.html` rewrite.
 */
import * as fs from 'fs';
import * as path from 'path';
import { CATEGORY_IDS } from '../categories';
import { isNonTechStory } from '../tech-filter';
import { pickTodayInFive, rankStories, TodayInFive } from '../ranking';
import { Story } from '../types';
import {
  DEFAULT_SITE_URL,
  injectIntoIndex,
  renderCategoryPage,
  renderIndexSeoBlock,
  renderRobots,
  renderRss,
  renderSitemap,
  renderStoryPage,
  SiteContext,
} from './templates';

export interface RenderOptions {
  outDir: string;
  stories: Story[];
  now?: number;
  siteUrl?: string;
  firebaseProjectId?: string;
  /** Max story pages (newest first). */
  maxStoryPages?: number;
  /** Stories embedded in data/feed.json for the app. */
  feedSize?: number;
  /** Write data/feed.json even when index.html is missing (tests). */
  requireIndex?: boolean;
}

export interface RenderResult {
  storyPages: number;
  categoryPages: number;
  indexInjected: boolean;
  feedStories: number;
  today: TodayInFive;
  bytes: number;
}

/** App-facing JSON shape for one story (no internal pipeline fields). */
export function publicStory(s: Story) {
  return {
    id: s.id,
    slug: s.slug,
    headline: s.headline,
    category: s.category,
    publishedAt: s.publishedAt,
    updatedAt: s.updatedAt,
    sources: s.sources.map((x) => ({ name: x.name, url: x.url, title: x.title, publishedAt: x.publishedAt })),
    whatHappened: s.whatHappened,
    affectsWho: s.affectsWho,
    whatToDo: s.whatToDo,
    whatItMeans: s.whatItMeans,
    scam: s.scam,
    confidence: s.confidence,
    developing: s.developing,
    aiModel: s.aiModel,
    region: s.region,
    image: s.image
      ? {
          url: s.image.url,
          sourceName: s.image.sourceName,
          sourceUrl: s.image.sourceUrl,
          ...(s.image.width ? { width: s.image.width } : {}),
          ...(s.image.height ? { height: s.image.height } : {}),
        }
      : null,
  };
}

function validStory(s: Story): boolean {
  return Boolean(s.id && s.slug && /^[a-z0-9-]+$/.test(s.slug) && s.headline && s.sources.length > 0);
}

export function renderSite(opts: RenderOptions): RenderResult {
  const now = opts.now ?? Date.now();
  const ctx: SiteContext = {
    siteUrl: (opts.siteUrl ?? DEFAULT_SITE_URL).replace(/\/+$/, ''),
    firebaseProjectId: opts.firebaseProjectId ?? 'techdaily-prod',
    now,
  };
  const out = path.resolve(opts.outDir);
  const indexFile = path.join(out, 'index.html');
  const hasIndex = fs.existsSync(indexFile);
  if (opts.requireIndex !== false && !hasIndex) {
    throw new Error(`${indexFile} not found — run "flutter build web --release" first (render writes into the Flutter build).`);
  }
  let bytes = 0;
  const write = (rel: string, content: string) => {
    const file = path.join(out, rel);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, content);
    bytes += Buffer.byteLength(content);
  };

  const all = opts.stories
    .filter(validStory)
    // Purely tech: never publish a stored story that is clearly not technology news.
    .filter((s) => !isNonTechStory(s))
    .sort((a, b) => b.publishedAt.localeCompare(a.publishedAt));
  const pages = all.slice(0, opts.maxStoryPages ?? 5000);
  const bySlug = new Map(pages.map((s) => [s.slug, s]));

  // Fresh output for generated folders (no stale pages from older renders).
  for (const dir of ['story', 'c', 'data']) fs.rmSync(path.join(out, dir), { recursive: true, force: true });

  const byCat = new Map<string, Story[]>(CATEGORY_IDS.map((c) => [c, [] as Story[]]));
  for (const s of pages) byCat.get(s.category)?.push(s);

  for (const s of pages) {
    const related = (byCat.get(s.category) ?? []).filter((r) => r.id !== s.id).slice(0, 4);
    write(path.join('story', s.slug, 'index.html'), renderStoryPage(s, ctx, related));
  }
  for (const c of CATEGORY_IDS) write(path.join('c', c, 'index.html'), renderCategoryPage(c, (byCat.get(c) ?? []).slice(0, 60), ctx));

  const today = pickTodayInFive(pages, now);
  write('sitemap.xml', renderSitemap(pages, ctx));
  write('rss.xml', renderRss(pages.slice(0, 50), ctx));
  write('robots.txt', renderRobots(ctx));

  const feed = pages.slice(0, opts.feedSize ?? 250);
  write(
    path.join('data', 'feed.json'),
    JSON.stringify({ version: 1, generatedAt: new Date(now).toISOString(), today, top: rankStories(feed, now).slice(0, 30).map((s) => s.id), stories: feed.map(publicStory) })
  );

  let indexInjected = false;
  if (hasIndex) {
    const html = fs.readFileSync(indexFile, 'utf8');
    const block = renderIndexSeoBlock(today, pages.slice(0, 30), ctx, bySlug);
    write('index.html', injectIntoIndex(html, block, today));
    indexInjected = true;
  }

  return { storyPages: pages.length, categoryPages: CATEGORY_IDS.length, indexInjected, feedStories: feed.length, today, bytes };
}
