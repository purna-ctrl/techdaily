export interface TrustedSourceConfig {
  sourceId: string;
  sourceName: string;
  domain: string; // Base trusted domain, e.g. "aws.amazon.com"
  feedUrl: string; // Official RSS / Atom feed URL
  defaultCategory: string;
  enabled: boolean;
  trustLevel: 'high' | 'verified';
  rateLimitPerMinute?: number;
  /** 'IN' for Indian publishers (drives the app's "India" section), otherwise 'GLOBAL'. */
  region?: SourceRegion;
  /** Max newest items to process per run (protects Gemini quota on very long feeds). */
  maxItemsPerRun?: number;
  /** Extra hostnames this source legitimately links to (still checked with strict suffix matching). */
  additionalDomains?: string[];
}

export type SourceRegion = 'IN' | 'GLOBAL';

export const DEFAULT_MAX_ITEMS_PER_RUN = 15;

export function getSourceRegion(source: TrustedSourceConfig): SourceRegion {
  return source.region === 'IN' ? 'IN' : 'GLOBAL';
}

export const TRUSTED_SOURCE_REGISTRY: TrustedSourceConfig[] = [
  {
    sourceId: 'aws-blog',
    sourceName: 'AWS Official Blog',
    domain: 'aws.amazon.com',
    feedUrl: 'https://aws.amazon.com/blogs/aws/feed/',
    defaultCategory: 'Cloud',
    enabled: true,
    trustLevel: 'high',
  },
  {
    sourceId: 'google-ai-blog',
    sourceName: 'Google Official Blog',
    domain: 'blog.google',
    feedUrl: 'https://blog.google/technology/ai/rss/',
    defaultCategory: 'AI & Machine Learning',
    enabled: true,
    trustLevel: 'high',
  },
  {
    sourceId: 'github-blog',
    sourceName: 'GitHub Blog',
    domain: 'github.blog',
    feedUrl: 'https://github.blog/feed/',
    defaultCategory: 'Software',
    enabled: true,
    trustLevel: 'high',
  },
  {
    sourceId: 'apple-newsroom',
    sourceName: 'Apple Newsroom',
    domain: 'apple.com',
    feedUrl: 'https://www.apple.com/newsroom/rss-feed.rss',
    defaultCategory: 'Smartphones',
    enabled: true,
    trustLevel: 'high',
  },
  {
    sourceId: 'microsoft-blog',
    sourceName: 'Microsoft Official Blog',
    domain: 'blogs.microsoft.com',
    feedUrl: 'https://blogs.microsoft.com/feed/',
    defaultCategory: 'Software',
    enabled: true,
    trustLevel: 'high',
  },
  {
    sourceId: 'nvidia-newsroom',
    sourceName: 'NVIDIA Newsroom',
    domain: 'nvidianews.nvidia.com',
    feedUrl: 'https://nvidianews.nvidia.com/releases.xml',
    defaultCategory: 'Hardware',
    enabled: true,
    trustLevel: 'high',
    // The newsroom feed also links official posts on NVIDIA's blog
    additionalDomains: ['blogs.nvidia.com'],
  },
  {
    sourceId: 'meta-newsroom',
    sourceName: 'Meta Newsroom',
    domain: 'about.fb.com',
    feedUrl: 'https://about.fb.com/news/feed/',
    defaultCategory: 'Companies',
    enabled: true,
    trustLevel: 'high',
  },
  {
    sourceId: 'nasa-breaking',
    sourceName: 'NASA Space Science',
    domain: 'nasa.gov',
    feedUrl: 'https://www.nasa.gov/feed/',
    defaultCategory: 'Space',
    enabled: true,
    trustLevel: 'high',
  },
  {
    sourceId: 'cisa-alerts',
    sourceName: 'CISA Cybersecurity Advisories',
    domain: 'cisa.gov',
    feedUrl: 'https://www.cisa.gov/cybersecurity-advisories/all.xml',
    defaultCategory: 'Cybersecurity',
    enabled: true,
    trustLevel: 'high',
  },
  // ---- Global tech media (feeds verified with curl on 2026-11-01) ----
  {
    sourceId: 'the-verge',
    sourceName: 'The Verge',
    domain: 'theverge.com',
    feedUrl: 'https://www.theverge.com/rss/index.xml',
    defaultCategory: 'Companies',
    enabled: true,
    trustLevel: 'verified',
    region: 'GLOBAL',
  },
  {
    sourceId: 'techcrunch',
    sourceName: 'TechCrunch',
    domain: 'techcrunch.com',
    feedUrl: 'https://techcrunch.com/feed/',
    defaultCategory: 'Startups',
    enabled: true,
    trustLevel: 'verified',
    region: 'GLOBAL',
  },
  {
    sourceId: 'ars-technica',
    sourceName: 'Ars Technica',
    domain: 'arstechnica.com',
    feedUrl: 'https://feeds.arstechnica.com/arstechnica/index',
    defaultCategory: 'Science',
    enabled: true,
    trustLevel: 'verified',
    region: 'GLOBAL',
  },
  {
    sourceId: 'wired',
    sourceName: 'Wired',
    domain: 'wired.com',
    feedUrl: 'https://www.wired.com/feed/rss',
    defaultCategory: 'Companies',
    enabled: true,
    trustLevel: 'verified',
    region: 'GLOBAL',
  },
  {
    sourceId: 'openai-news',
    sourceName: 'OpenAI News',
    domain: 'openai.com',
    feedUrl: 'https://openai.com/news/rss.xml',
    defaultCategory: 'AI & Machine Learning',
    enabled: true,
    trustLevel: 'high',
    region: 'GLOBAL',
    maxItemsPerRun: 10,
  },
  // ---- India (region 'IN') ----
  {
    sourceId: 'inc42',
    sourceName: 'Inc42',
    domain: 'inc42.com',
    feedUrl: 'https://inc42.com/feed/',
    defaultCategory: 'Startups',
    enabled: true,
    trustLevel: 'verified',
    region: 'IN',
  },
  {
    sourceId: 'yourstory',
    sourceName: 'YourStory',
    domain: 'yourstory.com',
    feedUrl: 'https://yourstory.com/feed',
    defaultCategory: 'Startups',
    enabled: true,
    trustLevel: 'verified',
    region: 'IN',
  },
];

export function getSourceById(sourceId: string): TrustedSourceConfig | undefined {
  return TRUSTED_SOURCE_REGISTRY.find((s) => s.sourceId === sourceId && s.enabled);
}

export function getAllEnabledSources(): TrustedSourceConfig[] {
  return TRUSTED_SOURCE_REGISTRY.filter((s) => s.enabled);
}
