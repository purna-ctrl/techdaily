import { Story } from './types';
import { istDate } from './text';

const HOUR = 3600 * 1000;

/**
 * Ranking score for "Top Stories" and "Today in 5": recency (12 h half-life) x coverage (more
 * independent sources = bigger story) x confidence, with a small boost for India-relevant and
 * scam/security stories (the ones readers act on).
 */
export function storyScore(s: Story, now = Date.now()): number {
  const t = new Date(s.publishedAt).getTime();
  const ageH = Math.max(0, (now - (isNaN(t) ? now : t)) / HOUR);
  const recency = Math.pow(0.5, ageH / 12);
  const outlets = new Set(s.sources.map((x) => x.name)).size;
  const coverage = 1 + 0.6 * Math.min(outlets - 1, 4);
  const conf = s.confidence === 'high' ? 1.15 : s.confidence === 'low' ? 0.8 : 1;
  const local = s.region === 'IN' ? 1.15 : 1;
  const act = s.category === 'scams-security' && s.scam ? 1.2 : 1;
  const official = s.sources.length > 0 ? 1 : 0.5;
  return recency * coverage * conf * local * act * official;
}

export function rankStories(stories: Story[], now = Date.now()): Story[] {
  return [...stories].sort((a, b) => storyScore(b, now) - storyScore(a, now) || b.publishedAt.localeCompare(a.publishedAt));
}

export interface TodayInFive {
  id: string;
  /** IST calendar date "YYYY-MM-DD". */
  date: string;
  generatedAt: string;
  storyIds: string[];
  items: Array<{
    storyId: string;
    slug: string;
    headline: string;
    category: string;
    whatItMeans: string;
    sourceCount: number;
    publishedAt: string;
  }>;
}

/**
 * Top five stories of the last 24 h (widening to 48 h / everything if there are not enough):
 * best score first, at most one story per category until every category is used once.
 */
export function pickTodayInFive(stories: Story[], now = Date.now(), count = 5): TodayInFive {
  let pool: Story[] = [];
  for (const hours of [24, 48, Infinity]) {
    pool = stories.filter((s) => now - new Date(s.publishedAt).getTime() <= hours * HOUR);
    if (pool.length >= count) break;
  }
  const ranked = rankStories(pool, now);
  const picked: Story[] = [];
  const used = new Set<string>();
  for (const s of ranked) {
    if (picked.length >= count) break;
    if (used.has(s.category)) continue;
    picked.push(s);
    used.add(s.category);
  }
  for (const s of ranked) {
    if (picked.length >= count) break;
    if (!picked.includes(s)) picked.push(s);
  }
  const date = istDate(new Date(now));
  return {
    id: date,
    date,
    generatedAt: new Date(now).toISOString(),
    storyIds: picked.map((s) => s.id),
    items: picked.map((s) => ({
      storyId: s.id,
      slug: s.slug,
      headline: s.headline,
      category: s.category,
      whatItMeans: s.whatItMeans || s.tldr || '',
      sourceCount: new Set(s.sources.map((x) => x.url)).size,
      publishedAt: s.publishedAt,
    })),
  };
}
