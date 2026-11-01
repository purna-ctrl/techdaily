/**
 * The eight stored story categories (tab order after "Top Stories", which is a ranked mix and never
 * stored). Ids are URL slugs: /c/<id>/.
 */
export const CATEGORIES = [
  { id: 'scams-security', label: 'Scams & Security' },
  { id: 'ai', label: 'AI' },
  { id: 'phones-gadgets', label: 'Phones & Gadgets' },
  { id: 'chips-hardware', label: 'Chips & Hardware' },
  { id: 'startups-india', label: 'Startups & India' },
  { id: 'innovations', label: 'Innovations' },
  { id: 'money-fintech', label: 'Money & Fintech' },
  { id: 'privacy', label: 'Privacy' },
] as const;

export type CategoryId = (typeof CATEGORIES)[number]['id'];
export const CATEGORY_IDS: CategoryId[] = CATEGORIES.map((c) => c.id);
export const TOP_STORIES = { id: 'top-stories', label: 'Top Stories' } as const;

export function isCategoryId(v: unknown): v is CategoryId {
  return typeof v === 'string' && (CATEGORY_IDS as string[]).includes(v);
}

export function categoryLabel(id: string): string {
  return CATEGORIES.find((c) => c.id === id)?.label ?? 'Tech';
}

/** Accepts an id, a label ("Money & Fintech") or a loose spelling ("money and fintech"). */
export function toCategoryId(v: unknown, fallback: CategoryId = 'innovations'): CategoryId {
  if (isCategoryId(v)) return v;
  if (typeof v !== 'string') return fallback;
  const norm = v.toLowerCase().replace(/&/g, 'and').replace(/[^a-z]+/g, ' ').trim();
  for (const c of CATEGORIES) {
    const l = c.label.toLowerCase().replace(/&/g, 'and').replace(/[^a-z]+/g, ' ').trim();
    if (l === norm) return c.id;
  }
  const legacy: Record<string, CategoryId> = {
    'ai and machine learning': 'ai',
    'artificial intelligence': 'ai',
    cybersecurity: 'scams-security',
    security: 'scams-security',
    scams: 'scams-security',
    smartphones: 'phones-gadgets',
    gadgets: 'phones-gadgets',
    phones: 'phones-gadgets',
    hardware: 'chips-hardware',
    chips: 'chips-hardware',
    semiconductors: 'chips-hardware',
    startups: 'startups-india',
    india: 'startups-india',
    companies: 'startups-india',
    science: 'innovations',
    space: 'innovations',
    software: 'innovations',
    cloud: 'innovations',
    fintech: 'money-fintech',
    money: 'money-fintech',
    payments: 'money-fintech',
    privacy: 'privacy',
  };
  return legacy[norm] ?? fallback;
}

// ---------------------------------------------------------------------------------------------
// Keyword classifier (used for the writer's category hint and by the rule-based fallback)
// ---------------------------------------------------------------------------------------------

const KEYWORDS: Record<CategoryId, string[]> = {
  'scams-security': [
    'scam', 'scammer', 'scams', 'fraud', 'fraudster', 'phishing', 'smishing', 'vishing', 'malware', 'ransomware',
    'hack', 'hacked', 'hacker', 'hackers', 'breach', 'leak', 'leaked', 'vulnerability', 'vulnerabilities', 'cve',
    'zero-day', 'exploit', 'exploited', 'patch', 'cyberattack', 'cyber attack', 'cybercrime', 'cyber fraud',
    'digital arrest', 'otp', 'spyware', 'trojan', 'botnet', 'stealer', 'backdoor', 'fake app', 'fake apps',
    'impersonat', 'sim swap', 'kyc fraud', 'sextortion', 'deepfake call', 'security flaw', 'security update',
    'cert-in', 'cisa', 'advisory', 'heist', 'stolen', 'threat actor', 'credential',
  ],
  ai: [
    'ai', 'artificial intelligence', 'chatgpt', 'openai', 'gemini', 'claude', 'anthropic', 'llm', 'chatbot',
    'machine learning', 'generative', 'genai', 'copilot', 'deepseek', 'llama', 'mistral', 'agentic', 'ai agent',
    'ai agents', 'neural', 'sam altman', 'perplexity', 'grok', 'xai', 'sarvam', 'krutrim', 'midjourney',
  ],
  'phones-gadgets': [
    'iphone', 'android', 'smartphone', 'smartphones', 'phone', 'phones', 'galaxy', 'pixel', 'oneplus', 'xiaomi',
    'redmi', 'realme', 'oppo', 'vivo', 'poco', 'motorola', 'nothing phone', 'iqoo', 'lava', 'ipad', 'tablet',
    'laptop', 'macbook', 'smartwatch', 'watch', 'earbuds', 'headphones', 'airpods', 'tv', 'television', 'camera',
    'wearable', 'gadget', 'gadgets', 'console', 'playstation', 'xbox', 'nintendo', 'ios', 'one ui', 'hyperos',
    'price in india', 'launched in india', 'review', 'foldable', 'charger', 'battery',
  ],
  'chips-hardware': [
    'chip', 'chips', 'chipmaker', 'semiconductor', 'semiconductors', 'processor', 'cpu', 'gpu', 'nvidia', 'amd',
    'intel', 'qualcomm', 'snapdragon', 'mediatek', 'dimensity', 'tsmc', 'arm', 'foundry', 'fab', 'wafer', 'ram',
    'dram', 'hbm', 'memory', 'ssd', 'data centre', 'data center', 'server', 'supercomputer', 'motherboard',
    'graphics card', 'rtx', 'radeon', 'ryzen', 'core ultra', 'apple silicon', 'm5', 'micron', 'sk hynix',
  ],
  'startups-india': [
    'startup', 'startups', 'funding', 'raises', 'raised', 'series a', 'series b', 'series c', 'seed round',
    'unicorn', 'ipo', 'valuation', 'founder', 'founders', 'layoffs', 'acquires', 'acquisition', 'india', 'indian',
    'bengaluru', 'bangalore', 'mumbai', 'delhi', 'hyderabad', 'chennai', 'meity', 'zepto', 'swiggy', 'zomato',
    'flipkart', 'meesho', 'ola', 'byju', 'reliance jio', 'jio', 'airtel', 'tata', 'infosys', 'tcs', 'wipro',
    'ondc', 'quick commerce', 'q-commerce', 'edtech', 'ev', 'electric scooter', 'ather',
  ],
  innovations: [
    'research', 'researchers', 'scientists', 'study', 'breakthrough', 'space', 'nasa', 'isro', 'rocket',
    'satellite', 'moon', 'mars', 'quantum', 'robot', 'robots', 'robotics', 'battery tech', 'solar', 'fusion',
    'climate', 'energy', 'biotech', 'drone', 'drones', 'self-driving', 'autonomous', 'invention', 'prototype',
    'telescope', 'physics', 'material', 'medical device', '3d print', 'spacex', 'gaganyaan', 'chandrayaan',
  ],
  'money-fintech': [
    'upi', 'npci', 'rbi', 'reserve bank', 'fintech', 'payment', 'payments', 'paytm', 'phonepe', 'google pay',
    'gpay', 'bhim', 'bank', 'banks', 'banking', 'loan', 'loans', 'credit card', 'debit card', 'wallet', 'emi',
    'interest rate', 'sebi', 'mutual fund', 'stock market', 'demat', 'crypto', 'bitcoin', 'digital rupee', 'cbdc',
    'insurance', 'tax', 'gst', 'income tax', 'rupay', 'neobank', 'lending', 'nbfc', 'money', 'pension',
  ],
  privacy: [
    'privacy', 'personal data', 'data protection', 'dpdp', 'tracking', 'tracker', 'surveillance', 'consent',
    'cookies', 'aadhaar', 'facial recognition', 'location data', 'data broker', 'gdpr', 'end-to-end', 'encryption',
    'encrypted', 'data sharing', 'telemetry', 'ad tracking', 'spy', 'monitoring', 'data retention', 'right to be forgotten',
  ],
};

const COMPILED: Array<[CategoryId, RegExp[]]> = (Object.keys(KEYWORDS) as CategoryId[]).map((cat) => [
  cat,
  KEYWORDS[cat].map((kw) => {
    const esc = kw.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    // "impersonat" is a stem: match as a prefix; everything else as a whole word/phrase.
    return kw === 'impersonat' ? new RegExp(`\\b${esc}`, 'i') : new RegExp(`\\b${esc}\\b`, 'i');
  }),
]);

export interface Classification {
  category: CategoryId;
  scores: Record<CategoryId, number>;
}

/**
 * Weighted keyword classifier: title hits score 3, body hits 1, the source's default category gets
 * +1.5 so a feed's beat breaks ties. Security wins ties with everything (it's the category where a
 * miss costs readers money).
 */
export function classify(title: string, body: string, defaultCategory?: CategoryId): Classification {
  const t = ` ${title} `;
  const b = ` ${body.slice(0, 1500)} `;
  const scores = Object.fromEntries(CATEGORY_IDS.map((c) => [c, 0])) as Record<CategoryId, number>;
  for (const [cat, res] of COMPILED) {
    for (const re of res) {
      if (re.test(t)) scores[cat] += 3;
      else if (re.test(b)) scores[cat] += 1;
    }
  }
  if (defaultCategory) scores[defaultCategory] += 1.5;
  // "India" alone should not pull a phone launch into Startups & India.
  if (scores['phones-gadgets'] >= 3 && scores['startups-india'] <= 4.5) scores['startups-india'] -= 2;
  let best: CategoryId = defaultCategory ?? 'innovations';
  let max = -Infinity;
  for (const cat of CATEGORY_IDS) {
    if (scores[cat] > max || (scores[cat] === max && cat === 'scams-security')) {
      max = scores[cat];
      best = cat;
    }
  }
  if (max < 2 && defaultCategory) best = defaultCategory;
  return { category: best, scores };
}

const SCAM_RE =
  /\b(scam|scams|scammer|scammers|fraud|fraudster|fraudsters|phishing|smishing|vishing|fake|impersonat\w*|digital arrest|sextortion|con|lure|lures|trick|tricks|duped|cheated|swindl\w*|ponzi|investment scheme|otp)\b/i;

/** True when the text describes a scam aimed at people (vs. a technical bug or breach). */
export function looksLikeScam(text: string): boolean {
  return SCAM_RE.test(text);
}

const RUMOUR_RE =
  /\b(reportedly|rumou?r|rumou?red|leak|leaked|leaks|tipped|tipster|could launch|may launch|expected to|said to|sources said|according to sources|unconfirmed|alleged|allegedly|in talks)\b/i;

export function looksUnconfirmed(text: string): boolean {
  return RUMOUR_RE.test(text);
}
