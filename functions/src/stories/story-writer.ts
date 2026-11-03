/**
 * Writes story cards. Gemini writes 4-6 stories per call (one JSON array keyed by story id, original
 * words only, per-category questions); each story in a batch is validated on its own. When Gemini
 * is unavailable / throttled / rate-limited / returns something invalid for a story, a rule-based
 * fallback writes a story-specific simplified summary (low confidence + needsEnrichment).
 */
import { takeGeminiSlot, markGeminiRateLimited, geminiBudgetLeft } from '../ai/server-ai-summarizer';
import { CATEGORY_IDS, CategoryId, categoryLabel, classify, looksLikeScam, looksUnconfirmed, toCategoryId } from './categories';
import { isOfficialAdvisoryUrl } from './feeds';
import { checkKeyNumbers, extractKeyNumbers, KeyNumber } from './facts';
import { questionGuide, questionsFor } from './questions';
import { plainSentencesAt } from './simplify';
import { cleanHeadline, findCopiedRun, formatIst, truncate, wordList } from './text';
import { Confidence, FALLBACK_MODEL, FaqItem, ScamDetails, STORY_PROMPT_VERSION } from './types';

export const DEFAULT_GEMINI_MODEL = 'gemini-flash-lite-latest';
export const DEFAULT_BATCH_SIZE = 5;
export const MAX_BATCH_SIZE = 6;

export interface WriterSource {
  sourceName: string;
  title: string;
  snippet: string;
  url: string;
  publishedAt: string;
  official: boolean;
}

export interface WriterInput {
  storyId: string;
  sources: WriterSource[];
  categoryHint: CategoryId;
}

export interface WrittenStory {
  headline: string;
  category: CategoryId;
  /** "In one line" TL;DR. */
  tldr: string;
  /** Prices, dates, %, user counts found in the reports (never invented). */
  keyNumbers: KeyNumber[];
  whatHappened: string;
  affectsWho: string;
  /** Steps / facts for the category's third question. Empty = show goodToKnow or hide. */
  whatToDo: string[];
  /** A useful tip shown as "Good to know" when there is nothing to do. */
  goodToKnow: string;
  whatItMeans: string;
  /** "Ask about this": likely reader questions with short answers. */
  faq: FaqItem[];
  scam: ScamDetails | null;
  confidence: Confidence;
  unconfirmed: boolean;
  aiModel: string;
  needsEnrichment: boolean;
  promptVersion: string;
  /** False when the AI judged the reports not to be technology news: the story is discarded. */
  isTech: boolean;
}

export class StoryValidationError extends Error {}

// ---------------------------------------------------------------------------------------------
// Prompt
// ---------------------------------------------------------------------------------------------

export const STORY_SYSTEM_INSTRUCTION = `You write for TechDaily, a technology news app for everyday people in India.
Readers are not tech experts. Explain each story so a 14-year-old in India understands it, in simple Indian English.
You get SEVERAL stories. Write one card per story and return them all in "stories", each with the story's "id".
TechDaily carries ONLY technology news (any field of tech). For each story first decide "isTech".

RULES
1. Use only facts that are in that story's reports. Never invent numbers, prices, dates, names, quotes or links.
2. Write everything in your OWN words. Never copy a sentence or any run of more than 6 words from the reports.
3. Simple words, short sentences. Explain any tech term in a few words. Be concrete: who, what, price in ₹ when the reports give it, dates.
4. Calm and neutral. No hype, no clickbait, no ALL CAPS, no emojis, no "game-changer", no "revolutionary".
5. Think about readers in India: mention rupees, UPI, Indian apps, Indian availability or rules only when the reports do. If India price/launch is not in the reports, say "not announced for India yet" rather than guessing.
6. If the reports are thin, disagree, or describe a leak, rumour or "reportedly" claim, say it is not confirmed, set "unconfirmed": true and lower "confidence".
7. Never write "Nothing to do", "open the original report" or "this was written automatically". If there is genuinely nothing for a reader to do, return "whatToDo": [] and put ONE useful, related tip in "goodToKnow".
8. Every answer must be about THIS story (name the product, company, app or mission). Generic sentences that would fit any story are not allowed.

QUESTIONS — each card answers the four questions of its category (the stored keys stay the same; what goes in them changes):
${questionGuide()}

FIELDS (per story)
- id: the story id you were given.
- isTech: true for technology news: gadgets, apps, AI, software, internet, telecom, chips, cyber security,
  fintech and digital payments, digital government services and tech laws, EVs and mobility tech, space tech, gaming,
  health tech, tech companies, tech jobs and skills, science and engineering breakthroughs.
  false for general politics, elections, war, sports, films and celebrities, crime, weather, share prices / stock-market
  moves or quarterly results with no tech angle, and business news with no technology in it. When false, fill the other fields briefly.
- headline: at most 90 characters, plain words, says what happened.
- category: exactly one of ${CATEGORY_IDS.map((c) => `"${c}"`).join(', ')}.
  scams-security = scams, fraud, hacking, data breaches, security bugs and updates; ai = AI tools and companies;
  phones-gadgets = phones, laptops, wearables, TVs and other devices; chips-hardware = chips, processors, memory, data centres;
  startups-india = startups, funding, Indian tech companies; innovations = research, robots, new inventions, science breakthroughs;
  money-fintech = UPI, banks' digital services, payments, loan apps, crypto; privacy = personal data, tracking, surveillance;
  telecom = 5G, broadband, Jio/Airtel/Vi/BSNL plans and prices, TRAI/DoT rules, satellite internet, outages;
  digital-india = Aadhaar, UPI/NPCI rules, DigiLocker, ONDC, IT rules and DPDP law, government tech services;
  ev-mobility = electric vehicles, batteries, charging, self-driving, ride-hailing, FASTag;
  space = ISRO, Gaganyaan, SpaceX, NASA, rockets, satellites; apps-gaming = app updates and bans, games, consoles, BGMI, OTT apps;
  health-tech = ABHA, telemedicine, health features in wearables, medical AI and devices;
  jobs-skills = tech hiring and layoffs, IT services jobs, GCCs, AI skills and courses.
- tldr: ONE sentence, at most 25 words: the whole story in one line.
- keyNumbers: 0 to 4 items {value, label} for numbers that appear in the reports (price "₹49,999" / "Price", date "15 Nov" / "Sale date", "12%" / "Price hike", "3 crore" / "Users"). Copy the number exactly; [] when there are none.
- whatHappened: 1 or 2 short sentences (max 45 words) answering the category's first question.
- affectsWho: 1 sentence answering the category's second question.
- whatToDo: 0 to 3 items answering the category's third question, each under 20 words. For step questions start each with a verb.
- goodToKnow: one useful tip (under 25 words) when whatToDo is empty, otherwise "".
- whatItMeans: 1 or 2 sentences answering the category's fourth question.
- faq: 3 or 4 questions a reader would likely ask about THIS story, each {q, a}: q under 70 characters (e.g. "Is this available in India?",
  "Is my phone affected?", "What does <term> mean?", "How much does it cost?"), a: 1 or 2 short sentences using only facts from the reports;
  when the reports don't say, answer honestly that it is not known yet.
- isScam: true only when the story is about a scam or fraud that targets people.
- scam: when isScam is true, {howItWorks: 2-3 sentences explaining the trick step by step, warningSigns: 2-4 short signs,
  ifTargeted: 2-4 steps (for India include calling 1930 or reporting at cybercrime.gov.in if money was lost),
  advisoryUrl: an official advisory URL ONLY if one appears in the reports, else null}. When isScam is false, scam is null.
- confidence: "high" (official source or several reports agree), "medium" (one reliable report), "low" (unclear, thin or conflicting).
- unconfirmed: true for leaks, rumours, "reportedly" or single-source claims that are not confirmed.

Respond with JSON only: {"stories": [ ...one object per story... ]}.`;

function storyBlock(input: WriterInput, maxSources: number, snippetChars: number): string[] {
  const qs = questionsFor(input.categoryHint);
  const lines = [
    `=== STORY id=${input.storyId}`,
    `Category hint: ${input.categoryHint} (${categoryLabel(input.categoryHint)}) — questions: ${qs.whatHappened.label} / ${qs.affectsWho.label} / ${qs.whatToDo.label} / ${qs.whatItMeans.label}. Change the category if another fits better.`,
    'REPORTS:',
  ];
  input.sources.slice(0, maxSources).forEach((s, i) => {
    lines.push(
      `[${i + 1}] ${s.sourceName}${s.official ? ' (official source)' : ''} — published ${s.publishedAt}`,
      `URL: ${s.url}`,
      `Headline: ${s.title}`,
      `Text: ${truncate(s.snippet || '(no text in feed)', snippetChars)}`
    );
  });
  lines.push('');
  return lines;
}

/** User prompt for a batch of stories (one block per story, keyed by id). */
export function buildBatchPrompt(inputs: WriterInput[]): string {
  const many = inputs.length > 1;
  const lines: string[] = [];
  for (const input of inputs) lines.push(...storyBlock(input, many ? 4 : 5, many ? 900 : 1200));
  lines.push(`Write ${inputs.length} TechDaily story card${many ? 's' : ''} as JSON: {"stories": [...]} with ids ${inputs.map((i) => i.storyId).join(', ')}.`);
  return lines.join('\n');
}

/** Single-story prompt (kept for callers/tests): a batch of one. */
export function buildStoryPrompt(input: WriterInput): string {
  return buildBatchPrompt([input]);
}

const S = (description?: string) => ({ type: 'STRING', ...(description ? { description } : {}) });
const ARR = (min: number, max: number) => ({ type: 'ARRAY', items: { type: 'STRING' }, minItems: min, maxItems: max });

export const STORY_OBJECT_SCHEMA = {
  type: 'OBJECT',
  properties: {
    id: S(),
    isTech: { type: 'BOOLEAN' },
    headline: S(),
    category: { type: 'STRING', enum: CATEGORY_IDS },
    tldr: S(),
    keyNumbers: {
      type: 'ARRAY',
      maxItems: 4,
      items: { type: 'OBJECT', properties: { value: S(), label: S() }, required: ['value', 'label'] },
    },
    whatHappened: S(),
    affectsWho: S(),
    whatToDo: ARR(0, 3),
    goodToKnow: S(),
    whatItMeans: S(),
    faq: {
      type: 'ARRAY',
      maxItems: 4,
      items: { type: 'OBJECT', properties: { q: S(), a: S() }, required: ['q', 'a'] },
    },
    isScam: { type: 'BOOLEAN' },
    scam: {
      type: 'OBJECT',
      nullable: true,
      properties: {
        howItWorks: S(),
        warningSigns: ARR(1, 4),
        ifTargeted: ARR(1, 4),
        advisoryUrl: { type: 'STRING', nullable: true },
      },
      required: ['howItWorks', 'warningSigns', 'ifTargeted'],
    },
    confidence: { type: 'STRING', enum: ['high', 'medium', 'low'] },
    unconfirmed: { type: 'BOOLEAN' },
  },
  required: ['id', 'isTech', 'headline', 'category', 'tldr', 'whatHappened', 'affectsWho', 'whatToDo', 'whatItMeans', 'faq', 'isScam', 'confidence', 'unconfirmed'],
};

export const STORY_RESPONSE_SCHEMA = {
  type: 'OBJECT',
  properties: { stories: { type: 'ARRAY', items: STORY_OBJECT_SCHEMA } },
  required: ['stories'],
};

// ---------------------------------------------------------------------------------------------
// Validation
// ---------------------------------------------------------------------------------------------

function str(v: unknown, field: string, min: number, max: number): string {
  if (typeof v !== 'string') throw new StoryValidationError(`${field} must be a string`);
  const t = v.replace(/\s+/g, ' ').trim();
  if (t.length < min) throw new StoryValidationError(`${field} is too short`);
  if (t.length > max) throw new StoryValidationError(`${field} is too long (${t.length} > ${max})`);
  return t;
}

function strList(v: unknown, field: string, min: number, max: number, itemMax = 220): string[] {
  if (!Array.isArray(v)) throw new StoryValidationError(`${field} must be an array`);
  const out = v
    .filter((x) => typeof x === 'string')
    .map((x) => (x as string).replace(/\s+/g, ' ').trim())
    .filter((x) => x.length >= 3)
    .map((x) => truncate(x, itemMax));
  if (out.length < min) throw new StoryValidationError(`${field} needs at least ${min} item(s)`);
  return out.slice(0, max);
}

/** Canned filler the v3 cards must never show. */
const FILLER_RE = /^(nothing (?:to do|urgent|much)|no action (?:is )?needed|open the original report|read the original)/i;

function faqList(v: unknown): FaqItem[] {
  if (!Array.isArray(v)) return [];
  const out: FaqItem[] = [];
  for (const x of v) {
    if (!x || typeof x !== 'object') continue;
    const q = String((x as any).q ?? '').replace(/\s+/g, ' ').trim();
    const a = String((x as any).a ?? '').replace(/\s+/g, ' ').trim();
    if (q.length < 6 || a.length < 6) continue;
    out.push({ q: truncate(q.endsWith('?') ? q : `${q}?`, 90), a: truncate(a, 320) });
    if (out.length >= 4) break;
  }
  return out;
}

/** First sentence of a text, at most `max` chars. */
function firstSentence(t: string, max = 180): string {
  const m = t.match(/^(.+?[.!?])(\s|$)/);
  return truncate(m ? m[1] : t, max);
}

/**
 * Validates and cleans one story of the model's JSON. Throws StoryValidationError on anything
 * unusable, including text copied from the reports (10+ word runs).
 */
export function validateStoryJson(raw: unknown, input: WriterInput, model: string): WrittenStory {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) throw new StoryValidationError('output is not an object');
  const o = raw as Record<string, unknown>;
  let headline = str(o.headline, 'headline', 12, 160);
  if (headline.length > 110) headline = truncate(headline, 110);
  if (headline === headline.toUpperCase() && /[A-Z]{6,}/.test(headline)) throw new StoryValidationError('headline is all caps');
  const category = toCategoryId(o.category, input.categoryHint);
  const whatHappened = str(o.whatHappened, 'whatHappened', 20, 450);
  const affectsWho = str(o.affectsWho, 'affectsWho', 5, 260);
  const whatToDo = strList(o.whatToDo ?? [], 'whatToDo', 0, 3).filter((x) => !FILLER_RE.test(x));
  const whatItMeans = str(o.whatItMeans, 'whatItMeans', 15, 450);
  let tldr = typeof o.tldr === 'string' ? o.tldr.replace(/\s+/g, ' ').trim() : '';
  if (tldr.length < 12) tldr = firstSentence(whatHappened);
  tldr = truncate(tldr, 200);
  const goodToKnowRaw = typeof o.goodToKnow === 'string' ? o.goodToKnow.replace(/\s+/g, ' ').trim() : '';
  const goodToKnow = whatToDo.length === 0 && goodToKnowRaw.length >= 8 && !FILLER_RE.test(goodToKnowRaw) ? truncate(goodToKnowRaw, 220) : '';
  const confidence: Confidence = o.confidence === 'high' || o.confidence === 'low' ? o.confidence : 'medium';
  const unconfirmed = o.unconfirmed === true;
  const faq = faqList(o.faq);

  let scam: ScamDetails | null = null;
  const isScam = o.isScam === true;
  if (isScam && o.scam && typeof o.scam === 'object') {
    const sc = o.scam as Record<string, unknown>;
    const advisory = typeof sc.advisoryUrl === 'string' ? sc.advisoryUrl.trim() : '';
    const inReports = input.sources.some((s) => s.url === advisory || (s.snippet || '').includes(advisory));
    scam = {
      howItWorks: str(sc.howItWorks, 'scam.howItWorks', 20, 600),
      warningSigns: strList(sc.warningSigns, 'scam.warningSigns', 1, 4, 160),
      ifTargeted: strList(sc.ifTargeted, 'scam.ifTargeted', 1, 4, 200),
      advisoryUrl: advisory && isOfficialAdvisoryUrl(advisory) && inReports ? advisory : officialSourceUrl(input),
    };
  } else if (isScam) {
    throw new StoryValidationError('isScam is true but scam details are missing');
  }

  const sourceTexts = input.sources.map((s) => s.snippet || '');
  const body = [
    tldr,
    whatHappened,
    affectsWho,
    ...whatToDo,
    goodToKnow,
    whatItMeans,
    ...faq.map((f) => f.a),
    scam?.howItWorks ?? '',
    ...(scam?.warningSigns ?? []),
    ...(scam?.ifTargeted ?? []),
  ].join(' \n ');
  const copied = findCopiedRun(body, sourceTexts, 10);
  if (copied) throw new StoryValidationError(`copied text from the report: "${copied}"`);

  const allText = input.sources.map((s) => `${s.title} ${s.snippet}`).join(' ');
  return {
    headline,
    category: scam ? 'scams-security' : category,
    tldr,
    keyNumbers: checkKeyNumbers(o.keyNumbers, allText),
    whatHappened,
    affectsWho,
    whatToDo,
    goodToKnow,
    whatItMeans,
    faq,
    scam,
    confidence,
    unconfirmed,
    aiModel: model,
    needsEnrichment: false,
    promptVersion: STORY_PROMPT_VERSION,
    // Only an explicit false discards; a missing field keeps the story (the keyword gate already ran).
    isTech: o.isTech !== false,
  };
}

/** Splits a parsed batch response into raw story objects by id. A lone object answers a batch of one. */
export function storiesById(parsed: unknown, inputs: WriterInput[]): Map<string, unknown> {
  const out = new Map<string, unknown>();
  let arr: unknown[] = [];
  if (Array.isArray(parsed)) arr = parsed;
  else if (parsed && typeof parsed === 'object') {
    const st = (parsed as any).stories;
    if (Array.isArray(st)) arr = st;
    else arr = [parsed];
  }
  const ids = new Set(inputs.map((i) => i.storyId));
  for (const x of arr) {
    if (!x || typeof x !== 'object') continue;
    const id = String((x as any).id ?? '').trim();
    if (ids.has(id) && !out.has(id)) out.set(id, x);
    else if (!id && inputs.length === 1 && !out.has(inputs[0].storyId)) out.set(inputs[0].storyId, x);
  }
  return out;
}

function officialSourceUrl(input: WriterInput): string | null {
  const s = input.sources.find((x) => x.official && isOfficialAdvisoryUrl(x.url));
  return s ? s.url : null;
}

// ---------------------------------------------------------------------------------------------
// Rule-based fallback: story-specific, built from the headline + report descriptions
// ---------------------------------------------------------------------------------------------

/** Who a story is about, from names in the reports ("WhatsApp users"). */
const AUDIENCES: Array<[RegExp, string]> = [
  [/\bwhatsapp\b/i, 'WhatsApp users'],
  [/\b(upi|phonepe|google pay|gpay|paytm|bhim)\b/i, 'people who pay with UPI apps'],
  [/\b(apple watch|watchos)\b/i, 'Apple Watch owners'],
  [/\b(iphone|ios)\b/i, 'iPhone users'],
  [/\b(mac|macbook|macos)\b/i, 'Mac users'],
  [/\bandroid\b/i, 'Android phone users'],
  [/\b(samsung|galaxy)\b/i, 'Samsung Galaxy owners'],
  [/\bpixel\b/i, 'Google Pixel owners'],
  [/\b(oneplus|xiaomi|redmi|realme|oppo|vivo|poco|iqoo|motorola|nothing phone)\b/i, 'people shopping for a new Android phone'],
  [/\b(jio|reliance jio)\b/i, 'Jio customers'],
  [/\b(airtel)\b/i, 'Airtel customers'],
  [/\b(vodafone idea|\bvi\b)\b/i, 'Vi customers'],
  [/\bbsnl\b/i, 'BSNL customers'],
  [/\baadhaar\b/i, 'anyone with an Aadhaar number'],
  [/\bfastag\b/i, 'drivers who use FASTag'],
  [/\bchatgpt\b/i, 'ChatGPT users'],
  [/\bgemini\b/i, 'Google Gemini users'],
  [/\b(copilot|windows)\b/i, 'Windows PC users'],
  [/\bchrome\b/i, 'Chrome browser users'],
  [/\b(gmail)\b/i, 'Gmail users'],
  [/\b(instagram|facebook|meta)\b/i, 'Instagram and Facebook users'],
  [/\byoutube\b/i, 'YouTube viewers'],
  [/\b(netflix|jiohotstar|prime video|spotify)\b/i, 'streaming subscribers'],
  [/\b(bgmi|free fire|gamers?|playstation|ps5|xbox|nintendo|steam)\b/i, 'gamers'],
  [/\b(ola electric|ather|tata ev|nexon ev|electric scooters?|electric cars?|\bevs?\b)\b/i, 'people planning to buy an electric vehicle'],
  [/\b(laptops?|notebooks?|windows pcs?)\b/i, 'people buying a laptop'],
  [/\b(swiggy|zomato|zepto|blinkit|flipkart|amazon|meesho)\b/i, 'shoppers using these apps'],
  [/\b(layoffs?|laid off|job cuts)\b/i, 'employees at the companies named'],
  [/\b(freshers|campus hiring|hiring)\b/i, 'job seekers in tech'],
];

function audiences(titles: string, body: string): string[] {
  const pick = (t: string, max: number, into: string[]) => {
    for (const [re, who] of AUDIENCES) {
      if (into.length >= max) break;
      if (re.test(t) && !into.includes(who)) into.push(who);
    }
    return into;
  };
  // Names in the headlines are what the story is about; the body only decides when titles name none.
  const out = pick(titles, 2, []);
  return out.length ? out : pick(body.slice(0, 1200), 1, out);
}

/** Useful tips per category shown as "Good to know" when a fallback has no specific steps. */
const GOOD_TO_KNOW: Partial<Record<CategoryId, string>> = {
  'money-fintech': 'You never need your UPI PIN to receive money — only to send it.',
  telecom: 'Your plan, validity and data balance are in your operator’s app (MyJio, Airtel Thanks, Vi) — check it before recharging.',
  'digital-india': 'Use only official sites ending in .gov.in and the official apps for Aadhaar, DigiLocker and other government services.',
  privacy: 'Phone Settings → Privacy (or Apps → Permissions) shows which apps can use your location, camera and contacts.',
  ai: 'Don’t paste bank details, passwords or health records into AI chatbots.',
  'health-tech': 'Health apps and wearables can guide you, but a doctor should confirm anything serious.',
  'apps-gaming': 'Install apps only from the Play Store or App Store, and update them to get new features and security fixes.',
  'jobs-skills': 'Many good AI and coding courses are free — for example on SWAYAM and NPTEL.',
  'phones-gadgets': 'Launch prices often drop during the first sale weeks and bank offers — compare stores before buying.',
  'ev-mobility': 'Check the real-world range, charging options near you and any state EV subsidy before buying.',
};

const SCAM_FALLBACK = {
  todo: [
    "Don't click links or share OTPs, PINs or passwords with anyone who contacts you first.",
    "Check the claim yourself in the official app or on the company's official website.",
  ],
  scam: (trick: string, advisoryUrl: string | null): ScamDetails => ({
    howItWorks: trick
      ? `${trick} Scams like this work by creating panic or a tempting offer so you pay, share a code or install an app before you think.`
      : 'Scammers pretend to be someone you trust, create panic or a tempting offer, and push you to act fast — pay money, share a code, or install an app.',
    warningSigns: [
      'Pressure to act immediately or face a penalty',
      'Requests for OTPs, PINs, passwords or screen-sharing apps',
      "Links, numbers or payment IDs that don't match the official website",
    ],
    ifTargeted: [
      'Stop replying and do not send any more money.',
      'Call your bank to block your card or UPI if you shared details.',
      'Call 1930 or file a complaint at cybercrime.gov.in.',
    ],
    advisoryUrl,
  }),
};

const DEVICE_UPDATE: Array<[RegExp, string]> = [
  [/\b(iphone|ios|ipad|macos|safari|apple)\b/i, 'Update your iPhone or Mac: Settings → General → Software Update.'],
  [/\b(android|pixel|samsung|galaxy)\b/i, 'Update your Android phone: Settings → System → Software update.'],
  [/\bwhatsapp\b/i, 'Update WhatsApp from the Play Store or App Store.'],
  [/\b(chrome|edge|firefox|browser)\b/i, 'Update your web browser and restart it.'],
  [/\b(windows|microsoft)\b/i, 'Run Windows Update and restart your computer.'],
];

export function joinNames(names: string[]): string {
  const u = [...new Set(names)];
  if (u.length <= 1) return u[0] ?? 'A news outlet';
  if (u.length === 2) return `${u[0]} and ${u[1]}`;
  return `${u[0]}, ${u[1]} and ${u.length - 2} other outlet${u.length - 2 > 1 ? 's' : ''}`;
}

const cap = (s: string) => s.charAt(0).toUpperCase() + s.slice(1);

/** Story-specific card without AI: always valid, low confidence, needs enrichment. */
export function fallbackStory(input: WriterInput): WrittenStory {
  const lead = input.sources[0];
  const headline = truncate(cleanHeadline(lead?.title || 'Tech news update', lead?.sourceName), 110);
  const titles = input.sources.map((s) => s.title).join(' · ');
  const allText = input.sources.map((s) => `${s.title}. ${s.snippet}`).join(' ');
  const { category } = classify(titles, allText, input.categoryHint);
  const isScam = category === 'scams-security' && looksLikeScam(titles);
  const names = joinNames(input.sources.map((s) => s.sourceName));
  const snippets = input.sources.map((s) => s.snippet || '').filter(Boolean);

  const found = plainSentencesAt(snippets, headline, 3);
  // The one-liner must be a lead sentence of a report; no usable lead = no one-liner (repeating the
  // headline adds nothing).
  const lead0 = found.find((x) => x.index <= 1);
  const tldr = lead0 ? truncate(lead0.text, 200) : '';
  const rest = found.filter((x) => x !== lead0).slice(0, 2).map((x) => x.text);
  const sentences = [tldr, ...rest].filter(Boolean);
  const whatHappened = rest.length ? `${rest.join(' ')} Reported by ${names}.` : '';

  const keyNumbers = extractKeyNumbers(allText);
  const who = audiences(titles, allText);
  let affectsWho = who.length ? `Mainly ${who.join(' and ')}.` : '';
  let whatToDo: string[] = [];
  let goodToKnow = '';
  let scam: ScamDetails | null = null;

  if (isScam) {
    affectsWho = who.length
      ? `${cap(who.join(' and '))}, and anyone who gets messages or calls from strangers.`
      : 'Anyone who gets calls, SMS, WhatsApp messages or emails from strangers — especially people who use UPI or net banking.';
    whatToDo = [...SCAM_FALLBACK.todo];
    scam = SCAM_FALLBACK.scam('', officialSourceUrl(input));
  } else if (category === 'scams-security') {
    const hit = DEVICE_UPDATE.find(([re]) => re.test(allText.slice(0, 800)));
    if (hit) whatToDo.push(hit[1]);
    if (/\b(breach|leak|leaked|stolen|password|credential|account)/i.test(allText)) {
      whatToDo.push('If you use the affected service, change that password and turn on two-step verification.');
    }
    if (!whatToDo.length) goodToKnow = 'Two-step verification on your email, bank and social accounts stops most account takeovers, even if a password leaks.';
  } else if (category === 'phones-gadgets' || category === 'ev-mobility') {
    const wanted = category === 'ev-mobility' ? /price|on sale|launch|range|date/i : /price|on sale|launch|date/i;
    const facts = keyNumbers.filter((k) => wanted.test(k.label));
    whatToDo = facts.slice(0, 3).map((k) => `${k.label}: ${k.value} (as reported)`);
    if (category === 'phones-gadgets' && whatToDo.length && !/india|₹/i.test(allText)) whatToDo.push('India price and availability: not announced yet.');
    if (!whatToDo.length) goodToKnow = GOOD_TO_KNOW[category] ?? '';
  } else if (category === 'space' || category === 'innovations' || category === 'chips-hardware' || category === 'startups-india') {
    // "Cool fact" / company news: nothing honest to add without the AI — hide the section.
  } else {
    goodToKnow = GOOD_TO_KNOW[category] ?? '';
  }

  // Two story-specific Q&As (or none).
  const faq: FaqItem[] = [];
  if (isScam) faq.push({ q: 'What if I already paid or shared an OTP?', a: 'Call 1930 or report at cybercrime.gov.in right away, and ask your bank to block your card or UPI.' });
  const price = ['phones-gadgets', 'ev-mobility', 'apps-gaming', 'telecom', 'ai'].includes(category) ? keyNumbers.find((k) => /price/i.test(k.label)) : undefined;
  if (price) faq.push({ q: 'How much does it cost?', a: `The reports mention ${price.value}. Check the official store for the final price and offers.` });
  const date = keyNumbers.find((k) => /^(on sale|launch)$/i.test(k.label));
  if (date && faq.length < 2) faq.push({ q: 'What’s the date?', a: `The reports give the date as ${date.value}.` });
  if (faq.length < 2 && lead) {
    faq.push({ q: 'Who reported this?', a: `${names}${lead.publishedAt ? `, first on ${formatIst(lead.publishedAt).replace(/,\s*\d{4},/, ',')}` : ''}. Tap Sources to read the originals.` });
  }

  return {
    headline,
    category,
    tldr,
    keyNumbers,
    whatHappened,
    affectsWho,
    whatToDo,
    goodToKnow,
    whatItMeans: '',
    faq: faq.slice(0, 2),
    scam,
    confidence: 'low',
    unconfirmed: looksUnconfirmed(titles),
    aiModel: FALLBACK_MODEL,
    needsEnrichment: true,
    promptVersion: STORY_PROMPT_VERSION,
    isTech: true,
  };
}

// ---------------------------------------------------------------------------------------------
// Writer
// ---------------------------------------------------------------------------------------------

export interface StoryWriterConfig {
  apiKey?: string;
  model?: string;
  timeoutMs?: number;
  fetchFn?: typeof fetch;
  /** Stories per Gemini call (1-6). Default GEMINI_BATCH_SIZE or 5. */
  batchSize?: number;
}

export interface WriterStats {
  /** Gemini HTTP calls made. */
  aiCalls: number;
  /** Stories written by Gemini. */
  aiOk: number;
  /** Stories Gemini returned that failed validation (or were missing from a batch). */
  aiInvalid: number;
  /** Calls that failed (HTTP / network / unparseable). */
  aiErrors: number;
  fallbacks: number;
  rateLimited: boolean;
}

export interface WriteManyOptions {
  allowFallback?: boolean;
  /** Epoch ms after which no further AI calls start (the rest gets fallback / null). */
  deadline?: number;
}

export class StoryWriter {
  private apiKey?: string;
  readonly model: string;
  readonly batchSize: number;
  private timeoutMs: number;
  private fetchFn: typeof fetch;
  private useSchema = true;
  readonly stats: WriterStats = { aiCalls: 0, aiOk: 0, aiInvalid: 0, aiErrors: 0, fallbacks: 0, rateLimited: false };

  constructor(cfg: StoryWriterConfig = {}) {
    this.apiKey = cfg.apiKey ?? process.env.GEMINI_API_KEY;
    this.model = cfg.model || process.env.GEMINI_MODEL || DEFAULT_GEMINI_MODEL;
    this.timeoutMs = cfg.timeoutMs ?? 45000;
    this.fetchFn = cfg.fetchFn ?? (globalThis.fetch as typeof fetch);
    const env = parseInt(process.env.GEMINI_BATCH_SIZE || '', 10);
    const b = cfg.batchSize ?? (Number.isFinite(env) ? env : DEFAULT_BATCH_SIZE);
    this.batchSize = Math.max(1, Math.min(MAX_BATCH_SIZE, b));
  }

  hasApiKey(): boolean {
    return Boolean(this.apiKey);
  }

  /** True when another Gemini call could be made right now. */
  aiAvailable(): boolean {
    return this.hasApiKey() && geminiBudgetLeft();
  }

  /** One story (a batch of one). */
  async write(input: WriterInput, allowFallback = true): Promise<WrittenStory | null> {
    return (await this.writeMany([input], { allowFallback }))[0];
  }

  /**
   * Writes many stories, `batchSize` per Gemini call, in the given order (put the most important
   * first). Each story is validated on its own: a bad story in a batch gets the fallback (or null
   * with allowFallback=false, used for re-enrichment) while the good ones are kept.
   */
  async writeMany(inputs: WriterInput[], opts: WriteManyOptions = {}): Promise<Array<WrittenStory | null>> {
    const allowFallback = opts.allowFallback ?? true;
    const out: Array<WrittenStory | null> = new Array(inputs.length).fill(null);
    const done = new Array(inputs.length).fill(false);
    for (let i = 0; i < inputs.length; i += this.batchSize) {
      const idx = Array.from({ length: Math.min(this.batchSize, inputs.length - i) }, (_, k) => i + k);
      const chunk = idx.map((k) => inputs[k]);
      if (opts.deadline !== undefined && Date.now() > opts.deadline) break;
      if (!this.hasApiKey() || !(await takeGeminiSlot())) break;
      let byId: Map<string, unknown>;
      try {
        byId = await this.callGemini(chunk);
      } catch (e: any) {
        this.stats.aiErrors++;
        console.warn(`[StoryWriter] AI batch failed (${chunk.length} stories): ${e?.message || e}`);
        if (this.stats.rateLimited) break;
        continue;
      }
      idx.forEach((k) => {
        const raw = byId.get(inputs[k].storyId);
        if (raw === undefined) {
          this.stats.aiInvalid++;
          console.warn(`[StoryWriter] AI batch left out ${inputs[k].storyId}`);
          return;
        }
        try {
          out[k] = validateStoryJson(raw, inputs[k], this.model);
          done[k] = true;
          this.stats.aiOk++;
        } catch (e: any) {
          this.stats.aiInvalid++;
          console.warn(`[StoryWriter] AI story invalid for ${inputs[k].storyId}: ${e?.message || e}`);
        }
      });
    }
    if (allowFallback) {
      inputs.forEach((input, k) => {
        if (done[k]) return;
        this.stats.fallbacks++;
        out[k] = fallbackStory(input);
      });
    }
    return out;
  }

  private async callGemini(inputs: WriterInput[], retried = false): Promise<Map<string, unknown>> {
    this.stats.aiCalls++;
    const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(this.model)}:generateContent`;
    const generationConfig: Record<string, unknown> = {
      responseMimeType: 'application/json',
      temperature: 0.2,
      maxOutputTokens: Math.min(8192, 1000 + inputs.length * 1300),
    };
    if (this.useSchema) generationConfig.responseSchema = STORY_RESPONSE_SCHEMA;
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.timeoutMs);
    let res: Response;
    try {
      res = await this.fetchFn(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'x-goog-api-key': this.apiKey as string },
        body: JSON.stringify({
          system_instruction: { parts: [{ text: STORY_SYSTEM_INSTRUCTION }] },
          contents: [{ role: 'user', parts: [{ text: buildBatchPrompt(inputs) }] }],
          generationConfig,
        }),
        signal: controller.signal,
      });
    } finally {
      clearTimeout(timer);
    }
    if (!res.ok) {
      const body = await res.text().catch(() => '');
      if (res.status === 429) {
        markGeminiRateLimited();
        this.stats.rateLimited = true;
      }
      // Some models reject parts of responseSchema: retry once without it.
      if (res.status === 400 && this.useSchema && !retried && /schema|response_schema|responseSchema/i.test(body)) {
        this.useSchema = false;
        return this.callGemini(inputs, true);
      }
      throw new Error(`Gemini HTTP ${res.status}: ${body.slice(0, 300)}`);
    }
    const data: any = await res.json();
    const parts = data?.candidates?.[0]?.content?.parts;
    const text = Array.isArray(parts) ? parts.map((p: any) => (typeof p?.text === 'string' && !p?.thought ? p.text : '')).join('') : '';
    if (!text) throw new Error('Gemini returned no text');
    let parsed: unknown;
    try {
      parsed = JSON.parse(text.replace(/^```(?:json)?\s*|\s*```$/g, '').trim());
    } catch {
      throw new StoryValidationError('output is not valid JSON');
    }
    return storiesById(parsed, inputs);
  }
}

/** Words in a text (exported for tests that check fallback originality). */
export const _wordCount = (t: string) => wordList(t).length;
