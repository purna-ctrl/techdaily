/**
 * "Purely tech" gate. TechDaily only carries technology news (any tech field). Feeds like ET
 * Government, ET HealthWorld or ET HR also publish politics, sports, celebrity, stock-market and
 * plain business stories; this keyword heuristic drops those before clustering, and is also used to
 * find non-tech stories already stored (ingest cleanup + `purge-non-tech` maintenance job).
 *
 * When Gemini writes a card it also answers `isTech`; `false` discards the story (story-writer.ts).
 */

const esc = (s: string) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const wordRe = (words: string[]) => new RegExp(`\\b(?:${words.map(esc).join('|')})\\b`, 'gi');

/** Technology subjects (concepts, products, platforms). One hit means "this is about tech". */
const TECH_SUBJECTS = [
  'tech', 'technology', 'technologies', 'technological', 'techie', 'techies', 'software', 'hardware', 'app', 'apps',
  'application', 'internet', 'online', 'digital', 'digitally', 'digitisation', 'digitization', 'cyber', 'cybersecurity',
  'ai', 'a.i.', 'artificial intelligence', 'genai', 'generative', 'llm', 'llms', 'chatbot', 'chatbots', 'machine learning',
  'deep learning', 'algorithm', 'algorithms', 'automation', 'robot', 'robots', 'robotics', 'drone', 'drones',
  'smartphone', 'smartphones', 'phone', 'phones', 'mobile', 'laptop', 'laptops', 'computer', 'computers', 'computing',
  'pc', 'tablet', 'gadget', 'gadgets', 'device', 'devices', 'wearable', 'wearables', 'smartwatch', 'earbuds', 'chip',
  'chips', 'chipmaker', 'semiconductor', 'semiconductors', 'processor', 'gpu', 'cpu', 'data centre', 'data center',
  'data centres', 'data centers', 'cloud', 'saas', 'server', 'servers', 'personal data', 'database', 'dataset', 'datasets',
  'website', 'web', 'browser', 'e-commerce', 'ecommerce', 'quick commerce', 'startup',
  'startups', 'fintech', 'edtech', 'healthtech', 'medtech', 'agritech', 'deeptech', 'spacetech', 'upi', 'payment app',
  'payments app', 'wallet', 'crypto', 'cryptocurrency', 'bitcoin', 'blockchain', 'cbdc', 'digital rupee', 'net banking',
  'telecom', '5g', '4g', '6g', 'broadband', 'wi-fi', 'wifi', 'spectrum', 'satellite', 'satellites', 'rocket', 'rockets',
  'space', 'spaceflight', 'spacecraft', 'space mission', 'launch vehicle', 'solar array', 'interceptor', 'interceptors', 'isro', 'nasa', 'spacex', 'gaganyaan', 'chandrayaan', 'orbit',
  'ev', 'evs', 'electric vehicle', 'electric vehicles', 'electric car', 'electric cars', 'electric scooter',
  'electric scooters', 'electric truck', 'electric trucks', 'electric tractor', 'electric bus', 'electric buses',
  'e-bus', 'e-buses', 'electric suv', 'electric motorcycle', 'electric motorcycles', 'e-motorcycle', 'e-bike', 'e-bikes',
  'electric two-wheeler', 'electric two-wheelers', 'e2w', 'electric air taxi', 'battery', 'batteries', 'battery-swapping',
  'charging', 'charger', 'self-driving', 'autonomous', 'driverless', 'robotaxi', 'fastag', 'gaming', 'gamers',
  'video game', 'video games', 'mobile game', 'game studio', 'esports', 'console', 'playstation', 'xbox', 'nintendo', 'streaming', 'ott', 'telemedicine',
  'telehealth', 'abha', 'aadhaar', 'digilocker', 'ondc', 'cowin', 'umang', 'dpdp', 'it rules', 'it act', 'meity',
  'encryption', 'malware', 'ransomware', 'phishing', 'ddos', 'cyberattack', 'cyberattacks', 'cyber attack', 'scam',
  'scams', 'scammers', 'smishing', 'vishing', 'digital arrest', 'hack', 'hacked', 'hacker', 'hackers', 'breach', 'data breach',
  'vulnerability', 'spyware', 'deepfake', 'deepfakes', 'quantum', 'fusion', 'fusion power', 'superconductivity',
  'superconductor', 'superconductors', 'gene therapy', 'gene editing', 'crispr', 'nanotech', 'nanotechnology',
  'nuclear reactor', 'reactor', 'patent', 'engineers',
  'engineering', 'coding', 'developer', 'developers', 'programmer', 'it services', 'it sector', 'it firm', 'it firms',
  'it company', 'it companies', 'gcc', 'gccs', 'global capability centre', 'global capability center', 'tech jobs',
  'upskilling', 'reskilling', 'ai skills', 'electronics', 'iot', 'sensor', 'sensors', 'camera',
  'gps', 'navic', 'bluetooth', 'otp', 'sim', 'esim', 'social media', 'search engine', 'email', 'password', 'passwords',
  'privacy', 'surveillance', 'facial recognition', 'robotic', 'remote patient monitoring', 'remote monitoring',
  'smart meter', 'smart meters', 'smart metering', 'analytics', 'agristack', 'digital id', 'digitised', 'digitalisation',
  'digitalization', 'biometric', 'biometrics', '3d', 'virtual reality', 'vr', 'ar',
  'augmented reality', 'metaverse', 'smart tv', 'smartphone app', 'e-governance', 'qr code', 'digital payments',
  'scam call', 'cyber fraud', 'online fraud', 'fraud app', 'loan app', 'software update', 'beta',
];

/** Tech companies / products by name (count as tech, but not enough to rescue a stock-only story). */
const TECH_NAMES = [
  'google', 'alphabet', 'apple', 'iphone', 'ipad', 'mac', 'macbook', 'microsoft', 'windows', 'amazon', 'aws', 'meta',
  'facebook', 'instagram', 'whatsapp', 'youtube', 'android', 'ios', 'samsung', 'galaxy s', 'galaxy z', 'pixel', 'oneplus', 'xiaomi',
  'redmi', 'realme', 'oppo', 'vivo', 'motorola', 'nokia', 'nothing', 'nvidia', 'intel', 'amd', 'qualcomm', 'tsmc',
  'mediatek', 'arm', 'openai', 'chatgpt', 'gemini', 'claude', 'anthropic', 'copilot', 'deepseek', 'perplexity', 'grok',
  'xai', 'tesla', 'byd', 'ather', 'ola electric', 'uber', 'ola', 'rapido', 'swiggy', 'zomato', 'zepto', 'blinkit',
  'flipkart', 'meesho', 'paytm', 'phonepe', 'google pay', 'razorpay', 'jio', 'airtel', 'vodafone idea', 'bsnl', 'trai',
  'starlink', 'netflix', 'spotify', 'jiohotstar', 'hotstar', 'x', 'twitter', 'telegram', 'snapchat', 'tiktok', 'roblox',
  'bgmi', 'krafton', 'nazara', 'infosys', 'tcs', 'wipro', 'hcltech', 'tech mahindra', 'cognizant', 'accenture', 'ibm',
  'oracle', 'salesforce', 'adobe', 'sap', 'cisco', 'dell', 'hp', 'lenovo', 'asus', 'acer', 'sony', 'lg', 'huawei',
  'npci', 'uidai', 'nasscom', 'cert-in', 'sarvam', 'krutrim', 'byju', 'byjus', 'unacademy', 'physicswallah', 'skyroot',
  'agnikul', 'waymo', 'zoho', 'freshworks', 'dream11', 'mpl', 'linkedin', 'github', 'reddit', 'discord',
  'cloudflare', 'akamai', 'mobikwik', 'pine labs', 'zerodha', 'groww', 'cred', 'ideaforge', 'pixxel', 'ultrahuman',
];

/** Plainly non-tech subjects. */
const NON_TECH: Array<[string, RegExp]> = [
  [
    'politics',
    wordRe([
      'election', 'elections', 'poll results', 'assembly polls', 'bypoll', 'bypolls', 'exit poll', 'exit polls', 'bjp',
      'congress party', 'aap', 'tmc', 'dmk', 'aiadmk', 'shiv sena', 'ncp', 'rjd', 'jdu', 'samajwadi', 'chief minister',
      'mla', 'mlas', 'mps', 'lok sabha', 'rajya sabha', 'campaign rally', 'manifesto', 'opposition leader',
      'cabinet reshuffle', 'reshuffle', 'reshuffles', 'ias officers', 'ips officers', 'coalition', 'vote count',
      'voters', 'electoral', 'ceasefire', 'war', 'defence deal', 'troops',
      'diplomatic', 'bilateral', 'summit', 'trade deal', 'trade ties', 'tariffs', 'sanctions', 'protest', 'protests',
      'riots', 'census', 'supreme court verdict', 'bail',
    ]),
  ],
  [
    'sports',
    wordRe([
      'cricket', 'ipl', 't20', 't20i', 'odi', 'test match', 'wicket', 'wickets', 'innings', 'bcci', 'world cup', 'football',
      'fifa', 'premier league', 'la liga', 'tennis', 'wimbledon', 'olympics', 'olympic', 'hockey', 'kabaddi', 'badminton',
      'formula 1', 'f1 race', 'grand prix', 'golf', 'nba', 'nfl', 'squad', 'tournament', 'semifinal', 'semi-final',
      'final score', 'medal', 'medals', 'athlete', 'athletes', 'batter', 'bowler', 'century', 'hat-trick',
    ]),
  ],
  [
    'celebrity',
    wordRe([
      'bollywood', 'tollywood', 'hollywood', 'actor', 'actress', 'celebrity', 'celebrities', 'box office', 'film review',
      'movie review', 'trailer', 'star cast', 'wedding', 'married', 'divorce', 'dating', 'red carpet', 'oscars', 'grammy',
      'grammys', 'emmys', 'bigg boss', 'reality show', 'singer', 'rapper', 'concert', 'album', 'web series review',
      'marvel', 'star trek', 'star wars', 'mourns', 'tributes', 'obituary', 'episode', 'season finale', 'tv series',
      'tv show', 'sitcom', 'anime',
    ]),
  ],
  [
    // Share-price / trading stories: out unless the title has a tech SUBJECT.
    'markets',
    wordRe([
      'sensex', 'nifty', 'share price', 'share prices', 'shares rise', 'shares fall', 'shares jump', 'shares surge',
      'shares slump', 'shares drop', 'shares gain', 'shares tank', 'stock price', 'stocks to buy', 'stock to buy',
      'target price', 'price targets', 'brokerage', 'buy rating', 'sell rating', 'multibagger', 'stock split',
      'bonus issue', 'dividend', 'market cap', 'm-cap', 'mcap', 'gmp', 'grey market premium', 'rights issue', 'bearish',
      'bullish', 'stake sale', 'sells stake', 'pledges', 'block deal', 'share sale', 'gold price', 'gold prices',
      'silver price', 'crude', 'oil prices', 'forex reserves', 'rupee falls', 'rupee rises', 'bond yields', 'inflation',
      'repo rate', 'gdp',
    ]),
  ],
  [
    // Financial results: out unless the title names a tech company/product or a tech subject.
    'results',
    wordRe([
      'q1', 'q2', 'q3', 'q4', 'q1 results', 'q2 results', 'q3 results', 'q4 results', 'quarterly results', 'net profit',
      'ebitda', 'revenue up', 'profit rises', 'profit falls', 'profit climbs', 'posts profit', 'posts loss',
      'profitability', 'turns profitable', 'fy26', 'fy27', 'fy28', 'yoy',
    ]),
  ],
  [
    'other',
    wordRe([
      'horoscope', 'astrology', 'recipe', 'recipes', 'weather', 'monsoon', 'rainfall', 'heatwave', 'cyclone', 'flood',
      'floods', 'earthquake', 'murder', 'murdered', 'stabbed', 'accident', 'road accident', 'crash kills', 'rape',
      'real estate', 'property prices', 'housing sales', 'fmcg', 'apparel', 'fashion', 'jewellery', 'tourism',
      'pilgrims', 'temple', 'festival', 'pandemic treaty', 'ebola', 'vaccine', 'vaccines', 'self-medication',
      'weight-loss injections', 'bonus for', 'psu employees', 'wage deals', 'airline', 'airlines', 'hotel', 'hotels',
      'shipbuilding', 'corvette', 'expressway', 'expressways', 'highway', 'highways', 'steel', 'cement', 'textile',
    ]),
  ],
];

const TECH_SUBJECT_RE = wordRe(TECH_SUBJECTS);
const TECH_NAME_RE = new RegExp(
  // Short brand names that are also ordinary words only count in their usual capitalisation.
  `\\b(?:${TECH_NAMES.filter((n) => !['x', 'nothing', 'arm', 'mac', 'ola', 'lg', 'hp', 'meta', 'sap', 'mpl'].includes(n)).map(esc).join('|')})\\b`,
  'gi'
);
const TECH_NAME_CASED_RE = /\b(?:X|Nothing|Arm|ARM|Mac|Ola|LG|HP|Meta|SAP|MPL)\b/g;

function count(re: RegExp, text: string): number {
  re.lastIndex = 0;
  return (text.match(re) ?? []).length;
}

export interface TechVerdict {
  isTech: boolean;
  /** Tech subject hits (title counts 3, body 1). */
  subjectScore: number;
  /** Tech company/product name hits (title 3, body 1). */
  nameScore: number;
  /** Non-tech signals found in the title (and body, weighted lower). */
  nonTech: string[];
  reason: string;
}

export interface TechCheckOptions {
  /**
   * The source is a mixed beat (government, health, HR, auto...). Its items must show a positive
   * tech signal; items from tech-native feeds are kept unless they look clearly non-tech.
   */
  mixedSource?: boolean;
}

/**
 * Heuristic tech gate for one report or story.
 *
 *  - stock-market-only: a markets signal in the title and no tech SUBJECT in the title (a company
 *    name alone does not count: "Infosys shares rise 3%" is out, "Nvidia shares jump on new AI chip" is in).
 *  - financial results: a results signal (Q2, net profit, YoY...) with neither a tech subject nor a
 *    tech company name in the title ("MobiKwik posts Q2 profit" is out, "Apple's record Q4 iPhone sales" is in).
 *  - non-tech subject (politics, sports, celebrity, other): a signal in the title and no tech signal
 *    in the title, and at most a faint one in the body.
 *  - mixed-beat sources: no tech signal at all in title or body is out.
 */
export function techVerdict(title: string, body = '', opts: TechCheckOptions = {}): TechVerdict {
  const t = title || '';
  const b = (body || '').slice(0, 1200);
  const tSub = count(TECH_SUBJECT_RE, t);
  const bSub = count(TECH_SUBJECT_RE, b);
  const tName = count(TECH_NAME_RE, t) + count(TECH_NAME_CASED_RE, t);
  const bName = count(TECH_NAME_RE, b) + count(TECH_NAME_CASED_RE, b);
  const subjectScore = tSub * 3 + bSub;
  const nameScore = tName * 3 + bName;
  const titleNonTech = NON_TECH.filter(([, re]) => count(re, t) > 0).map(([k]) => k);
  const bodyNonTech = NON_TECH.filter(([, re]) => count(re, b) >= 2).map(([k]) => k);
  const nonTech = [...new Set([...titleNonTech, ...bodyNonTech])];
  const v = (isTech: boolean, reason: string): TechVerdict => ({ isTech, subjectScore, nameScore, nonTech, reason });

  if (titleNonTech.includes('markets') && tSub === 0) return v(false, 'stock-market-only');
  if (titleNonTech.includes('results') && tSub + tName === 0) return v(false, 'financial results, no tech angle');
  const otherTitle = titleNonTech.filter((k) => k !== 'markets' && k !== 'results');
  if (otherTitle.length && tSub + tName === 0 && bSub + bName <= 2) return v(false, `non-tech: ${otherTitle.join(', ')}`);
  if (opts.mixedSource && tSub + tName === 0 && bSub + bName <= 1) return v(false, 'no tech signal (mixed-beat source)');
  if (opts.mixedSource && otherTitle.length && tSub === 0 && bSub <= 2) return v(false, `non-tech: ${otherTitle.join(', ')}`);
  return v(true, 'tech');
}

export function isTechItem(title: string, body = '', opts: TechCheckOptions = {}): boolean {
  return techVerdict(title, body, opts).isTech;
}

/** Minimal story shape the stored-story check needs. */
export interface TechCheckStory {
  headline: string;
  whatHappened?: string;
  sources: Array<{ title?: string }>;
}

/**
 * Stored-story check (conservative: used to DELETE). A story is non-tech only when its headline
 * AND every source title fail the gate, judged against the written summary as the body.
 */
export function storyTechVerdict(s: TechCheckStory): TechVerdict {
  const titles = [s.headline, ...s.sources.map((x) => x.title || '')].filter(Boolean);
  const body = s.whatHappened || '';
  let last: TechVerdict | undefined;
  for (const t of titles) {
    const v = techVerdict(t, body);
    if (v.isTech) return v;
    last = v;
  }
  return last ?? techVerdict(s.headline, body);
}

export function isNonTechStory(s: TechCheckStory): boolean {
  return !storyTechVerdict(s).isTech;
}
