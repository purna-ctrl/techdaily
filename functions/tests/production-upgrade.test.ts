import { ImageExtractor } from '../src/pipeline/image-extractor';
import { FeedParser } from '../src/pipeline/feed-parser';
import { UrlNormalizer } from '../src/pipeline/url-normalizer';
import { DuplicateDetector, TitleSimilarity } from '../src/pipeline/duplicate-detector';
import { IngestionEngine, detectBreakingByRules } from '../src/pipeline/ingestion-engine';
import { DomainValidator } from '../src/pipeline/domain-validator';
import { TRUSTED_SOURCE_REGISTRY, TrustedSourceConfig, getSourceRegion } from '../src/config/sources';
import { AiOutputValidator, RuleBasedAiSummarizer } from '../src/ai';
import { verifyAdmin } from '../src/admin/verify-admin';
import { AdminService } from '../src/admin/admin-service';
import { PushService } from '../src/notifications/push-service';
import { DailyBriefGenerator } from '../src/pipeline/daily-brief-generator';
import {
  ArticleQaService,
  MemoryRateLimiter,
  buildGroundedFallbackAnswer,
  createAskArticleHandler,
  ArticleForQa,
} from '../src/ask/ask-article';

function mockRes() {
  const res: any = { statusCode: 200, body: undefined, headers: {} };
  res.status = (c: number) => {
    res.statusCode = c;
    return res;
  };
  res.json = (b: any) => {
    res.body = b;
    return res;
  };
  res.send = (b: any) => {
    res.body = b;
    return res;
  };
  res.set = (k: string, v: string) => {
    res.headers[k] = v;
    return res;
  };
  return res;
}

/** Minimal in-memory Firestore stand-in that records writes. */
function fakeDb() {
  const writes: Record<string, Record<string, any>> = {};
  const db: any = {
    writes,
    collection: (col: string) => ({
      doc: (id: string) => ({
        get: async () => ({ exists: Boolean(writes[`${col}/${id}`]), data: () => writes[`${col}/${id}`] }),
        set: async (data: any) => {
          writes[`${col}/${id}`] = { ...(writes[`${col}/${id}`] || {}), ...data };
        },
      }),
      where: () => ({
        select: () => ({ limit: () => ({ get: async () => ({ docs: [] }) }) }),
      }),
    }),
  };
  return db;
}

const verge: TrustedSourceConfig = TRUSTED_SOURCE_REGISTRY.find((s) => s.sourceId === 'the-verge')!;
const inc42: TrustedSourceConfig = TRUSTED_SOURCE_REGISTRY.find((s) => s.sourceId === 'inc42')!;

describe('Image extraction', () => {
  test('prefers media:content, decodes entities, requires https', () => {
    const xml = `<?xml version="1.0"?><rss xmlns:media="http://search.yahoo.com/mrss/" version="2.0"><channel>
      <link>https://example.com/</link>
      <item><title>Post One Title Here</title><link>https://www.theverge.com/tech/1/post-one</link>
        <media:content medium="image" url="https://cdn.example.com/a.jpg?w=1200&amp;q=90"/>
        <media:thumbnail url="https://cdn.example.com/thumb.jpg"/>
      </item>
      <item><title>Post Two Title Here</title><link>https://www.theverge.com/tech/2/post-two</link>
        <enclosure url="https://cdn.example.com/b.png" type="image/png" length="1"/>
      </item>
      <item><title>Post Three Title Here</title><link>https://www.theverge.com/tech/3/post-three</link>
        <description><![CDATA[<p><img src="https://example.com/pixel.gif" width="1" height="1"><img src="https://cdn.example.com/c.webp" width="800"></p>]]></description>
      </item>
      <item><title>Post Four Title Here</title><link>https://www.theverge.com/tech/4/post-four</link>
        <media:content url="http://insecure.example.com/d.jpg" medium="image"/>
        <enclosure url="https://cdn.example.com/e.mp3" type="audio/mpeg"/>
      </item>
    </channel></rss>`;
    const items = FeedParser.parse(xml);
    expect(items.map((i) => i.imageUrl)).toEqual([
      'https://cdn.example.com/a.jpg?w=1200&q=90',
      'https://cdn.example.com/b.png',
      'https://cdn.example.com/c.webp',
      undefined,
    ]);
  });

  test('Atom: exact alternate link (not self/hub) and first <img> from html content', () => {
    const xml = `<?xml version="1.0"?><feed xmlns="http://www.w3.org/2005/Atom">
      <link rel="self" href="https://www.theverge.com/rss/index.xml"/>
      <link rel="alternate" href="https://www.theverge.com/"/>
      <entry>
        <title type="html">Halloween &amp; YouTube horror</title>
        <link rel="replies" href="https://www.theverge.com/x#comments"/>
        <link rel="alternate" type="text/html" href="https://www.theverge.com/entertainment/1024096/halloween-spirit-youtube-horror"/>
        <content type="html">&lt;figure&gt;&lt;img alt="x" src="https://platform.theverge.com/wp-content/uploads/a.jpg?quality=90&amp;#038;strip=all" /&gt;&lt;/figure&gt;&lt;p&gt;Body text here.&lt;/p&gt;</content>
        <published>2026-10-31T12:00:00Z</published>
      </entry>
    </feed>`;
    const items = FeedParser.parse(xml);
    expect(items).toHaveLength(1);
    expect(items[0].link).toBe('https://www.theverge.com/entertainment/1024096/halloween-spirit-youtube-horror');
    expect(items[0].description).toContain('Body text');
  });

  test('drops site-wide generic share images (no stock/default photos)', () => {
    expect(ImageExtractor.validateImageUrl('https://nvidianews.nvidia.com/media/sites/219/images/social-image.jpg')).toBeUndefined();
    expect(ImageExtractor.validateImageUrl('https://about.fb.com/wp-content/uploads/2021/10/meta-social-16x9-1.jpg?w=1200')).toBeUndefined();
    expect(ImageExtractor.validateImageUrl('https://d2908q01vomqb2.cloudfront.net/x/AWS-WIR-default.png')).toBeUndefined();
    expect(ImageExtractor.validateImageUrl('https://cdn.arstechnica.net/wp-content/uploads/2026/10/image-4.jpeg')).toBe('https://cdn.arstechnica.net/wp-content/uploads/2026/10/image-4.jpeg');
  });

  test('extractOgImage reads og:image and resolves relative URLs', () => {
    const html = `<html><head><meta property="og:image" content="/images/hero.jpg"><meta name="twitter:image" content="https://x.com/t.jpg"></head></html>`;
    expect(ImageExtractor.extractOgImage(html, 'https://openai.com/index/some-post')).toBe('https://openai.com/images/hero.jpg');
    expect(ImageExtractor.extractOgImage('<meta content="http://a.com/x.jpg" property="og:image">')).toBeUndefined();
  });

  test('fetchOgImage stops at </head>, respects content-type and never throws', async () => {
    const page = `<html><head><meta property="og:image" content="https://cdn.example.com/og.jpg"></head><body>${'x'.repeat(10000)}</body></html>`;
    const okFetch: any = async () => ({ ok: true, url: 'https://techcrunch.com/2026/10/31/post', headers: { get: () => 'text/html' }, text: async () => page });
    expect(await ImageExtractor.fetchOgImage('https://techcrunch.com/2026/10/31/post', { fetchFn: okFetch })).toBe('https://cdn.example.com/og.jpg');

    const throwingFetch: any = async () => {
      throw new Error('network down');
    };
    expect(await ImageExtractor.fetchOgImage('https://techcrunch.com/x', { fetchFn: throwingFetch })).toBeUndefined();

    const pdfFetch: any = async () => ({ ok: true, headers: { get: () => 'application/pdf' }, text: async () => page });
    expect(await ImageExtractor.fetchOgImage('https://techcrunch.com/x', { fetchFn: pdfFetch })).toBeUndefined();
  });

  test('ingestion falls back to og:image when the feed has no image, and stores null when none', async () => {
    const rss = `<?xml version="1.0"?><rss version="2.0"><channel><link>https://www.theverge.com/</link>
      <item><title>Story with og image only</title><link>https://www.theverge.com/news/111/og-story</link><description>Some description text for the story.</description><pubDate>${new Date().toUTCString()}</pubDate></item>
      <item><title>Completely different story without any image</title><link>https://www.theverge.com/news/222/no-image</link><description>Another description that is long enough.</description><pubDate>${new Date().toUTCString()}</pubDate></item>
    </channel></rss>`;
    const pageFetch: any = async (url: string) => ({
      ok: true,
      headers: { get: () => 'text/html' },
      text: async () => (url.includes('og-story') ? '<head><meta property="og:image" content="https://cdn.vox-cdn.com/og.jpg"></head>' : '<head></head>'),
    });
    const db = fakeDb();
    const engine = new IngestionEngine(db, undefined, async () => rss, new RuleBasedAiSummarizer(), new AdminService(), {
      pageFetch,
      pushService: new PushService({ send: async () => 'id' }),
    });
    const stats = await engine.processSource(verge, false);
    expect(stats.accepted).toBe(2);
    expect(stats.imagesFromOgTag).toBe(1);
    const docs = Object.entries(db.writes).filter(([k]) => k.startsWith('articles/')).map(([, v]) => v as any);
    const og = docs.find((d) => d.sourceUrl.includes('og-story'));
    const none = docs.find((d) => d.sourceUrl.includes('no-image'));
    expect(og.imageUrl).toBe('https://cdn.vox-cdn.com/og.jpg');
    expect(og.imageSource).toBe('og');
    expect(none.imageUrl).toBeNull();
  });
});

describe('Exact post URLs, never hubs', () => {
  test('isHubUrl detects homepages and section hubs', () => {
    expect(UrlNormalizer.isHubUrl('https://github.blog')).toBe(true);
    expect(UrlNormalizer.isHubUrl('https://nvidianews.nvidia.com/')).toBe(true);
    expect(UrlNormalizer.isHubUrl('https://blog.google/technology/ai/')).toBe(true);
    expect(UrlNormalizer.isHubUrl('https://www.reuters.com/technology')).toBe(true);
    expect(UrlNormalizer.isHubUrl('https://aws.amazon.com/blogs/aws/')).toBe(true);
    expect(UrlNormalizer.isHubUrl('https://techcrunch.com/2026/10/31/data-centers-are-now-a-midterm-issue/')).toBe(false);
    expect(UrlNormalizer.isHubUrl('https://openai.com/index/helping-websites-express-ai-training-preferences')).toBe(false);
    expect(UrlNormalizer.isHubUrl('https://pib.gov.in/PressReleaseIframePage.aspx?PRID=2331152')).toBe(false);
    expect(UrlNormalizer.isHubUrl('https://example.com/?p=123')).toBe(false);
  });

  test('ingestion stores the item link verbatim in sourceUrl and rejects hub links; region is tagged', async () => {
    const rss = `<?xml version="1.0"?><rss version="2.0"><channel><link>https://inc42.com/</link>
      <item><title>Netflix flips its India script</title><link>https://inc42.com/features/netflix-flips-its-india-script/</link><description>Netflix is changing strategy in India with new plans.</description></item>
      <item><title>Homepage masquerading as an item</title><link>https://inc42.com/</link><description>Should be rejected because it is a hub.</description></item>
    </channel></rss>`;
    const db = fakeDb();
    const engine = new IngestionEngine(db, undefined, async () => rss, new RuleBasedAiSummarizer(), new AdminService(), { pageFetch: null });
    const stats = await engine.processSource(inc42, false);
    expect(stats.accepted).toBe(1);
    expect(stats.rejected).toBe(1);
    const doc = Object.entries(db.writes).find(([k]) => k.startsWith('articles/'))![1] as any;
    expect(doc.sourceUrl).toBe('https://inc42.com/features/netflix-flips-its-india-script/');
    expect(doc.region).toBe('IN');
    expect(doc.id).toBe(UrlNormalizer.generateArticleId(UrlNormalizer.canonicalize(doc.sourceUrl)));
    // grounding text is stored privately for askArticle
    expect(db.writes[`articleSources/${doc.id}`].text).toContain('Netflix');
  });
});

describe('Dedupe', () => {
  test('stable id ignores tracking params and fragments', () => {
    const a = UrlNormalizer.generateArticleId(UrlNormalizer.canonicalize('https://techcrunch.com/2026/10/31/post/?utm_source=rss#top'));
    const b = UrlNormalizer.generateArticleId(UrlNormalizer.canonicalize('https://TechCrunch.com/2026/10/31/post'));
    expect(a).toBe(b);
  });

  test('title similarity scores near-identical titles high and unrelated titles low', () => {
    expect(TitleSimilarity.similarity('OpenAI launches GPT-6 for developers', 'OpenAI Launches GPT‑6 for Developers!')).toBeGreaterThanOrEqual(0.8);
    expect(TitleSimilarity.similarity('Apple unveils new iPad Pro with M5 chip', 'Apple unveils the new iPad Pro with M5 chip')).toBeGreaterThanOrEqual(0.8);
    expect(TitleSimilarity.similarity('Apple unveils new iPad Pro', 'NASA delays Artemis III launch')).toBeLessThan(0.3);
  });

  test('near-duplicate titles within 48h are skipped, but not outside the window', async () => {
    const d = new DuplicateDetector();
    const now = new Date('2026-11-01T00:00:00Z');
    d.recordSeen('art-1', 'fp1', 'Google releases Gemini 3 Ultra model to developers', now);
    expect(await d.isNearDuplicateTitle('Google releases Gemini 3 Ultra model to developers.', new Date('2026-11-01T10:00:00Z'))).toBe(true);
    expect(await d.isNearDuplicateTitle('Google releases Gemini 3 Ultra model to developers', new Date('2026-11-04T00:00:00Z'))).toBe(false);
    expect(await d.isNearDuplicateTitle('Microsoft ships Windows 12 preview', new Date('2026-11-01T10:00:00Z'))).toBe(false);
  });

  test('ingestion counts a syndicated copy under a different URL as a near duplicate', async () => {
    const pub = new Date().toUTCString();
    const rss = `<?xml version="1.0"?><rss version="2.0"><channel>
      <item><title>Inc42 exclusive: Zepto raises $500M in new round</title><link>https://inc42.com/buzz/zepto-raises-500m/</link><description>Zepto has raised a large new funding round.</description><pubDate>${pub}</pubDate></item>
      <item><title>Zepto raises $500M in new funding round, Inc42 exclusive</title><link>https://inc42.com/features/zepto-raises-500m-round/</link><description>Zepto has raised a large new funding round.</description><pubDate>${pub}</pubDate></item>
    </channel></rss>`;
    const engine = new IngestionEngine(undefined, undefined, async () => rss, new RuleBasedAiSummarizer());
    const stats = await engine.processSource(inc42, true);
    expect(stats.accepted).toBe(1);
    expect(stats.duplicates).toBe(1);
    expect(stats.nearDuplicates).toBe(1);
  });
});

describe('Sources & domain validation', () => {
  test('new sources are registered with regions and validate their own post URLs', () => {
    const ids = TRUSTED_SOURCE_REGISTRY.map((s) => s.sourceId);
    for (const id of ['the-verge', 'techcrunch', 'ars-technica', 'wired', 'openai-news', 'inc42', 'yourstory']) {
      expect(ids).toContain(id);
    }
    const samples: Record<string, string> = {
      'the-verge': 'https://www.theverge.com/entertainment/1024096/halloween',
      techcrunch: 'https://techcrunch.com/2026/10/31/data-centers/',
      'ars-technica': 'https://arstechnica.com/science/2026/10/seabirds/',
      wired: 'https://www.wired.com/story/kernel-panic/',
      'openai-news': 'https://openai.com/index/helping-websites',
      inc42: 'https://inc42.com/features/netflix/',
      yourstory: 'https://yourstory.com/2026/10/techsparks-2026',
    };
    for (const [id, url] of Object.entries(samples)) {
      const src = TRUSTED_SOURCE_REGISTRY.find((s) => s.sourceId === id)!;
      expect(DomainValidator.validate(url, src).isValid).toBe(true);
      expect(DomainValidator.validate(url).isValid).toBe(true);
    }
    expect(getSourceRegion(inc42)).toBe('IN');
    expect(getSourceRegion(TRUSTED_SOURCE_REGISTRY.find((s) => s.sourceId === 'yourstory')!)).toBe('IN');
    expect(getSourceRegion(verge)).toBe('GLOBAL');
    expect(DomainValidator.validate('https://theverge.com.evil.io/x', verge).isValid).toBe(false);
  });
});

describe('AI output translations', () => {
  const base = {
    summary: 'Company X released a product today. It ships next month.',
    whatHappened: 'Company X released a product.',
    whyItMatters: 'It changes how developers build apps.',
    simpleExplanation: 'A company made a new tool for app makers.',
    keyPoints: ['Point one here', 'Point two here', 'Point three here'],
    category: 'Software',
  };
  test('keeps valid translations and priority', () => {
    const out = AiOutputValidator.validate(
      { ...base, simpleExplanationTranslations: { te: 'ఒక కంపెనీ కొత్త సాధనం', ta: 'ஒரு நிறுவனம் புதிய கருவி', hi: 'एक कंपनी ने नया टूल बनाया' }, priority: 'High' },
      { model: 'gemini-2.5-flash' }
    );
    expect(out.simpleExplanationTranslations).toEqual({
      te: 'ఒక కంపెనీ కొత్త సాధనం',
      ta: 'ஒரு நிறுவனம் புதிய கருவி',
      hi: 'एक कंपनी ने नया टूल बनाया',
    });
    expect(out.priority).toBe('high');
  });
  test('tolerates missing or malformed translations', () => {
    expect(AiOutputValidator.validate(base, { model: 'm' }).simpleExplanationTranslations).toBeUndefined();
    const partial = AiOutputValidator.validate({ ...base, simpleExplanationTranslations: { te: 42, hi: 'हिंदी में सरल व्याख्या' } }, { model: 'm' });
    expect(partial.simpleExplanationTranslations).toEqual({ hi: 'हिंदी में सरल व्याख्या' });
    expect(AiOutputValidator.validate({ ...base, simpleExplanationTranslations: 'bad' }, { model: 'm' }).simpleExplanationTranslations).toBeUndefined();
  });
});

describe('askArticle', () => {
  const article: ArticleForQa = {
    id: 'art-abc',
    title: 'NVIDIA announces Rubin GPUs',
    summary: 'NVIDIA announced its Rubin GPU platform at GTC. The chips ship in 2027.',
    whatHappened: 'NVIDIA unveiled the Rubin GPU architecture for data centers.',
    whyItMatters: 'Rubin targets large AI training clusters and could lower training costs.',
    simpleExplanation: 'NVIDIA made faster chips for AI computers.',
    keyPoints: ['Rubin ships in 2027', 'Targets data centers', 'Announced at GTC'],
  };

  test('grounded fallback answers only from article sentences', () => {
    const ans = buildGroundedFallbackAnswer(article, 'When do the Rubin chips ship?');
    expect(ans).toContain('2027');
    expect(ans.startsWith('Based on the article')).toBe(true);
    const none = buildGroundedFallbackAnswer(article, 'What is the stock price of Intel?');
    expect(none).toContain("doesn't directly address");
    expect(none).toContain('NVIDIA announced its Rubin GPU platform');
  });

  test('without a key, the service uses the fallback', async () => {
    const r = await new ArticleQaService(undefined).answer(article, 'Why does this matter for training costs?');
    expect(r.grounded).toBe('fallback');
    expect(r.answer).toContain('lower training costs');
  });

  test('with a key, Gemini answer is returned; on Gemini failure it falls back', async () => {
    const okFetch: any = async (_url: string, init: any) => {
      const body = JSON.parse(init.body);
      expect(body.contents[0].parts[0].text).toContain('NVIDIA unveiled the Rubin GPU');
      expect(init.headers['x-goog-api-key']).toBe('k');
      return { ok: true, json: async () => ({ candidates: [{ content: { parts: [{ text: 'They ship in 2027.' }] } }] }) };
    };
    expect(await new ArticleQaService('k', 'gemini-2.5-flash', okFetch).answer(article, 'When?')).toEqual({ answer: 'They ship in 2027.', grounded: 'gemini' });
    const badFetch: any = async () => ({ ok: false, status: 500 });
    const r = await new ArticleQaService('k', 'gemini-2.5-flash', badFetch).answer(article, 'When do they ship?');
    expect(r.grounded).toBe('fallback');
  });

  test('handler validates input, enforces 500-char cap and 20/hour rate limit', async () => {
    const handler = createAskArticleHandler({
      loadArticle: async (id) => (id === 'art-abc' ? article : null),
      rateLimiter: new MemoryRateLimiter(20),
      qa: new ArticleQaService(undefined),
    });
    const req = (body: any, ip = '1.2.3.4') => ({ method: 'POST', body, headers: { 'x-forwarded-for': ip } });

    let res = mockRes();
    await handler({ method: 'GET', headers: {} }, res);
    expect(res.statusCode).toBe(405);

    res = mockRes();
    await handler(req({ articleId: 'art-abc', question: 'x'.repeat(501) }), res);
    expect(res.statusCode).toBe(400);

    res = mockRes();
    await handler(req({ articleId: 'missing', question: 'What?' }, '9.9.9.9'), res);
    expect(res.statusCode).toBe(404);

    res = mockRes();
    await handler(req({ articleId: 'art-abc', question: 'When do the Rubin chips ship?' }, '5.5.5.5'), res);
    expect(res.statusCode).toBe(200);
    expect(res.body.answer).toContain('2027');
    expect(res.body.grounded).toBe('fallback');

    for (let i = 0; i < 19; i++) await handler(req({ articleId: 'art-abc', question: 'Q?' }, '7.7.7.7'), mockRes());
    res = mockRes();
    await handler(req({ articleId: 'art-abc', question: 'Q?' }, '7.7.7.7'), res);
    expect(res.statusCode).toBe(200); // 20th allowed
    res = mockRes();
    await handler(req({ articleId: 'art-abc', question: 'Q?' }, '7.7.7.7'), res);
    expect(res.statusCode).toBe(429); // 21st blocked
  });
});

describe('verifyAdmin', () => {
  test('DENIES every request when ADMIN_SECRET is not configured', () => {
    for (const secret of [undefined, '', '   ']) {
      const res = mockRes();
      expect(verifyAdmin({ headers: { authorization: 'Bearer anything' } }, res, secret)).toBe(false);
      expect(res.statusCode).toBe(403);
    }
  });
  test('rejects wrong token and accepts the right one', () => {
    let res = mockRes();
    expect(verifyAdmin({ headers: { authorization: 'Bearer nope' } }, res, 's3cret')).toBe(false);
    expect(res.statusCode).toBe(401);
    res = mockRes();
    expect(verifyAdmin({ headers: {} }, res, 's3cret')).toBe(false);
    res = mockRes();
    expect(verifyAdmin({ headers: { authorization: 'Bearer s3cret' } }, res, 's3cret')).toBe(true);
  });
});

describe('Push notifications & breaking', () => {
  test('PushService never throws when messaging fails', async () => {
    const svc = new PushService({ send: async () => { throw new Error('FCM down'); } });
    await expect(svc.sendToTopic('breaking', { title: 't', body: 'b' })).resolves.toBeNull();
  });

  test('fresh breaking article triggers a push to topic "breaking"; ingestion survives push failure', async () => {
    const sent: any[] = [];
    const rss = `<?xml version="1.0"?><rss version="2.0"><channel>
      <item><title>Breaking: zero-day actively exploited in popular VPN</title><link>https://www.theverge.com/security/9/vpn-zero-day</link><description>Attackers are exploiting a flaw right now in a popular VPN.</description><pubDate>${new Date().toUTCString()}</pubDate></item>
    </channel></rss>`;
    const engine = new IngestionEngine(fakeDb(), undefined, async () => rss, new RuleBasedAiSummarizer(), new AdminService(), {
      pageFetch: null,
      pushService: new PushService({ send: async (m: any) => { sent.push(m); return 'msg-1'; } }),
    });
    const stats = await engine.processSource(verge, false);
    expect(stats.accepted).toBe(1);
    expect(stats.breakingPushes).toBe(1);
    expect(sent[0].topic).toBe('breaking');
    expect(sent[0].data.url).toBe('https://www.theverge.com/security/9/vpn-zero-day');

    const failing = new IngestionEngine(fakeDb(), undefined, async () => rss, new RuleBasedAiSummarizer(), new AdminService(), {
      pageFetch: null,
      pushService: new PushService({ send: async () => { throw new Error('boom'); } }),
    });
    const s2 = await failing.processSource(verge, false);
    expect(s2.accepted).toBe(1);
    expect(s2.breakingPushes).toBe(0);
  });

  test('rule-based breaking detection is conservative', () => {
    expect(detectBreakingByRules('CISA Adds Two Known Exploited Vulnerabilities to Catalog', '')).toBe(false);
    expect(detectBreakingByRules('Massive outage hits AWS us-east-1', '')).toBe(true);
  });
});

describe('Daily brief', () => {
  test('brief id follows the Asia/Kolkata calendar day', () => {
    // 2026-10-31 20:00 UTC is 2026-11-01 01:30 IST
    expect(DailyBriefGenerator.generateDateId(new Date('2026-10-31T20:00:00Z'))).toBe('brief-2026-11-01');
  });

  test('seedReason flags demo/seeded/hub docs and keeps real ingested ones', () => {
    expect(AdminService.seedReason('demo-ai-01', {})).toBe('demo id');
    expect(AdminService.seedReason('art-1', { sourceUrl: 'https://x.com/a/b-c' })).toBe('not written by ingestion engine');
    expect(AdminService.seedReason('art-2', { sourceId: 's', ingestedAt: 1, sourceUrl: 'https://github.blog' })).toBe('sourceUrl is a homepage/hub');
    expect(AdminService.seedReason('art-3', { sourceId: 's', ingestedAt: 1, sourceUrl: 'https://github.blog/news-insights/post-title/' })).toBeNull();
  });
});
