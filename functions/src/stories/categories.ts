/**
 * The fifteen stored story categories (tab order after "Top Stories", which is a ranked mix and never
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
  { id: 'telecom', label: 'Telecom & Internet' },
  { id: 'digital-india', label: 'Digital India' },
  { id: 'ev-mobility', label: 'EVs & Mobility' },
  { id: 'space', label: 'Space Tech' },
  { id: 'apps-gaming', label: 'Apps & Gaming' },
  { id: 'health-tech', label: 'Health Tech' },
  { id: 'jobs-skills', label: 'Tech Jobs & Skills' },
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
    telecom: 'telecom',
    internet: 'telecom',
    'telecom and internet': 'telecom',
    broadband: 'telecom',
    '5g': 'telecom',
    'digital india': 'digital-india',
    govtech: 'digital-india',
    'government tech': 'digital-india',
    ev: 'ev-mobility',
    evs: 'ev-mobility',
    'evs and mobility': 'ev-mobility',
    'electric vehicles': 'ev-mobility',
    mobility: 'ev-mobility',
    'space tech': 'space',
    apps: 'apps-gaming',
    gaming: 'apps-gaming',
    games: 'apps-gaming',
    'apps and gaming': 'apps-gaming',
    'health tech': 'health-tech',
    healthtech: 'health-tech',
    health: 'health-tech',
    jobs: 'jobs-skills',
    skills: 'jobs-skills',
    'tech jobs and skills': 'jobs-skills',
    layoffs: 'jobs-skills',
    companies: 'startups-india',
    science: 'innovations',
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
    'wearable', 'gadget', 'gadgets', 'ios', 'one ui', 'hyperos',
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
    'unicorn', 'ipo', 'valuation', 'founder', 'founders', 'acquires', 'acquisition', 'india', 'indian',
    'bengaluru', 'bangalore', 'mumbai', 'delhi', 'hyderabad', 'chennai', 'meity', 'zepto', 'swiggy', 'zomato',
    'flipkart', 'meesho', 'byju', 'tata', 'quick commerce', 'q-commerce', 'edtech',
  ],
  innovations: [
    'research', 'researchers', 'scientists', 'study', 'breakthrough', 'quantum', 'robot', 'robots', 'robotics',
    'battery tech', 'solar', 'fusion', 'climate', 'energy', 'biotech', 'drone', 'drones', 'invention', 'prototype',
    'physics', 'material', '3d print',
  ],
  'money-fintech': [
    'upi', 'npci', 'rbi', 'reserve bank', 'fintech', 'payment', 'payments', 'paytm', 'phonepe', 'google pay',
    'gpay', 'bhim', 'bank', 'banks', 'banking', 'loan', 'loans', 'credit card', 'debit card', 'wallet', 'emi',
    'interest rate', 'sebi', 'mutual fund', 'stock market', 'demat', 'crypto', 'bitcoin', 'digital rupee', 'cbdc',
    'insurance', 'tax', 'gst', 'income tax', 'rupay', 'neobank', 'lending', 'nbfc', 'money', 'pension',
  ],
  privacy: [
    'privacy', 'personal data', 'data protection', 'dpdp', 'tracking', 'tracker', 'surveillance', 'consent',
    'cookies', 'facial recognition', 'location data', 'data broker', 'gdpr', 'end-to-end', 'encryption',
    'encrypted', 'data sharing', 'telemetry', 'ad tracking', 'spy', 'monitoring', 'data retention', 'right to be forgotten',
  ],
  telecom: [
    'telecom', 'telco', 'telcos', '5g', '4g', '6g', 'broadband', 'fibre', 'fiber', 'ftth', 'jio', 'reliance jio',
    'airtel', 'bharti airtel', 'vodafone idea', 'bsnl', 'mtnl', 'trai', 'department of telecommunications', 'spectrum', 'tariff hike',
    'recharge', 'prepaid', 'postpaid', 'data plan', 'mobile plan', 'network outage', 'outage', 'internet shutdown',
    'satellite internet', 'satcom', 'starlink', 'oneweb', 'kuiper', 'wi-fi', 'wifi', 'mobile network',
    'sim card', 'esim', 'sanchar saathi', 'mobile subscribers', 'broadband subscribers', '5g customers', 'arpu', 'fcc', 'mvno', 'undersea cable', 'submarine cable', 'isp', 'telecom tower',
  ],
  'digital-india': [
    'digital india', 'aadhaar', 'uidai', 'digilocker', 'ondc', 'umang', 'cowin', 'abha', 'meity', 'it rules',
    'it ministry', 'it act', 'dpdp', 'data protection act', 'npci', 'india stack', 'digital public infrastructure',
    'dpi', 'e-governance', 'egovernance', 'govtech', 'indiaai', 'india ai mission', 'bhashini', 'digi yatra',
    'e-kyc', 'ekyc', 'cert-in', 'sahyog', 'blocking order', 'takedown', 'government portal', 'gst portal',
    'agristack', 'pm-wani', 'semicon india', 'digital rupee', 'parivahan', 'vahan', 'mparivahan', 'passport seva',
  ],
  'ev-mobility': [
    'ev', 'evs', 'electric vehicle', 'electric vehicles', 'electric car', 'electric cars', 'electric scooter',
    'electric scooters', 'e-scooter', 'e2w', 'e3w', 'electric two-wheeler', 'electric two-wheelers', 'electric bus',
    'electric buses', 'e-bus', 'e-buses', 'electric truck', 'electric trucks', 'electric tractor', 'electric suv',
    'electric motorcycle', 'electric motorcycles', 'e-motorcycle', 'e-bike', 'e-bikes', 'electric bike', 'ev sales',
    'electric air taxi', 'battery-swapping', 'tesla', 'rivian', 'lucid',
    'byd', 'ather', 'ola electric', 'tata ev', 'nexon ev', 'mahindra be', 'ev charging', 'charger network',
    'charging station', 'charging stations', 'battery swapping', 'battery swap', 'lithium-ion cells',
    'cell manufacturing', 'self-driving', 'autonomous driving', 'driverless', 'robotaxi', 'robotaxis',
    'waymo', 'adas', 'uber', 'ola', 'rapido', 'ride-hailing', 'fastag', 'pm e-drive', 'fame scheme',
  ],
  space: [
    'space', 'isro', 'nasa', 'spacex', 'gaganyaan', 'chandrayaan', 'aditya-l1', 'rocket', 'rockets', 'launch vehicle',
    'pslv', 'gslv', 'lvm3', 'sslv', 'satellite', 'satellites', 'orbit', 'orbital', 'astronaut', 'astronauts',
    'moon', 'lunar', 'mars', 'starship', 'falcon 9', 'blue origin', 'skyroot', 'agnikul', 'in-space', 'inspace',
    'spacecraft', 'space station', 'iss', 'telescope', 'esa', 'navic', 'space startup', 'spaceport',
  ],
  'apps-gaming': [
    'app', 'apps', 'app store', 'play store', 'whatsapp', 'instagram', 'facebook', 'youtube', 'telegram', 'snapchat',
    'threads', 'x app', 'tiktok', 'app ban', 'banned apps', 'game', 'games', 'gaming', 'gamer', 'gamers', 'bgmi',
    'free fire', 'esports', 'e-sports', 'console', 'playstation', 'ps5', 'xbox', 'nintendo', 'switch 2', 'steam',
    'game pass', 'gta', 'roblox', 'fortnite', 'minecraft', 'online gaming', 'real-money gaming', 'ott', 'netflix',
    'jiohotstar', 'prime video', 'spotify', 'subscription price', 'krafton', 'nazara',
  ],
  'health-tech': [
    'health tech', 'healthtech', 'health-tech', 'medtech', 'telemedicine', 'telehealth', 'esanjeevani', 'abha',
    'ayushman bharat digital', 'abdm', 'digital health', 'health app', 'health records', 'wearables', 'heart rate',
    'ecg', 'blood oxygen', 'spo2', 'blood pressure', 'sleep tracking', 'glucose', 'cgm', 'hearing aid',
    'medical ai', 'ai diagnosis', 'diagnostics', 'medical device', 'medical devices', 'fda', 'cdsco', 'surgical robot',
    'hospital software', 'e-pharmacy', 'epharmacy', 'health data', 'fitness tracker', 'oura', 'whoop',
  ],
  'jobs-skills': [
    'layoff', 'layoffs', 'laid off', 'job cuts', 'jobs', 'hiring', 'hires', 'recruitment', 'freshers', 'campus hiring',
    'workforce', 'employees', 'headcount', 'attrition', 'salary', 'salaries', 'appraisal', 'gcc', 'gccs',
    'global capability centre', 'global capability center', 'upskilling', 'reskilling', 'skilling', 'skills',
    'ai skills', 'online course', 'courses', 'certification', 'bootcamp', 'internship', 'h-1b', 'h1b', 'work visa',
    'it services', 'infosys', 'tcs', 'wipro', 'hcltech', 'tech mahindra', 'cognizant', 'accenture', 'nasscom',
    'return to office', 'work from home', 'talent',
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
  // An EV launch ("... Electric SUV launched in India") is EVs & Mobility, not Phones & Gadgets.
  if (scores['ev-mobility'] >= 3 && scores['phones-gadgets'] > 0) scores['phones-gadgets'] -= 2;
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
