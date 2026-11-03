import { FeedParser } from '../src/pipeline/feed-parser';
import {
  feedImageCandidate,
  fetchOgImage,
  firstImgCandidate,
  imageScore,
  MAX_IMAGE_TRIES,
  ogImageCandidate,
  parseStoryImage,
  pickBestImage,
  resolveMissingImages,
  usableImageUrl,
} from '../src/stories/images';
import { bestItemImage, mergeImage, runStoryPipeline } from '../src/stories/story-pipeline';
import { publicStory } from '../src/stories/render/render';
import { docToStory, StoryCache, storyToDoc } from '../src/stories/story-store';
import { StoryFeed } from '../src/stories/feeds';
import { NewsItem, Story } from '../src/stories/types';
import { StoryWriter } from '../src/stories/story-writer';
import { renderRss, renderStoryPage, newsArticleJsonLd } from '../src/stories/render/templates';

const story = (over: Partial<Story> = {}): Story => ({
  id: 'st-1',
  slug: 'a-story-abc123',
  headline: 'A story',
  category: 'ai',
  publishedAt: '2026-11-01T10:00:00.000Z',
  updatedAt: '2026-11-01T10:00:00.000Z',
  sources: [{ sourceId: 'verge', name: 'The Verge', url: 'https://www.theverge.com/a', title: 'A', publishedAt: '2026-11-01T10:00:00.000Z' }],
  whatHappened: 'w',
  affectsWho: 'a',
  whatToDo: ['x'],
  whatItMeans: 'm',
  scam: null,
  confidence: 'medium',
  developing: false,
  aiModel: 'gemini',
  needsEnrichment: false,
  enrichAttempts: 0,
  region: 'GLOBAL',
  unconfirmed: false,
  promptVersion: 'stories-v1',
  ...over,
});

describe('image URL filters', () => {
  it('accepts normal https photos and rejects junk', () => {
    expect(usableImageUrl('https://cdn.x.com/2026/11/phone.jpg')).toBe('https://cdn.x.com/2026/11/phone.jpg');
    expect(usableImageUrl('http://cdn.x.com/a.jpg')).toBeUndefined(); // not https
    expect(usableImageUrl('https://cdn.x.com/anim.gif')).toBeUndefined();
    expect(usableImageUrl('https://cdn.x.com/site/logo.png')).toBeUndefined();
    expect(usableImageUrl('https://cdn.x.com/icons/share.png')).toBeUndefined();
    expect(usableImageUrl('https://cdn.x.com/u/avatar-12.jpg')).toBeUndefined();
    expect(usableImageUrl('https://cdn.x.com/a.jpg', undefined, 1, 1)).toBeUndefined(); // tracking pixel
    expect(usableImageUrl('https://cdn.x.com/a.jpg', undefined, 150, 150)).toBeUndefined();
    expect(usableImageUrl('https://cdn.x.com/a.jpg?w=96')).toBeUndefined();
    expect(usableImageUrl('https://cdn.x.com/up/photo-150x150.jpg')).toBeUndefined();
    expect(usableImageUrl('https://pixel.wp.com/g.jpg')).toBeUndefined();
    expect(usableImageUrl('//cdn.x.com/b.webp')).toBe('https://cdn.x.com/b.webp');
    // "pixel" in a phone photo name is fine
    expect(usableImageUrl('https://cdn.x.com/google-pixel-10-review.jpg')).toBeDefined();
  });
});

describe('feed item images', () => {
  const rss = (item: string) => `<?xml version="1.0"?><rss version="2.0" xmlns:media="http://search.yahoo.com/mrss/"><channel><title>x</title>
<item><title>Big phone launch today in India</title><link>https://news.example.com/a</link>${item}</item></channel></rss>`;

  it('prefers the largest media:content and keeps its size', () => {
    const [it] = FeedParser.parse(
      rss(`<media:content url="https://img.example.com/small.jpg" medium="image" width="300" height="200"/>
           <media:content url="https://img.example.com/big.jpg" medium="image" width="1200" height="675"/>`)
    );
    expect(it.image).toEqual({ url: 'https://img.example.com/big.jpg', width: 1200, height: 675, origin: 'media' });
  });

  it('reads media:thumbnail, enclosure and the first <img> in content', () => {
    expect(FeedParser.parse(rss(`<media:thumbnail url="https://img.example.com/t.jpg" width="640" height="360"/>`))[0].image?.origin).toBe('thumbnail');
    expect(FeedParser.parse(rss(`<enclosure url="https://img.example.com/e.jpg" type="image/jpeg" length="0"/>`))[0].image?.url).toBe(
      'https://img.example.com/e.jpg'
    );
    expect(FeedParser.parse(rss(`<enclosure url="https://img.example.com/e.mp3" type="audio/mpeg" length="0"/>`))[0].image).toBeUndefined();
    const html = `<description><![CDATA[<p><img src="https://img.example.com/pixel.gif" width="1" height="1"><img src="https://img.example.com/real.jpg" width="800" height="450"></p>]]></description>`;
    expect(FeedParser.parse(rss(html))[0].image).toEqual({ url: 'https://img.example.com/real.jpg', width: 800, height: 450, origin: 'html' });
  });

  it('handles escaped HTML and srcset', () => {
    expect(firstImgCandidate('<img srcset="https://i.x.com/s.jpg 300w, https://i.x.com/l.jpg 1200w">')?.url).toBe('https://i.x.com/l.jpg');
    expect(feedImageCandidate({ description: '&lt;img src="https://i.x.com/esc.jpg"&gt;' })?.url).toBe('https://i.x.com/esc.jpg');
  });
});

describe('og:image', () => {
  const page = `<html><head><meta property="og:image" content="https://cdn.site.com/lead.jpg"><meta property="og:image:width" content="1600">
<meta property="og:image:height" content="900"><meta name="twitter:image" content="https://cdn.site.com/tw.jpg"></head><body>`;

  it('parses og:image with its declared size, falls back to twitter:image', () => {
    expect(ogImageCandidate(page, 'https://site.com/a')).toEqual({ url: 'https://cdn.site.com/lead.jpg', width: 1600, height: 900, origin: 'og' });
    expect(ogImageCandidate('<meta name="twitter:image" content="/img/x.jpg">', 'https://site.com/a')?.url).toBe('https://site.com/img/x.jpg');
    expect(ogImageCandidate('<meta property="og:image" content="https://site.com/logo.png">')).toBeUndefined();
  });

  it('fetches the page head with a timeout and never throws', async () => {
    const calls: any[] = [];
    const ok = async (url: string, init: any) => {
      calls.push([url, init]);
      return { ok: true, url, headers: { get: () => 'text/html' }, text: async () => page };
    };
    expect((await fetchOgImage('https://site.com/a', { fetchFn: ok }))?.url).toBe('https://cdn.site.com/lead.jpg');
    expect(calls[0][1].signal).toBeDefined();
    expect(await fetchOgImage('https://site.com/a', { fetchFn: async () => ({ ok: false }) })).toBeUndefined();
    expect(await fetchOgImage('https://site.com/a', { fetchFn: async () => Promise.reject(new Error('boom')) })).toBeUndefined();
    expect(await fetchOgImage('ftp://site.com/a', { fetchFn: ok })).toBeUndefined();
  });
});

describe('best image across a cluster', () => {
  const item = (name: string, at: string, image?: NewsItem['image']): NewsItem => ({
    sourceId: name.toLowerCase(),
    sourceName: name,
    url: `https://${name.toLowerCase()}.com/x`,
    canonicalUrl: `https://${name.toLowerCase()}.com/x`,
    title: 't',
    snippet: '',
    publishedAt: at,
    region: 'GLOBAL',
    official: false,
    defaultCategory: 'ai',
    ...(image ? { image } : {}),
  });

  it('prefers larger / og images and credits that source', () => {
    const a = item('Alpha', '2026-11-01T01:00:00Z', { url: 'https://a.com/t.jpg', width: 320, height: 180, origin: 'thumbnail' });
    const b = item('Beta', '2026-11-01T02:00:00Z', { url: 'https://b.com/big.jpg', width: 1600, height: 900, origin: 'media' });
    const c = item('Gamma', '2026-11-01T03:00:00Z');
    expect(bestItemImage([a, b, c])).toEqual({ url: 'https://b.com/big.jpg', sourceName: 'Beta', sourceUrl: 'https://beta.com/x', width: 1600, height: 900 });
    expect(bestItemImage([c])).toBeNull();
    expect(imageScore({ origin: 'og' })).toBeGreaterThan(imageScore({ origin: 'thumbnail' }));
    expect(pickBestImage([null, undefined])).toBeNull();
    // Existing image kept unless the new one is clearly better
    const s = story({ image: { url: 'https://a.com/1.jpg', sourceName: 'Alpha', sourceUrl: 'https://alpha.com/x', width: 1200 } });
    expect(mergeImage(s, [b])?.url).toBe('https://b.com/big.jpg');
    expect(mergeImage(s, [a])?.url).toBe('https://a.com/1.jpg');
    expect(mergeImage(story(), [a])?.url).toBe('https://a.com/t.jpg');
  });
});

describe('og:image step + backfill', () => {
  it('fetches once per story without an image, changed first, capped by budget', async () => {
    const changed = [story({ id: 'new-1', publishedAt: '2026-11-01T12:00:00Z' }), story({ id: 'has', image: { url: 'https://x.com/a.jpg', sourceName: 'X', sourceUrl: 'https://x.com/' } })];
    const backlog = [
      story({ id: 'old-1', publishedAt: '2026-10-30T12:00:00Z' }),
      story({ id: 'old-2', publishedAt: '2026-10-31T12:00:00Z' }),
      story({ id: 'gave-up', imageTries: MAX_IMAGE_TRIES }),
    ];
    const fetched: string[] = [];
    const r = await resolveMissingImages(changed, backlog, {
      budget: 2,
      nowIso: '2026-11-01T13:00:00.000Z',
      fetchOg: async (url) => {
        fetched.push(url);
        return fetched.length === 1 ? { url: 'https://cdn.verge.com/lead.jpg', width: 1200, height: 675, origin: 'og' } : undefined;
      },
    });
    expect(fetched).toHaveLength(2);
    expect(r.stats).toEqual({ fetches: 2, hits: 1, backfilled: 0 });
    const hit = r.updated.find((s) => s.id === 'new-1')!;
    expect(hit.image).toEqual({ url: 'https://cdn.verge.com/lead.jpg', sourceName: 'The Verge', sourceUrl: 'https://www.theverge.com/a', width: 1200, height: 675 });
    expect(hit.updatedAt).toBe('2026-11-01T13:00:00.000Z');
    const miss = r.updated.find((s) => s.id === 'old-2')!; // newest backlog story first
    expect(miss.image).toBeUndefined();
    expect(miss.imageTries).toBe(1);
    expect(miss.updatedAt).toBe('2026-11-01T10:00:00.000Z');
  });

  it('pipeline: feed images on new stories, og fetch for the rest, coverage report, backfill of cached stories', async () => {
    const feed: StoryFeed = {
      sourceId: 'demo',
      sourceName: 'Demo News',
      domain: 'demo.example.com',
      feedUrl: 'https://demo.example.com/rss',
      category: 'ai',
      kind: 'india',
      defaultCategory: 'ai',
      enabled: true,
      trustLevel: 'verified',
      region: 'IN',
      maxItemsPerRun: 12,
    } as any;
    const now = Date.parse('2026-11-01T12:00:00Z');
    const xml = `<?xml version="1.0"?><rss version="2.0" xmlns:media="http://search.yahoo.com/mrss/"><channel><title>d</title>
<item><title>OpenAI launches a new reasoning model for Indian languages</title><link>https://demo.example.com/one</link><pubDate>Sun, 01 Nov 2026 10:00:00 GMT</pubDate>
<media:content url="https://img.demo.example.com/one.jpg" medium="image" width="1200" height="675"/></item>
<item><title>Nvidia shows a faster chip for data centres in Bengaluru</title><link>https://demo.example.com/two</link><pubDate>Sun, 01 Nov 2026 09:00:00 GMT</pubDate></item>
</channel></rss>`;
    const cache = new StoryCache();
    cache.upsert(story({ id: 'old', slug: 'old-abc123', publishedAt: '2026-10-29T10:00:00.000Z', updatedAt: '2026-10-29T10:00:00.000Z' }));
    const og: string[] = [];
    const r = await runStoryPipeline(
      {
        dryRun: true,
        now,
        feeds: [feed],
        fetchText: async () => xml,
        fetchOgImage: async (url) => {
          og.push(url);
          return { url: `https://img.cdn.com/${og.length}.jpg`, origin: 'og' };
        },
      },
      { cache, writer: new StoryWriter({ apiKey: '' }) }
    );
    expect(r.storiesCreated).toBe(2);
    const one = r.changed.find((s) => s.sources[0].url.endsWith('/one'))!;
    const two = r.changed.find((s) => s.sources[0].url.endsWith('/two'))!;
    expect(one.image).toEqual({ url: 'https://img.demo.example.com/one.jpg', sourceName: 'Demo News', sourceUrl: 'https://demo.example.com/one', width: 1200, height: 675 });
    expect(og).toEqual(['https://demo.example.com/two', 'https://www.theverge.com/a']); // new story first, then backfill
    expect(two.image?.url).toBe('https://img.cdn.com/1.jpg');
    expect(cache.stories.get('old')!.image?.sourceName).toBe('The Verge');
    expect(r.images.perSource.demo).toEqual({ items: 2, feedImages: 1, stories: 2, storiesWithImage: 2 });
    expect(r.images).toMatchObject({ fetches: 2, hits: 2, backfilled: 1, storiesTotal: 3, storiesTotalWithImage: 3 });
  });
});

describe('storage + rendering', () => {
  const img = { url: 'https://cdn.site.com/lead.jpg', sourceName: 'Site', sourceUrl: 'https://site.com/a', width: 1600, height: 900 };

  it('round-trips through Firestore docs and drops unsafe images', () => {
    const doc = storyToDoc(story({ image: img })) as any;
    expect(doc.image).toEqual(img);
    expect(storyToDoc(story()).image).toBeNull();
    expect(docToStory(doc).image).toEqual(img);
    expect(parseStoryImage({ url: 'http://x.com/a.jpg', sourceName: 'X', sourceUrl: 'https://x.com' })).toBeNull();
    expect(parseStoryImage({ url: 'https://x.com/a.jpg', sourceName: 'X', sourceUrl: 'javascript:alert(1)' })).toBeNull();
    expect(publicStory(story({ image: img })).image).toEqual(img);
    expect(publicStory(story()).image).toBeNull();
  });

  it('story page uses the image as og:image with a visible credit; category art otherwise', () => {
    const ctx = { siteUrl: 'https://techdaily-prod.web.app', firebaseProjectId: 'p', now: Date.parse('2026-11-01T12:00:00Z') };
    const html = renderStoryPage(story({ image: img }), ctx);
    expect(html).toContain('<meta property="og:image" content="https://cdn.site.com/lead.jpg">');
    expect(html).toContain('<meta property="og:image:width" content="1600">');
    expect(html).toMatch(/Image: <a href="https:\/\/site\.com\/a"[^>]*>Site<\/a>/);
    expect(html).toContain('loading="eager"');
    expect(html).toContain('/art/ai.svg');
    expect(newsArticleJsonLd(story({ image: img }), ctx).image).toEqual(['https://cdn.site.com/lead.jpg', 'https://techdaily-prod.web.app/og/ai.png']);
    const plain = renderStoryPage(story(), ctx);
    expect(plain).toContain('<meta property="og:image" content="https://techdaily-prod.web.app/og/ai.png">');
    expect(plain).not.toContain('Image: <a');
    const rss = renderRss([story({ image: img })], ctx);
    expect(rss).toContain('xmlns:media="http://search.yahoo.com/mrss/"');
    expect(rss).toContain('<media:content url="https://cdn.site.com/lead.jpg" medium="image" width="1600" height="900"/>');
    expect(rss).toContain('<enclosure url="https://cdn.site.com/lead.jpg" type="image/jpeg" length="0"/>');
  });
});
