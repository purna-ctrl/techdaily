/**
 * Feeds read by the v2 stories pipeline. Every URL here returned valid, parseable RSS/Atom with
 * recent items when checked with curl + FeedParser on 2026-11-01 (see SETUP-GITHUB.md for the list
 * that did NOT work: Moneycontrol, PIB, CERT-In, NPCI, SEBI (no dates), Digit, 91mobiles, BGR).
 *
 * `category` is only the feed's beat (a tie-breaker); each story's category is picked per story.
 */
import { TrustedSourceConfig } from '../config/sources';
import { CategoryId } from './categories';

export type FeedKind = 'global' | 'india' | 'advisory' | 'official';

export interface StoryFeed extends TrustedSourceConfig {
  category: CategoryId;
  kind: FeedKind;
  /** Official body / vendor (regulator, CERT, company newsroom). */
  official?: boolean;
  /** When set, only items whose title (or description) matches are used. */
  includePattern?: RegExp;
}

const f = (
  sourceId: string,
  sourceName: string,
  domain: string,
  feedUrl: string,
  category: CategoryId,
  kind: FeedKind,
  extra: Partial<StoryFeed> = {}
): StoryFeed => ({
  sourceId,
  sourceName,
  domain,
  feedUrl,
  category,
  kind,
  defaultCategory: category,
  enabled: true,
  trustLevel: kind === 'official' || kind === 'advisory' ? 'high' : 'verified',
  region: kind === 'india' ? 'IN' : 'GLOBAL',
  maxItemsPerRun: 12,
  ...extra,
});

const RBI_PATTERN =
  /\b(fraud|frauds|caution|cautions|cautioned|digital|payment|payments|upi|card|cards|cyber|fintech|kyc|loan app|unauthori[sz]ed|fake|scam|customer protection|ombudsman|e-rupee|cbdc|mule|alert list|forex|deposit insurance|data)\b/i;

export const STORY_FEEDS: StoryFeed[] = [
  // ---- India ----
  f('gadgets360', 'Gadgets 360', 'gadgets360.com', 'https://feeds.feedburner.com/gadgets360-latest', 'phones-gadgets', 'india', { maxItemsPerRun: 15 }),
  f('medianama', 'MediaNama', 'medianama.com', 'https://www.medianama.com/feed/', 'privacy', 'india'),
  f('et-tech', 'ET Tech', 'economictimes.indiatimes.com', 'https://economictimes.indiatimes.com/tech/rssfeeds/13357270.cms', 'startups-india', 'india', { maxItemsPerRun: 15 }),
  f('et-bfsi', 'ET BFSI', 'bfsi.economictimes.indiatimes.com', 'https://bfsi.economictimes.indiatimes.com/rss/topstories', 'money-fintech', 'india'),
  f('et-telecom', 'ET Telecom', 'telecom.economictimes.indiatimes.com', 'https://telecom.economictimes.indiatimes.com/rss/topstories', 'phones-gadgets', 'india', { maxItemsPerRun: 8 }),
  f('the-hindu-tech', 'The Hindu', 'thehindu.com', 'https://www.thehindu.com/sci-tech/technology/feeder/default.rss', 'innovations', 'india'),
  f('the-hindu-gadgets', 'The Hindu', 'thehindu.com', 'https://www.thehindu.com/sci-tech/technology/gadgets/feeder/default.rss', 'phones-gadgets', 'india', { maxItemsPerRun: 8 }),
  f('the-hindu-science', 'The Hindu', 'thehindu.com', 'https://www.thehindu.com/sci-tech/science/feeder/default.rss', 'innovations', 'india', { maxItemsPerRun: 8 }),
  f('livemint-tech', 'Mint', 'livemint.com', 'https://www.livemint.com/rss/technology', 'startups-india', 'india'),
  f('indian-express-tech', 'The Indian Express', 'indianexpress.com', 'https://indianexpress.com/section/technology/feed/', 'phones-gadgets', 'india'),
  f('inc42', 'Inc42', 'inc42.com', 'https://inc42.com/feed/', 'startups-india', 'india'),
  f('yourstory', 'YourStory', 'yourstory.com', 'https://yourstory.com/feed', 'startups-india', 'india'),
  f('entrackr', 'Entrackr', 'entrackr.com', 'https://entrackr.com/rss', 'startups-india', 'india'),
  // ---- Official advisories / regulators ----
  f('rbi-press', 'Reserve Bank of India', 'rbi.org.in', 'https://www.rbi.org.in/pressreleases_rss.xml', 'money-fintech', 'advisory', {
    region: 'IN',
    official: true,
    includePattern: RBI_PATTERN,
  }),
  f('cisa-alerts', 'CISA', 'cisa.gov', 'https://www.cisa.gov/cybersecurity-advisories/all.xml', 'scams-security', 'advisory', { official: true, maxItemsPerRun: 4 }),
  f('google-security-blog', 'Google Security Blog', 'security.googleblog.com', 'https://security.googleblog.com/feeds/posts/default', 'scams-security', 'official', { official: true, maxItemsPerRun: 4 }),
  // ---- Security & scams ----
  f('the-hacker-news', 'The Hacker News', 'thehackernews.com', 'https://feeds.feedburner.com/TheHackersNews', 'scams-security', 'global'),
  f('bleepingcomputer', 'BleepingComputer', 'bleepingcomputer.com', 'https://www.bleepingcomputer.com/feed/', 'scams-security', 'global'),
  f('krebs', 'Krebs on Security', 'krebsonsecurity.com', 'https://krebsonsecurity.com/feed/', 'scams-security', 'global', { maxItemsPerRun: 5 }),
  f('malwarebytes', 'Malwarebytes Labs', 'malwarebytes.com', 'https://www.malwarebytes.com/blog/feed/index.xml', 'scams-security', 'global', { maxItemsPerRun: 8 }),
  f('welivesecurity', 'ESET WeLiveSecurity', 'welivesecurity.com', 'https://feeds.feedburner.com/eset/blog', 'scams-security', 'global', { maxItemsPerRun: 6 }),
  // ---- Privacy ----
  f('eff', 'EFF', 'eff.org', 'https://www.eff.org/rss/updates.xml', 'privacy', 'global', { maxItemsPerRun: 5 }),
  // ---- Global tech ----
  f('the-verge', 'The Verge', 'theverge.com', 'https://www.theverge.com/rss/index.xml', 'phones-gadgets', 'global'),
  f('techcrunch', 'TechCrunch', 'techcrunch.com', 'https://techcrunch.com/feed/', 'ai', 'global'),
  f('techcrunch-fintech', 'TechCrunch', 'techcrunch.com', 'https://techcrunch.com/category/fintech/feed/', 'money-fintech', 'global', { maxItemsPerRun: 6 }),
  f('ars-technica', 'Ars Technica', 'arstechnica.com', 'https://feeds.arstechnica.com/arstechnica/index', 'innovations', 'global'),
  f('wired', 'Wired', 'wired.com', 'https://www.wired.com/feed/rss', 'innovations', 'global'),
  f('engadget', 'Engadget', 'engadget.com', 'https://www.engadget.com/rss.xml', 'phones-gadgets', 'global'),
  f('gsmarena', 'GSMArena', 'gsmarena.com', 'https://www.gsmarena.com/rss-news-reviews.php3', 'phones-gadgets', 'global'),
  f('tomshardware', "Tom's Hardware", 'tomshardware.com', 'https://www.tomshardware.com/feeds/all', 'chips-hardware', 'global'),
  f('mit-tech-review', 'MIT Technology Review', 'technologyreview.com', 'https://www.technologyreview.com/feed/', 'ai', 'global', { maxItemsPerRun: 6 }),
  f('sciencedaily-tech', 'ScienceDaily', 'sciencedaily.com', 'https://www.sciencedaily.com/rss/top/technology.xml', 'innovations', 'global', { maxItemsPerRun: 6 }),
  // ---- Company newsrooms (from v1) ----
  f('openai-news', 'OpenAI', 'openai.com', 'https://openai.com/news/rss.xml', 'ai', 'official', { official: true, maxItemsPerRun: 6 }),
  f('google-ai-blog', 'Google', 'blog.google', 'https://blog.google/technology/ai/rss/', 'ai', 'official', { official: true, maxItemsPerRun: 6 }),
  f('microsoft-blog', 'Microsoft', 'blogs.microsoft.com', 'https://blogs.microsoft.com/feed/', 'ai', 'official', { official: true, maxItemsPerRun: 5 }),
  f('apple-newsroom', 'Apple Newsroom', 'apple.com', 'https://www.apple.com/newsroom/rss-feed.rss', 'phones-gadgets', 'official', { official: true, maxItemsPerRun: 5 }),
  f('nvidia-newsroom', 'NVIDIA', 'nvidianews.nvidia.com', 'https://nvidianews.nvidia.com/releases.xml', 'chips-hardware', 'official', {
    official: true,
    maxItemsPerRun: 5,
    additionalDomains: ['blogs.nvidia.com'],
  }),
  f('meta-newsroom', 'Meta', 'about.fb.com', 'https://about.fb.com/news/feed/', 'ai', 'official', { official: true, maxItemsPerRun: 5 }),
  f('nasa', 'NASA', 'nasa.gov', 'https://www.nasa.gov/feed/', 'innovations', 'official', { official: true, maxItemsPerRun: 4 }),
  f('github-blog', 'GitHub', 'github.blog', 'https://github.blog/feed/', 'ai', 'official', { official: true, maxItemsPerRun: 3 }),
  f('aws-blog', 'AWS', 'aws.amazon.com', 'https://aws.amazon.com/blogs/aws/feed/', 'innovations', 'official', { official: true, maxItemsPerRun: 2 }),
];

/**
 * Shopping lists, deal round-ups, puzzles, newsletters and live blogs are not news events; they are
 * skipped before clustering.
 */
const LOW_VALUE: RegExp[] = [
  /^best\b/i,
  /\bbest\b.{0,60}\b(under|below)\s*(rs\.?|₹|inr)/i,
  /\b(deals|doorbuster|price cut|price drop|discounts?|coupons?|promo codes?|bank offers?|cashback offers?)\b/i,
  /\b(black friday|cyber monday|prime day|great indian festival|big billion days?)\b/i,
  /^get\b.{0,80}\bfor\s*(₹|rs\.?)\s?\d/i,
  /\b(wordle|crossword|quordle|strands|connections)\b.{0,40}\b(hints?|answers?|clues?)\b/i,
  /\b(horoscope|quiz|giveaway|sweepstakes)\b/i,
  /\b(live blog|live updates|how to watch|where to watch)\b/i,
  /^(the download|this week in|week in review|weekly recap|podcast|newsletter)\b/i,
  /\bspecial newsletter\b/i,
  /\b\d+\s+days?\s+left\b/i,
  /\b(sponsored|partner content|advertorial)\b/i,
  /\b(review|hands-on|first look|unboxing)\s*[:|–—-]/i,
  /\breview\s*$/i,
  /\bvs\.?\s/i,
  /\btracker\s+20\d\d\b/i,
  /^\d+\s+(best|ways|things|tips|settings|apps|gadgets|reasons)\b/i,
  /\bbest\b.{0,40}\b20\d\d\b/i,
  /^apod\b/i,
];

export function isLowValueTitle(title: string): boolean {
  return LOW_VALUE.some((re) => re.test(title || ''));
}

export function getStoryFeed(id: string): StoryFeed | undefined {
  return STORY_FEEDS.find((s) => s.sourceId === id && s.enabled);
}

/** Domains whose pages count as an "official advisory" link on scam stories. */
export const OFFICIAL_ADVISORY_HOSTS = [
  'cert-in.org.in',
  'rbi.org.in',
  'sachet.rbi.org.in',
  'cybercrime.gov.in',
  'sancharsaathi.gov.in',
  'pib.gov.in',
  'npci.org.in',
  'sebi.gov.in',
  'meity.gov.in',
  'i4c.mha.gov.in',
  'mha.gov.in',
  'dot.gov.in',
  'trai.gov.in',
  'incometax.gov.in',
  'uidai.gov.in',
  'cisa.gov',
  'ftc.gov',
  'ncsc.gov.uk',
  'support.apple.com',
  'support.google.com',
  'security.googleblog.com',
  'msrc.microsoft.com',
  'faq.whatsapp.com',
];

export function isOfficialAdvisoryUrl(url: string | null | undefined): boolean {
  if (!url) return false;
  try {
    const u = new URL(url);
    if (u.protocol !== 'https:' && u.protocol !== 'http:') return false;
    const h = u.hostname.toLowerCase();
    return OFFICIAL_ADVISORY_HOSTS.some((d) => h === d || h.endsWith('.' + d));
  } catch {
    return false;
  }
}
