/**
 * Writes one story card per cluster: one Gemini call (JSON output, original words only) or, when
 * Gemini is unavailable / throttled / rate-limited / returns something invalid, a rule-based
 * fallback that still fills every card field and is marked low confidence + needsEnrichment.
 */
import { takeGeminiSlot, markGeminiRateLimited, geminiBudgetLeft } from '../ai/server-ai-summarizer';
import { CATEGORY_IDS, CategoryId, categoryLabel, classify, looksLikeScam, looksUnconfirmed, toCategoryId } from './categories';
import { isOfficialAdvisoryUrl } from './feeds';
import { cleanHeadline, findCopiedRun, truncate } from './text';
import { Confidence, FALLBACK_MODEL, ScamDetails, STORY_PROMPT_VERSION } from './types';

export const DEFAULT_GEMINI_MODEL = 'gemini-flash-lite-latest';

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
  whatHappened: string;
  affectsWho: string;
  whatToDo: string[];
  whatItMeans: string;
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
Readers are not tech experts. Explain the news so a 14-year-old understands it.
TechDaily carries ONLY technology news (any field of tech). First decide "isTech".

RULES
1. Use only facts that are in the reports you are given. Never invent numbers, prices, dates, names, quotes or links.
2. Write everything in your OWN words. Never copy a sentence or any run of more than 6 words from the reports.
3. Simple English: short sentences, everyday words. If you must use a tech term, explain it in a few words.
4. Be calm and neutral. No hype, no clickbait, no ALL CAPS, no emojis.
5. Think about readers in India: mention rupees, UPI, Indian apps or Indian rules only when the reports do.
6. If the reports are thin, disagree, or describe a leak, rumour or "reportedly" claim, say it is not confirmed, set "unconfirmed": true and lower "confidence".

FIELDS (respond with one JSON object only)
- isTech: true when the story is about technology: gadgets, apps, AI, software, internet, telecom, chips, cyber security,
  fintech and digital payments, digital government services and tech laws, EVs and mobility tech, space tech, gaming,
  health tech, tech companies, tech jobs and skills, science and engineering breakthroughs.
  false for general politics, elections, war, sports, films and celebrities, crime, weather, share prices / stock-market
  moves or quarterly results with no tech angle, and business news with no technology in it (airlines, steel, FMCG, real estate).
  When isTech is false, still fill the other fields briefly; the story will be discarded.
- headline: at most 90 characters, plain words, says what happened.
- category: exactly one of ${CATEGORY_IDS.map((c) => `"${c}"`).join(', ')}.
  scams-security = scams, fraud, hacking, data breaches, security bugs and updates; ai = AI tools and companies;
  phones-gadgets = phones, laptops, wearables, TVs and other devices; chips-hardware = chips, processors, memory, data centres;
  startups-india = startups, funding, Indian tech companies; innovations = research, robots, new inventions, science breakthroughs;
  money-fintech = UPI, banks' digital services, payments, loans apps, crypto; privacy = personal data, tracking, surveillance;
  telecom = 5G, broadband, Jio/Airtel/Vi/BSNL plans and prices, TRAI/DoT rules, satellite internet, network outages;
  digital-india = Aadhaar, UPI/NPCI rules, DigiLocker, ONDC, IT rules and DPDP law, government tech services;
  ev-mobility = electric vehicles, batteries, charging, self-driving, ride-hailing and mobility apps, FASTag;
  space = ISRO, Gaganyaan, SpaceX, NASA, rockets, satellites; apps-gaming = app updates and bans, games, consoles, BGMI,
  OTT and streaming apps (features, prices); health-tech = ABHA, telemedicine, health features in wearables, medical AI and devices;
  jobs-skills = tech hiring and layoffs, IT services jobs, GCCs, AI skills and courses.
- whatHappened: 1 or 2 short sentences (max 45 words).
- affectsWho: 1 sentence naming who is affected (for example "Android phone users", "People who use UPI apps"), or "No one directly yet" with a short reason.
- whatToDo: 1 to 3 concrete steps, each under 20 words, each starting with a verb. If there is nothing to do, give one step that says so and why.
- whatItMeans: 1 or 2 sentences on what this means for the reader.
- isScam: true only when the story is about a scam or fraud that targets people.
- scam: when isScam is true, an object with
    howItWorks: 2 or 3 sentences explaining the trick step by step,
    warningSigns: 2 to 4 short signs to watch for,
    ifTargeted: 2 to 4 steps (for India, include calling 1930 or reporting at cybercrime.gov.in if money was lost),
    advisoryUrl: an official advisory URL ONLY if one appears in the reports, otherwise null.
  When isScam is false, scam must be null.
- confidence: "high" (official source or several reports agree), "medium" (one reliable report), "low" (unclear, thin or conflicting).
- unconfirmed: true for leaks, rumours, "reportedly" or single-source claims that are not confirmed.`;

export function buildStoryPrompt(input: WriterInput): string {
  const lines = [`Category hint: ${input.categoryHint} (${categoryLabel(input.categoryHint)}). Change it if another fits better.`, '', 'REPORTS:'];
  input.sources.slice(0, 5).forEach((s, i) => {
    lines.push(
      `[${i + 1}] ${s.sourceName}${s.official ? ' (official source)' : ''} — published ${s.publishedAt}`,
      `URL: ${s.url}`,
      `Headline: ${s.title}`,
      `Text: ${truncate(s.snippet || '(no text in feed)', 1200)}`,
      ''
    );
  });
  lines.push('Write the TechDaily story card as JSON.');
  return lines.join('\n');
}

const S = (description?: string) => ({ type: 'STRING', ...(description ? { description } : {}) });
const ARR = (min: number, max: number) => ({ type: 'ARRAY', items: { type: 'STRING' }, minItems: min, maxItems: max });

export const STORY_RESPONSE_SCHEMA = {
  type: 'OBJECT',
  properties: {
    headline: S(),
    category: { type: 'STRING', enum: CATEGORY_IDS },
    whatHappened: S(),
    affectsWho: S(),
    whatToDo: ARR(1, 3),
    whatItMeans: S(),
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
    isTech: { type: 'BOOLEAN' },
  },
  required: ['isTech', 'headline', 'category', 'whatHappened', 'affectsWho', 'whatToDo', 'whatItMeans', 'isScam', 'confidence', 'unconfirmed'],
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

/**
 * Validates and cleans the model's JSON. Throws StoryValidationError on anything unusable,
 * including text copied from the reports (10+ word runs).
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
  const whatToDo = strList(o.whatToDo, 'whatToDo', 1, 3);
  const whatItMeans = str(o.whatItMeans, 'whatItMeans', 15, 450);
  const confidence: Confidence = o.confidence === 'high' || o.confidence === 'low' ? o.confidence : 'medium';
  const unconfirmed = o.unconfirmed === true;

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
  const body = [whatHappened, affectsWho, ...whatToDo, whatItMeans, scam?.howItWorks ?? '', ...(scam?.warningSigns ?? []), ...(scam?.ifTargeted ?? [])].join(' \n ');
  const copied = findCopiedRun(body, sourceTexts, 10);
  if (copied) throw new StoryValidationError(`copied text from the report: "${copied}"`);

  return {
    headline,
    category: scam ? 'scams-security' : category,
    whatHappened,
    affectsWho,
    whatToDo,
    whatItMeans,
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

function officialSourceUrl(input: WriterInput): string | null {
  const s = input.sources.find((x) => x.official && isOfficialAdvisoryUrl(x.url));
  return s ? s.url : null;
}

// ---------------------------------------------------------------------------------------------
// Rule-based fallback
// ---------------------------------------------------------------------------------------------

interface Template {
  affects: string;
  todo: string[];
  means: string;
}

const TEMPLATES: Record<CategoryId, Template> = {
  'scams-security': {
    affects: 'People and businesses using the affected apps, devices or online services.',
    todo: [
      'Install the latest updates for your phone, computer and apps.',
      'If a service you use was breached, change that password and turn on two-step verification.',
    ],
    means: 'Security holes are fixed through updates, so keeping your devices and apps updated is the simplest protection.',
  },
  ai: {
    affects: 'People who use AI chatbots and assistants, and companies building with AI.',
    todo: [
      'Nothing urgent — open the original report if you use this AI tool.',
      'Avoid sharing private, health or bank details with AI chatbots.',
    ],
    means: 'AI tools are changing quickly; new features may soon show up in apps you already use.',
  },
  'phones-gadgets': {
    affects: 'People who own, or are planning to buy, the phone or gadget in this story.',
    todo: [
      'If you plan to buy, compare prices across stores and wait for detailed reviews.',
      'If you already own it, check Settings for a software update.',
    ],
    means: 'This helps you make a better choice before your next phone or gadget purchase.',
  },
  'chips-hardware': {
    affects: 'Mainly tech companies and PC builders; over time it can change prices of phones and laptops.',
    todo: ['Nothing to do right now.', 'If you are buying a laptop or PC soon, keep an eye on prices.'],
    means: 'Chips power every phone and laptop, so changes here slowly affect the price and speed of devices you buy.',
  },
  'startups-india': {
    affects: 'Customers, employees and investors of the companies in this story.',
    todo: [
      "Nothing to do if you don't use or work for these companies.",
      "If you use this company's app, watch for changes to prices or services.",
    ],
    means: "It shows where India's tech industry is heading and which services you use may change.",
  },
  innovations: {
    affects: 'No one directly yet — this is new research or early technology.',
    todo: ['Nothing to do — open the original report if you want the details.'],
    means: 'Ideas like this can take years to reach everyday products, but they show what is coming.',
  },
  'money-fintech': {
    affects: 'People who use UPI, banking apps, cards or digital wallets.',
    todo: [
      'Check your bank or UPI app for official notices about this change.',
      'Never share OTPs or PINs, even with someone who says they are from your bank.',
    ],
    means: 'Changes to payments and banking can affect how you pay, borrow or save money.',
  },
  privacy: {
    affects: 'People who use the apps or services mentioned and share personal data with them.',
    todo: [
      "Review app permissions in your phone's Settings.",
      "Turn off location, contacts or microphone access for apps that don't need it.",
    ],
    means: 'Your personal data has value; knowing who collects it helps you stay in control of it.',
  },
  telecom: {
    affects: 'Mobile and broadband users, especially customers of the telecom companies in this story.',
    todo: [
      "Check your operator's app or website for changes to your plan or price.",
      'Compare plans before your next recharge if prices change.',
    ],
    means: 'Changes in telecom affect how much you pay for data and how good your network is.',
  },
  'digital-india': {
    affects: 'People who use government digital services like Aadhaar, UPI, DigiLocker or online portals.',
    todo: [
      'Check the official government website or app for the exact new rule.',
      'Use only official apps and websites for Aadhaar and other government services.',
    ],
    means: "India's digital public services keep changing; knowing the rules helps you use them safely.",
  },
  'ev-mobility': {
    affects: 'People who own or plan to buy an electric vehicle, and users of ride and mobility apps.',
    todo: [
      'If you plan to buy an EV, compare range, charging options and subsidies first.',
      'Nothing urgent — open the original report for full details.',
    ],
    means: 'Electric and smarter vehicles are changing how India travels, and costs may shift as a result.',
  },
  space: {
    affects: 'No one directly yet — this is about space missions and satellite technology.',
    todo: ['Nothing to do — open the original report if you want the details.'],
    means: 'Space technology powers everyday things like maps, weather forecasts and satellite internet.',
  },
  'apps-gaming': {
    affects: 'People who use the apps, games or streaming services in this story.',
    todo: [
      'Update the app from the Play Store or App Store to get the change.',
      'Check the app for any change to its price or subscription plan.',
    ],
    means: 'Apps and games you use every day may look, work or cost different after this change.',
  },
  'health-tech': {
    affects: 'People who use health apps, wearables or online doctor services.',
    todo: [
      'Use health features as a guide, not a replacement for a doctor.',
      'Share health data only with apps and services you trust.',
    ],
    means: 'Technology is making health care easier to reach, but your health data needs care.',
  },
  'jobs-skills': {
    affects: 'People working in, or hoping to join, the tech industry.',
    todo: [
      'If you work in tech, keep your skills and resume up to date.',
      'Learn in-demand skills like AI from trusted free or low-cost courses.',
    ],
    means: 'Tech hiring and skills keep shifting; staying updated helps you stay employable.',
  },
};

const SCAM_TEMPLATE = {
  affects: 'Anyone who gets calls, SMS, WhatsApp messages or emails from strangers — especially people who use UPI or net banking.',
  todo: [
    "Don't click links or share OTPs, PINs or passwords with anyone who contacts you first.",
    "Check the claim yourself in the official app or on the company's official website.",
    'If you lost money, call 1930 or report at cybercrime.gov.in right away.',
  ],
  means: 'Scammers keep inventing new stories to rush people into paying. Slowing down and checking before you act protects you.',
  scam: (advisoryUrl: string | null): ScamDetails => ({
    howItWorks:
      'Scammers usually pretend to be someone you trust, create panic or a tempting offer, and push you to act fast — pay money, share a code, or install an app. Open the original report for the exact steps used in this case.',
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

function joinNames(names: string[]): string {
  const u = [...new Set(names)];
  if (u.length <= 1) return u[0] ?? 'A news outlet';
  if (u.length === 2) return `${u[0]} and ${u[1]}`;
  return `${u[0]}, ${u[1]} and ${u.length - 2} other outlet${u.length - 2 > 1 ? 's' : ''}`;
}

/** Card for a cluster without AI: always valid, low confidence, needs enrichment. */
export function fallbackStory(input: WriterInput): WrittenStory {
  const lead = input.sources[0];
  const headline = truncate(cleanHeadline(lead?.title || 'Tech news update', lead?.sourceName), 110);
  const allText = input.sources.map((s) => `${s.title} ${s.snippet}`).join(' ');
  const { category: classified } = classify(input.sources.map((s) => s.title).join(' · '), allText, input.categoryHint);
  const category = classified;
  const isScam = category === 'scams-security' && looksLikeScam(input.sources.map((s) => s.title).join(' '));
  const names = joinNames(input.sources.map((s) => s.sourceName));
  const whatHappened = `${names} reported: ${headline.replace(/[.!?…]+$/, '')}. This short version was written automatically — open the original report for full details.`;

  let affectsWho: string;
  let whatToDo: string[];
  let whatItMeans: string;
  let scam: ScamDetails | null = null;
  if (isScam) {
    affectsWho = SCAM_TEMPLATE.affects;
    whatToDo = [...SCAM_TEMPLATE.todo];
    whatItMeans = SCAM_TEMPLATE.means;
    scam = SCAM_TEMPLATE.scam(officialSourceUrl(input));
  } else {
    const t = TEMPLATES[category];
    affectsWho = t.affects;
    whatToDo = [...t.todo];
    whatItMeans = t.means;
    if (category === 'scams-security') {
      const hit = DEVICE_UPDATE.find(([re]) => re.test(allText.slice(0, 600)));
      if (hit) whatToDo = [hit[1], whatToDo[1]];
    }
  }

  return {
    headline,
    category,
    whatHappened,
    affectsWho,
    whatToDo,
    whatItMeans,
    scam,
    confidence: 'low',
    unconfirmed: looksUnconfirmed(input.sources.map((s) => s.title).join(' ')),
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
}

export interface WriterStats {
  aiCalls: number;
  aiOk: number;
  aiInvalid: number;
  aiErrors: number;
  fallbacks: number;
  rateLimited: boolean;
}

export class StoryWriter {
  private apiKey?: string;
  readonly model: string;
  private timeoutMs: number;
  private fetchFn: typeof fetch;
  private useSchema = true;
  readonly stats: WriterStats = { aiCalls: 0, aiOk: 0, aiInvalid: 0, aiErrors: 0, fallbacks: 0, rateLimited: false };

  constructor(cfg: StoryWriterConfig = {}) {
    this.apiKey = cfg.apiKey ?? process.env.GEMINI_API_KEY;
    this.model = cfg.model || process.env.GEMINI_MODEL || DEFAULT_GEMINI_MODEL;
    this.timeoutMs = cfg.timeoutMs ?? 30000;
    this.fetchFn = cfg.fetchFn ?? (globalThis.fetch as typeof fetch);
  }

  hasApiKey(): boolean {
    return Boolean(this.apiKey);
  }

  /** True when another Gemini call could be made right now. */
  aiAvailable(): boolean {
    return this.hasApiKey() && geminiBudgetLeft();
  }

  /**
   * Writes the card. With `allowFallback=false` returns null instead of a fallback card when the
   * AI is unavailable or fails (used for re-enrichment, where a new fallback would change nothing).
   */
  async write(input: WriterInput, allowFallback = true): Promise<WrittenStory | null> {
    if (this.hasApiKey() && (await takeGeminiSlot())) {
      try {
        const out = await this.callGemini(input);
        this.stats.aiOk++;
        return out;
      } catch (e: any) {
        if (e instanceof StoryValidationError) this.stats.aiInvalid++;
        else this.stats.aiErrors++;
        console.warn(`[StoryWriter] AI failed for ${input.storyId}: ${e?.message || e}`);
      }
    }
    if (!allowFallback) return null;
    this.stats.fallbacks++;
    return fallbackStory(input);
  }

  private async callGemini(input: WriterInput, retried = false): Promise<WrittenStory> {
    this.stats.aiCalls++;
    const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(this.model)}:generateContent`;
    const generationConfig: Record<string, unknown> = {
      responseMimeType: 'application/json',
      temperature: 0.2,
      maxOutputTokens: 1400,
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
          contents: [{ role: 'user', parts: [{ text: buildStoryPrompt(input) }] }],
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
        return this.callGemini(input, true);
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
    return validateStoryJson(parsed, input, this.model);
  }
}
