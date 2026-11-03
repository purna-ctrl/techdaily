/**
 * stories-v3: batched Gemini writing, per-category questions, TL;DR, key numbers, FAQ ("Ask about
 * this"), story-specific fallback and the static page.
 */
import * as fs from 'fs';
import * as path from 'path';
import { CATEGORY_IDS } from '../src/stories/categories';
import { checkKeyNumbers, extractKeyNumbers } from '../src/stories/facts';
import { displayFields, GENERAL_QUESTIONS, QUESTION_SETS, questionsFor, SCAM_QUESTIONS } from '../src/stories/questions';
import { renderStoryPage, SiteContext } from '../src/stories/render/templates';
import { plainSentences } from '../src/stories/simplify';
import { StoryCache } from '../src/stories/story-store';
import { runStoryPipeline } from '../src/stories/story-pipeline';
import { buildBatchPrompt, fallbackStory, STORY_SYSTEM_INSTRUCTION, StoryWriter, validateStoryJson, WriterInput } from '../src/stories/story-writer';
import { findCopiedRun } from '../src/stories/text';
import { resetGeminiBudget } from '../src/ai/server-ai-summarizer';
import { Story, STORY_PROMPT_VERSION } from '../src/stories/types';

const NOW = Date.parse('2026-11-03T09:00:00Z');
const H = 3600 * 1000;
const iso = (h: number) => new Date(NOW - h * H).toISOString();
const ctx: SiteContext = { siteUrl: 'https://techdaily-prod.web.app', firebaseProjectId: 'techdaily-prod', now: NOW };

const input = (id: string, over: Partial<WriterInput> = {}): WriterInput => ({
  storyId: id,
  categoryHint: 'phones-gadgets',
  sources: [
    {
      sourceName: 'Gadgets 360',
      title: `Phone ${id} launched in India at Rs 24,999`,
      snippet: `The phone ${id} has been launched in India at Rs 24,999 for the 8GB variant. It goes on sale from November 12 on Amazon and has a 6000mAh battery and a 50MP camera.`,
      url: `https://www.gadgets360.com/${id}`,
      publishedAt: iso(1),
      official: false,
    },
  ],
  ...over,
});

const aiStory = (id: string) => ({
  id,
  isTech: true,
  headline: `A new mid-range phone ${id} is out in India`,
  category: 'phones-gadgets',
  tldr: `The ${id} phone costs ₹24,999 and goes on sale on 12 November.`,
  keyNumbers: [
    { value: '₹24,999', label: 'Price' },
    { value: '12 Nov', label: 'Sale date' },
    { value: '₹19,999', label: 'Made-up price' },
  ],
  whatHappened: `Gadgets 360 says the ${id} has a big 6000mAh battery and a 50MP main camera.`,
  affectsWho: 'People looking for a phone around ₹25,000.',
  whatToDo: ['Price: ₹24,999 for 8GB RAM', 'Sale: 12 November on Amazon'],
  goodToKnow: '',
  whatItMeans: 'A good battery pick if you are buying in this range.',
  faq: [
    { q: 'Is it available in India?', a: 'Yes, it goes on sale on Amazon from 12 November.' },
    { q: 'How much does it cost', a: 'The 8GB model costs ₹24,999.' },
  ],
  isScam: false,
  scam: null,
  confidence: 'medium',
  unconfirmed: false,
});

/** Gemini mock answering each batch; `map` can change or drop stories by id. */
function gemini(map: (id: string) => Record<string, unknown> | null = aiStory) {
  return jest.fn().mockImplementation(async (_url: string, init: any) => {
    const prompt: string = JSON.parse(init.body).contents[0].parts[0].text;
    const ids = [...prompt.matchAll(/=== STORY id=(\S+)/g)].map((m) => m[1]);
    const stories = ids.map(map).filter(Boolean);
    return { ok: true, status: 200, json: async () => ({ candidates: [{ content: { parts: [{ text: JSON.stringify({ stories }) }] } }] }), text: async () => '' };
  });
}

afterEach(() => {
  resetGeminiBudget();
  delete process.env.GEMINI_MAX_CALLS_PER_RUN;
});

// ---------------------------------------------------------------------------------------------
describe('per-category questions', () => {
  test('every category has its own complete set; scam stories use the scam set', () => {
    for (const c of CATEGORY_IDS) {
      const q = questionsFor(c);
      for (const k of ['whatHappened', 'affectsWho', 'whatToDo', 'whatItMeans'] as const) expect(q[k].label.length).toBeGreaterThan(3);
    }
    expect(questionsFor('space').whatToDo.label).toBe('Cool fact');
    expect(questionsFor('space').whatItMeans.label).toBe('What’s next');
    expect(questionsFor('phones-gadgets').whatToDo.label).toBe('Price & availability in India');
    expect(questionsFor('money-fintech').affectsWho.label).toBe('Does it affect my money?');
    expect(questionsFor('scams-security', true)).toBe(SCAM_QUESTIONS);
    expect(SCAM_QUESTIONS.whatHappened.label).toBe('What’s the trick?');
    expect(questionsFor('top-stories')).toBe(GENERAL_QUESTIONS);
    // Not one generic set: at least 10 distinct second questions across categories.
    expect(new Set(CATEGORY_IDS.map((c) => questionsFor(c).affectsWho.label)).size).toBeGreaterThanOrEqual(10);
  });

  test('the app (Dart) uses exactly the same labels', () => {
    const dart = fs.readFileSync(path.join(__dirname, '../../lib/core/constants/story_questions.dart'), 'utf8');
    for (const set of [...Object.values(QUESTION_SETS), SCAM_QUESTIONS, GENERAL_QUESTIONS]) {
      for (const k of ['whatHappened', 'affectsWho', 'whatToDo', 'whatItMeans'] as const) expect(dart).toContain(`'${set[k].label}'`);
    }
    for (const c of CATEGORY_IDS) expect(dart).toContain(`'${c}': StoryQuestionSet(`);
  });

  test('the prompt carries every category question set and asks for TL;DR, key numbers and FAQ', () => {
    expect(STORY_PROMPT_VERSION).toBe('stories-v3');
    for (const c of CATEGORY_IDS) expect(STORY_SYSTEM_INSTRUCTION).toContain(`- ${c}: whatHappened = "${questionsFor(c).whatHappened.label}"`);
    for (const f of ['tldr', 'keyNumbers', 'faq', 'goodToKnow']) expect(STORY_SYSTEM_INSTRUCTION).toContain(`- ${f}:`);
    expect(STORY_SYSTEM_INSTRUCTION).toMatch(/Never write "Nothing to do"/);
    const p = buildBatchPrompt([input('a'), input('b', { categoryHint: 'space' })]);
    expect(p).toContain('=== STORY id=a');
    expect(p).toContain('=== STORY id=b');
    expect(p).toContain('Cool fact');
  });
});

// ---------------------------------------------------------------------------------------------
describe('batched Gemini writer', () => {
  test('writes 4-6 stories per call: 12 stories with batch 5 = 3 calls', async () => {
    const fetchFn = gemini();
    const w = new StoryWriter({ apiKey: 'k', fetchFn: fetchFn as any, batchSize: 5 });
    const out = await w.writeMany(Array.from({ length: 12 }, (_, i) => input(`s${i}`)));
    expect(fetchFn).toHaveBeenCalledTimes(3);
    expect(out.every((s) => s && s.aiModel === w.model)).toBe(true);
    expect(w.stats).toMatchObject({ aiCalls: 3, aiOk: 12, fallbacks: 0 });
    const s0 = out[0]!;
    expect(s0.tldr).toContain('₹24,999');
    // Key numbers not present in the reports are dropped.
    expect(s0.keyNumbers.map((k) => k.value)).toEqual(['₹24,999', '12 Nov']);
    expect(s0.faq).toHaveLength(2);
    expect(s0.faq[1].q).toBe('How much does it cost?');
  });

  test('batch size is clamped to 1..6 and read from GEMINI_BATCH_SIZE', () => {
    expect(new StoryWriter({ apiKey: '', batchSize: 20 }).batchSize).toBe(6);
    expect(new StoryWriter({ apiKey: '', batchSize: 0 }).batchSize).toBe(1);
    process.env.GEMINI_BATCH_SIZE = '4';
    expect(new StoryWriter({ apiKey: '' }).batchSize).toBe(4);
    delete process.env.GEMINI_BATCH_SIZE;
    expect(new StoryWriter({ apiKey: '' }).batchSize).toBe(5);
  });

  test('one bad story in a batch falls back alone (copied text, missing id); the rest are kept', async () => {
    const copied = (id: string) => ({ ...aiStory(id), whatHappened: `The phone ${id} has been launched in India at Rs 24,999 for the 8GB variant.` });
    const fetchFn = gemini((id) => (id === 'b' ? copied(id) : id === 'c' ? null : aiStory(id)));
    const w = new StoryWriter({ apiKey: 'k', fetchFn: fetchFn as any, batchSize: 5 });
    const out = await w.writeMany(['a', 'b', 'c', 'd'].map((id) => input(id)));
    expect(fetchFn).toHaveBeenCalledTimes(1);
    expect(out.map((s) => s!.needsEnrichment)).toEqual([false, true, true, false]);
    expect(w.stats).toMatchObject({ aiOk: 2, aiInvalid: 2, fallbacks: 2 });
    // allowFallback=false (re-enrichment): failed ones are null.
    const w2 = new StoryWriter({ apiKey: 'k', fetchFn: gemini((id) => (id === 'b' ? copied(id) : aiStory(id))) as any });
    const out2 = await w2.writeMany(['a', 'b'].map((id) => input(id)), { allowFallback: false });
    expect(out2[0]).not.toBeNull();
    expect(out2[1]).toBeNull();
  });

  test('stops on 429 and respects the per-run call budget', async () => {
    process.env.GEMINI_MAX_CALLS_PER_RUN = '2';
    const ok = gemini();
    const fetchFn = jest
      .fn()
      .mockImplementationOnce(ok)
      .mockResolvedValueOnce({ ok: false, status: 429, text: async () => 'quota', json: async () => ({}) });
    const w = new StoryWriter({ apiKey: 'k', fetchFn: fetchFn as any, batchSize: 5 });
    const out = await w.writeMany(Array.from({ length: 15 }, (_, i) => input(`s${i}`)));
    expect(fetchFn).toHaveBeenCalledTimes(2);
    expect(w.stats.rateLimited).toBe(true);
    expect(out.filter((s) => !s!.needsEnrichment)).toHaveLength(5);
    expect(out.filter((s) => s!.needsEnrichment)).toHaveLength(10);
    expect(w.aiAvailable()).toBe(false);
  });

  test('validation drops "Nothing to do" filler and keeps a Good to know tip instead', () => {
    const w = validateStoryJson(
      { ...aiStory('a'), category: 'space', whatToDo: ['Nothing to do — just enjoy the news.'], goodToKnow: 'You can watch ISRO launches live on its YouTube channel.' },
      input('a'),
      'm'
    );
    expect(w.whatToDo).toEqual([]);
    expect(w.goodToKnow).toContain('YouTube');
  });
});

// ---------------------------------------------------------------------------------------------
describe('key numbers and fallback', () => {
  test('extracts prices, dates, percentages, user counts and specs', () => {
    const k = extractKeyNumbers('Jio raised prices by 12% from July 3. The plan now costs Rs 299 and Jio has 47 crore subscribers. It has a 5000mAh battery.');
    const byLabel = Object.fromEntries(k.map((x) => [x.value, x.label]));
    expect(byLabel['12%']).toBe('Increase');
    expect(byLabel['3 Jul']).toBe('Date');
    expect(byLabel['₹299']).toBe('Plan price');
    expect(k.length).toBeLessThanOrEqual(4);
    expect(checkKeyNumbers([{ value: '₹299', label: 'Price' }, { value: '₹349', label: 'Price' }], 'costs Rs 299')).toEqual([{ value: '₹299', label: 'Price' }]);
  });

  test('fallback is story-specific: paraphrased lead, sources named, key numbers, no boilerplate, no 10-word copies', () => {
    const inp = input('x', {
      sources: [
        {
          sourceName: 'Gadgets 360',
          title: 'Vivo Y32 5G launched with 8,000mAh battery',
          snippet:
            'Vivo Y32 5G has been launched in India with a Snapdragon 4 Gen 2 processor and an 8,000mAh battery. The smartphone supports 44W fast charging and is priced at Rs 14,999 for the 6GB variant. It will be available from November 10 via Flipkart.',
          url: 'https://www.gadgets360.com/vivo',
          publishedAt: iso(1),
          official: false,
        },
      ],
    });
    const f = fallbackStory(inp);
    expect(f.tldr.length).toBeGreaterThan(20);
    expect(f.whatHappened).toContain('Reported by Gadgets 360');
    expect(f.keyNumbers.map((k) => k.value)).toEqual(expect.arrayContaining(['₹14,999', '10 Nov']));
    expect(f.whatToDo.join(' ')).toContain('₹14,999');
    const all = JSON.stringify(f);
    expect(all).not.toMatch(/written automatically|Nothing to do|open the original report/i);
    const body = [f.tldr, f.whatHappened, f.affectsWho, ...f.whatToDo, f.goodToKnow, ...f.faq.map((x) => x.a)].join(' ');
    expect(findCopiedRun(body, [inp.sources[0].snippet], 10)).toBeNull();
    expect(f.faq.length).toBeGreaterThan(0);
    expect(f.faq.length).toBeLessThanOrEqual(2);
  });

  test('fallback drops sections it has nothing honest for (space: no fake "Cool fact")', () => {
    const f = fallbackStory(
      input('s', {
        categoryHint: 'space',
        sources: [{ sourceName: 'ISRO', title: 'ISRO launches PSLV-C62 with EOS-09', snippet: '', url: 'https://www.isro.gov.in/x', publishedAt: iso(1), official: true }],
      })
    );
    expect(f.category).toBe('space');
    expect(f.whatToDo).toEqual([]);
    expect(f.goodToKnow).toBe('');
    expect(f.whatItMeans).toBe('');
    expect(f.affectsWho).toBe('');
  });

  test('plainSentences skips quotes and truncated tails', () => {
    const s = plainSentences(['“We are thrilled,” said the CEO of the company today. The company opened a new chip plant in Gujarat this week. More details on the deal and the cost were not given by the firm in its stat'], 'Chip plant opens');
    // 11 words would be copied: a small word is dropped to keep every run under 10.
    expect(s).toEqual(['The company opened new chip plant in Gujarat this week.']);
  });
});

// ---------------------------------------------------------------------------------------------
describe('pipeline: stories-v3 rewrite', () => {
  const base = (id: string, over: Partial<Story> = {}): Story => ({
    id,
    slug: `story-${id}`,
    headline: `Story ${id} about a new phone`,
    category: 'phones-gadgets',
    publishedAt: iso(2),
    updatedAt: iso(2),
    sources: [{ sourceId: 'gadgets360', name: 'Gadgets 360', url: `https://www.gadgets360.com/${id}`, title: `Phone ${id} launched in India at Rs 24,999`, publishedAt: iso(2) }],
    whatHappened: 'Gadgets 360 reported: a phone. This short version was written automatically — open the original report for full details.',
    affectsWho: 'People who own, or are planning to buy, the phone or gadget in this story.',
    whatToDo: ['Nothing urgent — open the original report.'],
    whatItMeans: 'This helps you make a better choice before your next phone or gadget purchase.',
    scam: null,
    confidence: 'low',
    developing: true,
    aiModel: 'techdaily-fallback-v2',
    needsEnrichment: true,
    enrichAttempts: 3,
    region: 'IN',
    unconfirmed: false,
    promptVersion: 'stories-v2',
    ...over,
  });

  test('older-version stories (incl. old Gemini ones) are rewritten in batches, Top stories first', async () => {
    const cache = new StoryCache();
    cache.upsert(base('old-ai', { aiModel: 'gemini-flash-lite-latest', needsEnrichment: false, confidence: 'medium', developing: false, publishedAt: iso(100) }));
    for (let i = 0; i < 6; i++) cache.upsert(base(`fb${i}`, { publishedAt: iso(3 + i) }));
    const fetchFn = gemini((id) => aiStory(id));
    process.env.GEMINI_MAX_CALLS_PER_RUN = '1';
    const r = await runStoryPipeline({ dryRun: true, feeds: [], imageFetchBudget: 0, now: NOW }, { cache, writer: new StoryWriter({ apiKey: 'k', fetchFn: fetchFn as any, batchSize: 5 }) });
    expect(fetchFn).toHaveBeenCalledTimes(1);
    expect(r.storiesEnriched).toBe(5);
    const v3 = cache.all().filter((s) => s.promptVersion === STORY_PROMPT_VERSION && !s.needsEnrichment);
    expect(v3).toHaveLength(5);
    // The rest of the old fallback cards are rebuilt by the current rule-based writer (no canned text).
    expect(r.storiesRefreshed).toBeGreaterThan(0);
    for (const s of cache.all().filter((x) => x.aiModel.startsWith('techdaily-fallback'))) {
      expect(s.promptVersion).toBe(STORY_PROMPT_VERSION);
      expect(JSON.stringify(s)).not.toMatch(/written automatically|Nothing urgent/);
    }
  });
});

// ---------------------------------------------------------------------------------------------
describe('static story page (v3)', () => {
  const story = (over: Partial<Story> = {}): Story => ({
    id: 'st-1',
    slug: 'isro-launch-st-1',
    headline: 'ISRO puts a new weather satellite in orbit',
    category: 'space',
    publishedAt: iso(2),
    updatedAt: iso(1),
    sources: [{ sourceId: 'isro', name: 'ISRO', url: 'https://www.isro.gov.in/x', title: 'PSLV-C62 success', publishedAt: iso(2) }],
    tldr: 'ISRO launched a weather satellite that will improve monsoon forecasts.',
    keyNumbers: [{ value: '1,450 kg', label: 'Satellite weight' }],
    whatHappened: 'A PSLV rocket carried the satellite from Sriharikota on Monday.',
    affectsWho: 'Better weather data helps farmers and fishermen plan ahead.',
    whatToDo: ['The satellite can spot cloud changes every 15 minutes.'],
    goodToKnow: '',
    whatItMeans: 'ISRO plans a second satellite next year.',
    faq: [{ q: 'Can I see the satellite?', a: 'No, it is too far away to see without a telescope.' }],
    scam: null,
    confidence: 'high',
    developing: false,
    aiModel: 'gemini-flash-lite-latest',
    needsEnrichment: false,
    enrichAttempts: 1,
    region: 'IN',
    unconfirmed: false,
    promptVersion: 'stories-v3',
    ...over,
  });

  test('shows TL;DR, key numbers, the category questions and Ask about this as <details>', () => {
    const html = renderStoryPage(story(), ctx);
    for (const t of ['In one line', 'Key numbers', '1,450 kg', 'What happened?', 'Why should I care?', 'Cool fact', 'What’s next', 'Ask about this', '<details><summary>Can I see the satellite?</summary>']) {
      expect(html).toContain(t);
    }
    expect(html).not.toContain('Does it affect me?');
    expect(html).not.toContain('Simplified summary');
  });

  test('fallback pill, Good to know instead of an empty checklist, empty sections hidden, legacy text stripped', () => {
    const html = renderStoryPage(
      story({ aiModel: 'techdaily-fallback-v3', category: 'money-fintech', whatToDo: [], goodToKnow: 'You never need your UPI PIN to receive money.', whatItMeans: '', affectsWho: '', faq: [] }),
      ctx
    );
    expect(html).toContain('Simplified summary · updating soon');
    expect(html).toContain('Good to know');
    expect(html).not.toContain('Does it affect my money?');
    expect(html).not.toContain('Bottom line');
    expect(html).not.toContain('Ask about this');
    const legacy = displayFields({
      aiModel: 'techdaily-fallback-v2',
      promptVersion: 'stories-v2',
      whatHappened: 'NASA reported: A rocket. This short version was written automatically — open the original report for full details.',
      affectsWho: 'No one directly yet — this is about space missions and satellite technology.',
      whatToDo: ['Nothing to do — open the original report if you want the details.'],
      whatItMeans: 'Space technology powers everyday things like maps, weather forecasts and satellite internet.',
    });
    expect(legacy).toEqual({ tldr: '', whatHappened: '', affectsWho: '', whatToDo: [], goodToKnow: '', whatItMeans: '' });
  });
});
