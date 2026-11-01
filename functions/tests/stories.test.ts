import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import { XMLParser, XMLValidator } from 'fast-xml-parser';
import { classify, CATEGORY_IDS, looksLikeScam, toCategoryId } from '../src/stories/categories';
import { clusterItems, IdfModel, titleSimilarity, titleTokens } from '../src/stories/clusterer';
import { isLowValueTitle, isOfficialAdvisoryUrl, STORY_FEEDS } from '../src/stories/feeds';
import { pickTodayInFive, rankStories, storyScore } from '../src/stories/ranking';
import { renderSite, publicStory } from '../src/stories/render/render';
import {
  injectIntoIndex,
  newsArticleJsonLd,
  renderCategoryPage,
  renderIndexSeoBlock,
  renderRss,
  renderSitemap,
  renderStoryPage,
  SiteContext,
  whatsappUrl,
} from '../src/stories/render/templates';
import { docToStory, StoryCache, storyToDoc } from '../src/stories/story-store';
import { isDeveloping, itemsFromFeed, runStoryPipeline } from '../src/stories/story-pipeline';
import { fallbackStory, StoryValidationError, StoryWriter, validateStoryJson, WriterInput } from '../src/stories/story-writer';
import { cleanHeadline, escapeHtml, findCopiedRun, jsonForScript, slugify, storySlug } from '../src/stories/text';
import { resetGeminiBudget } from '../src/ai/server-ai-summarizer';
import { Story } from '../src/stories/types';

const NOW = Date.parse('2026-11-01T12:00:00Z');
const H = 3600 * 1000;
const iso = (hoursAgo: number) => new Date(NOW - hoursAgo * H).toISOString();
const ctx: SiteContext = { siteUrl: 'https://techdaily-prod.web.app', firebaseProjectId: 'techdaily-prod', now: NOW };

function story(over: Partial<Story> = {}): Story {
  const id = over.id ?? 'st-1';
  return {
    id,
    slug: over.slug ?? `upi-sets-a-record-${id}`,
    headline: 'UPI sets a new monthly record',
    category: 'money-fintech',
    publishedAt: iso(2),
    updatedAt: iso(1),
    sources: [{ sourceId: 'et-tech', name: 'ET Tech', url: `https://economictimes.indiatimes.com/tech/${id}.cms`, title: 'Record UPI transactions in October', publishedAt: iso(2) }],
    whatHappened: 'People made more UPI payments in October than in any month before.',
    affectsWho: 'Everyone who pays with UPI apps.',
    whatToDo: ['Nothing to do — keep using UPI as usual.'],
    whatItMeans: 'UPI keeps growing, so more shops will accept it.',
    scam: null,
    confidence: 'medium',
    developing: false,
    aiModel: 'gemini-flash-lite-latest',
    needsEnrichment: false,
    enrichAttempts: 0,
    region: 'IN',
    unconfirmed: false,
    promptVersion: 'stories-v1',
    ...over,
  };
}

const writerInput = (over: Partial<WriterInput> = {}): WriterInput => ({
  storyId: 'st-x',
  categoryHint: 'scams-security',
  sources: [
    {
      sourceName: 'The Hindu',
      title: 'Fake courier SMS scam targets UPI users in Chennai',
      snippet:
        'Police in Chennai warned residents about a new scam in which fraudsters send SMS messages claiming a courier parcel is held and ask victims to pay a small fee through a link that steals their UPI PIN and bank details.',
      url: 'https://www.thehindu.com/news/cities/chennai/fake-courier-sms.ece',
      publishedAt: iso(3),
      official: false,
    },
  ],
  ...over,
});

const goodAiJson = {
  headline: 'Fake parcel texts are tricking UPI users in Chennai',
  category: 'scams-security',
  whatHappened: 'Chennai police say crooks are texting people about a stuck parcel and asking for a small fee.',
  affectsWho: 'Anyone who gets SMS messages and pays with UPI.',
  whatToDo: ['Ignore texts about parcels you did not order.', 'Never type your UPI PIN to receive anything.'],
  whatItMeans: 'A tiny fee request can empty your bank account, so check before you pay.',
  isScam: true,
  scam: {
    howItWorks: 'You get an SMS saying a parcel is held. The link opens a fake payment page. When you pay, they capture your UPI PIN.',
    warningSigns: ['A parcel you never ordered', 'A link asking for a small fee'],
    ifTargeted: ['Call your bank and block UPI.', 'Call 1930 or report at cybercrime.gov.in.'],
    advisoryUrl: 'https://cybercrime.gov.in/fake-advisory-not-in-report',
  },
  confidence: 'medium',
  unconfirmed: false,
};

// ---------------------------------------------------------------------------------------------
describe('slug and text helpers', () => {
  test('slugify folds case, accents and punctuation', () => {
    expect(slugify('Apple’s iPhone 18 Pro: ₹1,29,900 in India!')).toBe('apples-iphone-18-pro-1-29-900-in-india');
    expect(slugify('Café & Crème')).toBe('cafe-and-creme');
    expect(slugify('')).toBe('');
  });
  test('story slug is stable, url-safe and unique per id', () => {
    const a = storySlug('UPI hits a record', 'st-aaa');
    expect(a).toMatch(/^upi-hits-a-record-[0-9a-f]{6}$/);
    expect(storySlug('UPI hits a record', 'st-aaa')).toBe(a);
    expect(storySlug('UPI hits a record', 'st-bbb')).not.toBe(a);
    expect(storySlug('!!!', 'st-a')).toMatch(/^story-[0-9a-f]{6}$/);
  });
  test('cleanHeadline strips publisher suffixes', () => {
    expect(cleanHeadline('Big launch today - The Verge', 'The Verge')).toBe('Big launch today');
    expect(cleanHeadline('Big launch | Inc42')).toBe('Big launch');
  });
  test('escaping', () => {
    expect(escapeHtml(`<a href="x">'&'</a>`)).toBe('&lt;a href=&quot;x&quot;&gt;&#39;&amp;&#39;&lt;/a&gt;');
    expect(jsonForScript({ a: '</script><b>' })).not.toContain('</script>');
    expect(JSON.parse(jsonForScript({ a: '</script>&' }))).toEqual({ a: '</script>&' });
  });
  test('findCopiedRun detects 10-word copies only', () => {
    const src = 'the quick brown fox jumps over the lazy dog near the river bank today';
    expect(findCopiedRun('Something: the quick brown fox jumps over the lazy dog near the river.', [src])).toBeTruthy();
    expect(findCopiedRun('A fox jumped over a dog by the river.', [src])).toBeNull();
  });
});

// ---------------------------------------------------------------------------------------------
describe('category classification', () => {
  test('keywords pick the right category', () => {
    expect(classify('Fake courier SMS scam steals UPI PIN', '').category).toBe('scams-security');
    expect(classify('OpenAI launches new ChatGPT model', '').category).toBe('ai');
    expect(classify('Samsung Galaxy S26 launched in India with Snapdragon chip', '').category).toBe('phones-gadgets');
    expect(classify('TSMC starts 2nm chip production', '').category).toBe('chips-hardware');
    expect(classify('Zepto raises $400 million in Series G funding', '').category).toBe('startups-india');
    expect(classify('RBI changes rules for UPI payments and loans', '').category).toBe('money-fintech');
    expect(classify('ISRO launches navigation satellite', '').category).toBe('innovations');
    expect(classify('New DPDP rules on personal data and consent', '').category).toBe('privacy');
  });
  test('default category breaks ties and weak matches', () => {
    expect(classify('A quiet day', 'nothing here', 'privacy').category).toBe('privacy');
  });
  test('toCategoryId maps labels and v1 names', () => {
    expect(toCategoryId('Money & Fintech')).toBe('money-fintech');
    expect(toCategoryId('Cybersecurity')).toBe('scams-security');
    expect(toCategoryId('AI & Machine Learning')).toBe('ai');
    expect(toCategoryId('nonsense', 'ai')).toBe('ai');
    expect(CATEGORY_IDS).toHaveLength(8);
  });
  test('scam detection', () => {
    expect(looksLikeScam('Digital arrest fraud: retired teacher loses ₹20 lakh')).toBe(true);
    expect(looksLikeScam('Chrome patches zero-day bug')).toBe(false);
  });
  test('low-value titles are skipped', () => {
    expect(isLowValueTitle('Best Phones Under Rs. 20,000 in India')).toBe(true);
    expect(isLowValueTitle('Weekend Apple deals: AirPods, MacBooks')).toBe(true);
    expect(isLowValueTitle('Microsoft signs $10 billion deal with OpenAI')).toBe(false);
    expect(isLowValueTitle('Wordle hints and answer for today')).toBe(true);
    expect(isLowValueTitle('Oppo Enco X4 Review: Premium Sound That Beats the Price')).toBe(true);
    expect(isLowValueTitle('Apple iPad mini vs Oppo Pad mini: what to buy')).toBe(true);
    expect(isLowValueTitle('8 best space heaters 2026, tested')).toBe(true);
    expect(isLowValueTitle('SEBI puts Paytm IPO under review after complaints')).toBe(false);
  });
  test('official advisory host check', () => {
    expect(isOfficialAdvisoryUrl('https://www.cert-in.org.in/s2cMainServlet?pageid=X')).toBe(true);
    expect(isOfficialAdvisoryUrl('https://cybercrime.gov.in/')).toBe(true);
    expect(isOfficialAdvisoryUrl('https://cybercrime.gov.in.evil.com/')).toBe(false);
    expect(isOfficialAdvisoryUrl('javascript:alert(1)')).toBe(false);
  });
  test('every feed has a valid category and https URL', () => {
    for (const f of STORY_FEEDS) {
      expect(CATEGORY_IDS).toContain(f.category);
      expect(f.feedUrl).toMatch(/^https:\/\//);
    }
    expect(new Set(STORY_FEEDS.map((f) => f.sourceId)).size).toBe(STORY_FEEDS.length);
  });
});

// ---------------------------------------------------------------------------------------------
describe('clusterer', () => {
  const item = (key: string, title: string, hoursAgo: number) => ({ key, title, publishedAtMs: NOW - hoursAgo * H });

  test('groups reports about the same event and keeps different events apart', () => {
    const items = [
      item('a', 'FBI links North Korea to record $6.4 billion Binance crypto heist', 3),
      item('b', 'North Korea linked to massive Binance crypto heist', 2),
      item('c', 'Samsung Galaxy Fit 4 features revealed through companion app teardown', 5),
      item('d', 'Samsung Galaxy Fit 4 leaks, key features revealed', 4),
      item('e', 'OpenAI cuts funding target by $10 billion', 6),
      item('f', 'OpenAI reportedly lowers funding target for new round', 5),
      item('g', 'Apple launches new iPad Air with M4 chip', 1),
      item('h', 'Apple launches new iPhone 18 colours', 1),
    ];
    const clusters = clusterItems(items);
    const keys = clusters.map((c) => c.items.map((i) => i.key).sort().join(''));
    expect(keys).toEqual(expect.arrayContaining(['ab', 'cd', 'ef', 'g', 'h']));
    expect(clusters).toHaveLength(5);
  });

  test('respects the time window', () => {
    const clusters = clusterItems([item('a', 'Binance crypto heist linked to North Korea', 80), item('b', 'Binance crypto heist linked to North Korea', 1)]);
    expect(clusters).toHaveLength(2);
  });

  test('joins new reports onto an existing story seed and skips known URLs', () => {
    const seeds = [{ storyId: 'st-1', members: [item('known', 'UPI hits record 25 billion transactions in October', 6)] }];
    const clusters = clusterItems(
      [item('known', 'UPI hits record 25 billion transactions in October', 6), item('n', 'Festive spending drives record UPI transactions in October', 2)],
      seeds
    );
    expect(clusters).toHaveLength(1);
    expect(clusters[0].storyId).toBe('st-1');
    expect(clusters[0].items.map((i) => i.key)).toEqual(['n']);
  });

  test('tokens drop stop words and stem plurals', () => {
    expect(titleTokens('Apple launches the new iPhones in India')).toEqual(['apple', 'iphone']);
    const idf = new IdfModel(['a b', 'apple iphone', 'apple ipad']);
    expect(titleSimilarity('Apple iPhone', 'Apple iPhone', idf).score).toBe(1);
  });
});

// ---------------------------------------------------------------------------------------------
describe('story writer', () => {
  afterEach(() => {
    resetGeminiBudget();
    delete process.env.GEMINI_MAX_CALLS_PER_RUN;
    delete process.env.GEMINI_MIN_INTERVAL_MS;
  });

  test('valid JSON passes; unofficial / unseen advisory URLs are dropped', () => {
    const w = validateStoryJson(goodAiJson, writerInput(), 'm');
    expect(w.category).toBe('scams-security');
    expect(w.scam?.warningSigns).toHaveLength(2);
    expect(w.scam?.advisoryUrl).toBeNull(); // not present in the report
    expect(w.needsEnrichment).toBe(false);
  });

  test('advisory URL is kept when official and in the report', () => {
    const input = writerInput();
    input.sources[0].snippet += ' Advisory: https://www.cert-in.org.in/s2cMainServlet?pageid=PUBVLNOTES01';
    const w = validateStoryJson({ ...goodAiJson, scam: { ...goodAiJson.scam, advisoryUrl: 'https://www.cert-in.org.in/s2cMainServlet?pageid=PUBVLNOTES01' } }, input, 'm');
    expect(w.scam?.advisoryUrl).toContain('cert-in.org.in');
  });

  test('rejects missing fields, bad types and copied text', () => {
    expect(() => validateStoryJson({ ...goodAiJson, whatToDo: [] }, writerInput(), 'm')).toThrow(StoryValidationError);
    expect(() => validateStoryJson({ ...goodAiJson, headline: 42 }, writerInput(), 'm')).toThrow(StoryValidationError);
    expect(() => validateStoryJson({ ...goodAiJson, scam: null }, writerInput(), 'm')).toThrow(/scam details/);
    expect(() => validateStoryJson('nope', writerInput(), 'm')).toThrow(StoryValidationError);
    const copied = {
      ...goodAiJson,
      whatHappened:
        'Police in Chennai warned residents about a new scam in which fraudsters send SMS messages claiming a courier parcel is held.',
    };
    expect(() => validateStoryJson(copied, writerInput(), 'm')).toThrow(/copied/);
  });

  test('non-scam output gets scam: null and keeps its category; whatToDo capped at 3', () => {
    const w = validateStoryJson(
      { ...goodAiJson, isScam: false, scam: null, category: 'phones-gadgets', whatToDo: ['Do a', 'Do b', 'Do c', 'Do d'] },
      writerInput(),
      'm'
    );
    expect(w.scam).toBeNull();
    expect(w.category).toBe('phones-gadgets');
    expect(w.whatToDo).toHaveLength(3);
  });

  test('fallback fills every card field, low confidence, needs enrichment; scam template for scams', () => {
    const f = fallbackStory(writerInput());
    expect(f.confidence).toBe('low');
    expect(f.needsEnrichment).toBe(true);
    expect(f.category).toBe('scams-security');
    expect(f.scam?.ifTargeted.join(' ')).toContain('1930');
    for (const k of ['headline', 'whatHappened', 'affectsWho', 'whatItMeans'] as const) expect(f[k].length).toBeGreaterThan(10);
    expect(f.whatToDo.length).toBeGreaterThanOrEqual(1);
    expect(f.whatToDo.length).toBeLessThanOrEqual(3);
    // Fallback never copies the report body.
    expect(findCopiedRun(f.whatHappened, [writerInput().sources[0].snippet], 10)).toBeNull();
  });

  test('fallback for a non-scam phone story', () => {
    const f = fallbackStory(
      writerInput({
        categoryHint: 'phones-gadgets',
        sources: [{ sourceName: 'Gadgets 360', title: 'OnePlus 15 launched in India with Snapdragon chip - Gadgets 360', snippet: '', url: 'https://www.gadgets360.com/x', publishedAt: iso(1), official: false }],
      })
    );
    expect(f.category).toBe('phones-gadgets');
    expect(f.scam).toBeNull();
    expect(f.headline).toBe('OnePlus 15 launched in India with Snapdragon chip');
  });

  test('uses Gemini JSON when available, falls back on errors, and stops after 429', async () => {
    const ok = { ok: true, status: 200, json: async () => ({ candidates: [{ content: { parts: [{ text: JSON.stringify(goodAiJson) }] } }] }), text: async () => '' };
    const fetchFn = jest.fn().mockResolvedValueOnce(ok).mockResolvedValueOnce({ ok: false, status: 429, text: async () => 'quota', json: async () => ({}) });
    const writer = new StoryWriter({ apiKey: 'k', model: 'gemini-flash-lite-latest', fetchFn: fetchFn as any });
    const a = await writer.write(writerInput());
    expect(a?.aiModel).toBe('gemini-flash-lite-latest');
    expect(fetchFn.mock.calls[0][0]).toContain('gemini-flash-lite-latest:generateContent');
    const body = JSON.parse(fetchFn.mock.calls[0][1].body);
    expect(body.generationConfig.responseMimeType).toBe('application/json');
    const b = await writer.write(writerInput());
    expect(b?.aiModel).toBe('techdaily-fallback-v2');
    expect(writer.stats.rateLimited).toBe(true);
    expect(writer.aiAvailable()).toBe(false);
    const c = await writer.write(writerInput(), false);
    expect(c).toBeNull();
    expect(fetchFn).toHaveBeenCalledTimes(2);
  });

  test('respects GEMINI_MAX_CALLS_PER_RUN and retries once without responseSchema on schema 400', async () => {
    process.env.GEMINI_MAX_CALLS_PER_RUN = '1';
    const ok = { ok: true, status: 200, json: async () => ({ candidates: [{ content: { parts: [{ text: JSON.stringify(goodAiJson) }] } }] }), text: async () => '' };
    const bad = { ok: false, status: 400, text: async () => 'Invalid JSON payload: responseSchema unknown field', json: async () => ({}) };
    const fetchFn = jest.fn().mockResolvedValueOnce(bad).mockResolvedValueOnce(ok);
    const writer = new StoryWriter({ apiKey: 'k', fetchFn: fetchFn as any });
    const a = await writer.write(writerInput());
    expect(a?.needsEnrichment).toBe(false);
    expect(JSON.parse(fetchFn.mock.calls[1][1].body).generationConfig.responseSchema).toBeUndefined();
    const b = await writer.write(writerInput());
    expect(b?.needsEnrichment).toBe(true); // budget used up -> fallback
    expect(fetchFn).toHaveBeenCalledTimes(2);
  });

  test('default model is gemini-flash-lite-latest and GEMINI_MODEL overrides it', () => {
    expect(new StoryWriter({ apiKey: '' }).model).toBe('gemini-flash-lite-latest');
    process.env.GEMINI_MODEL = 'gemini-flash-latest';
    expect(new StoryWriter({ apiKey: '' }).model).toBe('gemini-flash-latest');
    delete process.env.GEMINI_MODEL;
  });
});

// ---------------------------------------------------------------------------------------------
describe('ranking and Today in 5', () => {
  test('more sources and fresher stories rank higher', () => {
    const a = story({ id: 'a', publishedAt: iso(1) });
    const b = story({ id: 'b', publishedAt: iso(20) });
    const c = story({ id: 'c', publishedAt: iso(1), sources: [...a.sources, { ...a.sources[0], name: 'Mint', url: 'https://www.livemint.com/x' }] });
    expect(storyScore(c, NOW)).toBeGreaterThan(storyScore(a, NOW));
    expect(rankStories([b, a, c], NOW).map((s) => s.id)).toEqual(['c', 'a', 'b']);
  });

  test('Today in 5 is diverse across categories', () => {
    const cats = ['money-fintech', 'money-fintech', 'money-fintech', 'ai', 'privacy', 'phones-gadgets', 'innovations'] as const;
    const stories = cats.map((c, i) => story({ id: `s${i}`, slug: `s-${i}`, category: c, publishedAt: iso(i) }));
    const t = pickTodayInFive(stories, NOW);
    expect(t.items).toHaveLength(5);
    expect(new Set(t.items.map((i) => i.category)).size).toBe(5);
    expect(t.date).toBe('2026-11-01');
  });
});

// ---------------------------------------------------------------------------------------------
describe('store conversion and cache', () => {
  test('round-trips through Firestore shape', () => {
    const s = story({ scam: { howItWorks: 'x'.repeat(30), warningSigns: ['a'], ifTargeted: ['b'], advisoryUrl: null } });
    const doc = storyToDoc(s) as any;
    expect(typeof doc.publishedAt.toDate).toBe('function');
    expect(doc.sourceCount).toBe(1);
    const back = docToStory(doc);
    expect(back).toEqual(s);
  });

  test('cache saves, loads and indexes URLs', () => {
    const file = path.join(fs.mkdtempSync(path.join(os.tmpdir(), 'td-')), 'c.json');
    const c = new StoryCache();
    c.upsert(story({ id: 'a', updatedAt: iso(3) }));
    c.upsert(story({ id: 'b', updatedAt: iso(1) }));
    c.save(file);
    const l = StoryCache.load(file);
    expect(l.stories.size).toBe(2);
    expect(l.maxUpdatedAt).toBe(iso(1));
    expect(l.urlIndex().get('https://economictimes.indiatimes.com/tech/a.cms')).toBe('a');
  });

  test('developing = low confidence or a single unconfirmed source', () => {
    expect(isDeveloping(story({ confidence: 'low' }))).toBe(true);
    expect(isDeveloping(story({ unconfirmed: true }))).toBe(true);
    expect(isDeveloping(story())).toBe(false);
  });
});

// ---------------------------------------------------------------------------------------------
describe('pipeline (offline, fixture feeds)', () => {
  const rss = (items: Array<[string, string, number, string?]>) => `<?xml version="1.0"?><rss version="2.0"><channel><title>x</title><link>https://x</link>
${items.map(([t, l, h, d]) => `<item><title><![CDATA[${t}]]></title><link>${l}</link><pubDate>${new Date(NOW - h * H).toUTCString()}</pubDate><description><![CDATA[${d ?? 'Some text about it.'}]]></description></item>`).join('\n')}
</channel></rss>`;

  const feeds = STORY_FEEDS.filter((f) => ['the-verge', 'the-hacker-news', 'et-tech', 'rbi-press'].includes(f.sourceId));
  const xml: Record<string, string> = {
    'https://www.theverge.com/rss/index.xml': rss([
      ['North Korea linked to massive Binance crypto heist', 'https://www.theverge.com/tech/1/north-korea-binance-heist', 2],
      ['Weekend deals: AirPods and MacBooks', 'https://www.theverge.com/deals/2/weekend-deals', 1],
      ['An old story', 'https://www.theverge.com/tech/3/old', 100],
    ]),
    'https://feeds.feedburner.com/TheHackersNews': rss([
      ["FBI links North Korea's TraderTraitor to record $6.43 billion Binance crypto heist", 'https://thehackernews.com/2026/11/fbi-binance.html', 3],
      ['Spoofed item', 'https://evil.example.com/x', 1],
    ]),
    'https://economictimes.indiatimes.com/tech/rssfeeds/13357270.cms': rss([
      ['Festive spending drives record UPI transactions in October', 'https://economictimes.indiatimes.com/tech/technology/upi-record/articleshow/1.cms', 4],
    ]),
    'https://www.rbi.org.in/pressreleases_rss.xml': rss([
      ['RBI cautions public against fake loan apps', 'https://www.rbi.org.in/scripts/BS_PressReleaseDisplay.aspx?prid=1', 5],
      ['Money market operations as on October 30', 'https://www.rbi.org.in/scripts/BS_PressReleaseDisplay.aspx?prid=2', 5],
    ]),
  };
  const fetchText = async (url: string) => {
    if (!xml[url]) throw new Error('404');
    return xml[url];
  };

  test('itemsFromFeed validates domains, age, low-value and include patterns', () => {
    const verge = itemsFromFeed(feeds.find((f) => f.sourceId === 'the-verge')!, xml['https://www.theverge.com/rss/index.xml'], NOW, 48);
    expect(verge.items.map((i) => i.title)).toEqual(['North Korea linked to massive Binance crypto heist']);
    const thn = itemsFromFeed(feeds.find((f) => f.sourceId === 'the-hacker-news')!, xml['https://feeds.feedburner.com/TheHackersNews'], NOW, 48);
    expect(thn.items).toHaveLength(1);
    const rbi = itemsFromFeed(feeds.find((f) => f.sourceId === 'rbi-press')!, xml['https://www.rbi.org.in/pressreleases_rss.xml'], NOW, 48);
    expect(rbi.items.map((i) => i.title)).toEqual(['RBI cautions public against fake loan apps']);
    expect(rbi.items[0].official).toBe(true);
  });

  test('dry run: clusters, writes fallback cards, picks Today in 5, re-runs are idempotent', async () => {
    const cache = new StoryCache();
    const writer = new StoryWriter({ apiKey: '' });
    const r = await runStoryPipeline({ dryRun: true, feeds, fetchText, now: NOW }, { cache, writer });
    expect(r.feeds.every((f) => f.status === 'ok')).toBe(true);
    expect(r.itemsFetched).toBe(4);
    expect(r.storiesCreated).toBe(3);
    const heist = r.changed.find((s) => s.sources.length === 2)!;
    expect(heist.category).toBe('scams-security');
    expect(heist.sources.map((s) => s.name).sort()).toEqual(['The Hacker News', 'The Verge']);
    expect(heist.publishedAt).toBe(new Date(NOW - 3 * H).toISOString());
    expect(heist.slug).toMatch(/^[a-z0-9-]+$/);
    for (const s of r.changed) {
      expect(s.developing).toBe(true); // fallback => low confidence
      expect(s.needsEnrichment).toBe(true);
      expect(s.whatToDo.length).toBeGreaterThan(0);
    }
    const rbi = r.changed.find((s) => s.sources[0].sourceId === 'rbi-press')!;
    expect(rbi.region).toBe('IN');
    expect(r.today.items.length).toBe(3);

    const again = await runStoryPipeline({ dryRun: true, feeds, fetchText, now: NOW + H }, { cache, writer });
    expect(again.storiesCreated).toBe(0);
    expect(again.itemsNew).toBe(0);
  });

  test('re-enriches fallback stories with AI in a later run', async () => {
    const cache = new StoryCache();
    await runStoryPipeline({ dryRun: true, feeds, fetchText, now: NOW }, { cache, writer: new StoryWriter({ apiKey: '' }) });
    const aiJson = { ...goodAiJson, isScam: false, scam: null, category: 'money-fintech', headline: 'A simple AI headline here' };
    const fetchFn = jest.fn().mockResolvedValue({ ok: true, status: 200, json: async () => ({ candidates: [{ content: { parts: [{ text: JSON.stringify(aiJson) }] } }] }), text: async () => '' });
    const r = await runStoryPipeline({ dryRun: true, feeds, fetchText, now: NOW + H }, { cache, writer: new StoryWriter({ apiKey: 'k', fetchFn: fetchFn as any }) });
    expect(r.storiesEnriched).toBe(3);
    const s = cache.all()[0];
    expect(s.needsEnrichment).toBe(false);
    expect(s.confidence).toBe('medium');
    expect(s.enrichAttempts).toBe(1);
    // slug never changes after enrichment
    expect(cache.all().every((x) => !x.slug.startsWith('a-simple-ai-headline'))).toBe(true);
    resetGeminiBudget();
  });
});

// ---------------------------------------------------------------------------------------------
describe('renderer', () => {
  const evil = story({
    id: 'st-evil',
    slug: 'evil-story-abc123',
    headline: 'Hackers use <script>alert("x")</script> & "quotes" in fake UPI app',
    category: 'scams-security',
    developing: true,
    confidence: 'low',
    scam: {
      howItWorks: 'They send a link to a fake app that copies your UPI PIN.',
      warningSigns: ['Unknown APK files', 'Urgent messages'],
      ifTargeted: ['Uninstall the app', 'Call 1930'],
      advisoryUrl: 'https://www.cert-in.org.in/advisory',
    },
  });

  test('story page has title, description, canonical, OG/Twitter tags, escaping and all card sections', () => {
    const html = renderStoryPage(evil, ctx, [story({ id: 'r1', slug: 'related-1' })]);
    expect(html).toContain('<link rel="canonical" href="https://techdaily-prod.web.app/story/evil-story-abc123/">');
    expect(html).toContain('<meta property="og:type" content="article">');
    expect(html).toContain('<meta property="og:image" content="https://techdaily-prod.web.app/og/scams-security.png">');
    expect(html).toContain('<meta name="twitter:card" content="summary_large_image">');
    expect(html).toMatch(/<meta name="description" content="[^"<>]+">/);
    expect(html).not.toContain('<script>alert');
    expect(html).toContain('&lt;script&gt;alert(&quot;x&quot;)&lt;/script&gt; &amp; &quot;quotes&quot;');
    for (const section of ['What happened', 'Does it affect me?', 'What to do', 'How the trick works', 'Warning signs', 'What to do if you’re targeted', 'What this means for you', 'Read the original']) {
      expect(html).toContain(section);
    }
    expect(html).toContain('Developing');
    expect(html).toContain('Read the official advisory');
    expect(html).toContain('href="https://wa.me/?text=');
    expect(html).toContain('/app/story/evil-story-abc123');
    expect(html).toContain('href="https://economictimes.indiatimes.com/tech/st-evil.cms"');
    expect(html).toContain('<time datetime=');
    expect(html).toContain('class="signup"');
    // WhatsApp share is the first share action
    expect(html.indexOf('Share on WhatsApp')).toBeLessThan(html.indexOf('Telegram'));
  });

  test('NewsArticle JSON-LD is valid JSON with required fields', () => {
    const html = renderStoryPage(evil, ctx);
    const m = html.match(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/);
    expect(m).toBeTruthy();
    const ld = JSON.parse(m![1]);
    expect(ld['@type']).toBe('NewsArticle');
    expect(ld.headline).toBe(evil.headline);
    expect(ld.datePublished).toBe(evil.publishedAt);
    expect(ld.publisher.logo.url).toMatch(/^https:/);
    expect(ld.isBasedOn).toEqual([evil.sources[0].url]);
    expect((newsArticleJsonLd(evil, ctx) as any).mainEntityOfPage['@id']).toBe('https://techdaily-prod.web.app/story/evil-story-abc123/');
  });

  test('whatsapp link encodes headline + story url', () => {
    const u = whatsappUrl('A & B', 'https://techdaily-prod.web.app/story/a/');
    expect(u).toBe('https://wa.me/?text=A%20%26%20B%0A%0Ahttps%3A%2F%2Ftechdaily-prod.web.app%2Fstory%2Fa%2F');
  });

  test('category page and index injection', () => {
    const cat = renderCategoryPage('money-fintech', [story()], ctx);
    expect(cat).toContain('<h1>Money &amp; Fintech</h1>');
    expect(cat).toContain('aria-current="page"');
    const today = pickTodayInFive([story()], NOW);
    const block = renderIndexSeoBlock(today, [story()], ctx, new Map([[story().slug, story()]]));
    const base = '<html><head><meta name="description" content="old"></head><body><!--TD-SEO--><!--/TD-SEO--><script src="flutter_bootstrap.js"></script></body></html>';
    const once = injectIntoIndex(base, block, today);
    const twice = injectIntoIndex(once, block, today);
    expect(twice).toBe(once);
    expect(once).toContain('Today in 5 stories');
    expect(once).toContain('<meta name="description" content="Today in 5: UPI sets a new monthly record">');
    expect(once.match(/id="td-seo"/g)).toHaveLength(1);
    const noMarker = injectIntoIndex('<html><body class="x"><p>a</p></body></html>', block, today);
    expect(noMarker).toContain('<body class="x">\n<!--TD-SEO-->');
  });

  test('sitemap and RSS are well-formed XML with escaped content', () => {
    const items = [evil, story()];
    const sm = renderSitemap(items, ctx);
    expect(XMLValidator.validate(sm)).toBe(true);
    const parsed = new XMLParser().parse(sm);
    expect(parsed.urlset.url.length).toBe(1 + 8 + 2);
    expect(sm).toContain('<loc>https://techdaily-prod.web.app/story/evil-story-abc123/</loc>');
    const rss = renderRss(items, ctx);
    expect(XMLValidator.validate(rss)).toBe(true);
    const r = new XMLParser().parse(rss);
    expect(r.rss.channel.item).toHaveLength(2);
    expect(rss).not.toContain('<script>');
  });

  test('renderSite writes every file, skips invalid stories and is re-runnable', () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'td-web-'));
    fs.writeFileSync(path.join(dir, 'index.html'), '<html><head><meta name="description" content="x"></head><body><!--TD-SEO--><!--/TD-SEO--></body></html>');
    const bad = story({ id: 'bad', slug: '../../etc', headline: 'Bad slug' });
    const res = renderSite({ outDir: dir, stories: [evil, story(), bad], now: NOW });
    expect(res.storyPages).toBe(2);
    for (const f of ['story/evil-story-abc123/index.html', 'c/scams-security/index.html', 'c/privacy/index.html', 'sitemap.xml', 'rss.xml', 'robots.txt', 'data/feed.json']) {
      expect(fs.existsSync(path.join(dir, f))).toBe(true);
    }
    expect(fs.readFileSync(path.join(dir, 'robots.txt'), 'utf8')).toContain('Sitemap: https://techdaily-prod.web.app/sitemap.xml');
    const feed = JSON.parse(fs.readFileSync(path.join(dir, 'data/feed.json'), 'utf8'));
    expect(feed.stories).toHaveLength(2);
    expect(feed.stories[0]).not.toHaveProperty('needsEnrichment');
    expect(feed.today.items.length).toBe(2);
    expect(publicStory(evil).slug).toBe('evil-story-abc123');
    renderSite({ outDir: dir, stories: [story()], now: NOW });
    expect(fs.existsSync(path.join(dir, 'story/evil-story-abc123/index.html'))).toBe(false);
    expect(() => renderSite({ outDir: path.join(dir, 'missing'), stories: [] })).toThrow(/flutter build web/);
  });
});

// ---------------------------------------------------------------------------------------------
import { articleToItem, migrateArticles } from '../src/stories/migrate';

describe('migration articles -> stories', () => {
  const art = (id: string, title: string, url: string, hoursAgo: number, extra: Record<string, any> = {}) => ({
    id,
    data: () => ({ title, sourceUrl: url, sourceName: 'X', sourceId: 'the-verge', publishedAt: { toDate: () => new Date(NOW - hoursAgo * H) }, summary: 'A summary.', status: 'published', category: 'Smartphones', ...extra }),
  });
  const fakeDb = (docs: any[]) =>
    ({
      collection: (name: string) => {
        if (name !== 'articles') throw new Error('unexpected write/read: ' + name);
        const q: any = { orderBy: () => q, limit: () => q, get: async () => ({ size: docs.length, docs }) };
        return q;
      },
    }) as any;

  test('articleToItem maps v1 fields and rejects junk', () => {
    const i = articleToItem(art('a', 'Pixel 11 launched in India', 'https://www.theverge.com/a/pixel', 2).data())!;
    expect(i.sourceName).toBe('The Verge');
    expect(i.defaultCategory).toBe('phones-gadgets');
    expect(articleToItem({ title: 'x', sourceUrl: 'nope' })).toBeNull();
    expect(articleToItem(art('b', 'Best phones under Rs 20,000', 'https://www.theverge.com/b', 1).data())).toBeNull();
  });

  test('dry run clusters into fallback stories without writing, and skips URLs already migrated', async () => {
    const docs = [
      art('a', 'North Korea linked to massive Binance crypto heist', 'https://www.theverge.com/a/heist', 2),
      art('b', 'FBI links North Korea to record Binance crypto heist', 'https://thehackernews.com/b/heist', 3, { sourceId: 'the-hacker-news' }),
      art('c', 'Pixel 11 launched in India', 'https://www.theverge.com/c/pixel', 4),
    ];
    const cache = new StoryCache();
    const r = await migrateArticles(fakeDb(docs), cache, { dryRun: true, now: NOW });
    expect(r.articlesRead).toBe(3);
    expect(r.storiesCreated).toBe(2);
    expect(r.firestoreWrites).toBe(0);
    expect(r.changed.every((s) => s.needsEnrichment && s.confidence === 'low')).toBe(true);
    const again = await migrateArticles(fakeDb(docs), cache, { dryRun: true, now: NOW });
    expect(again.skippedKnown).toBe(3);
    expect(again.storiesCreated).toBe(0);
  });
});
