/**
 * Groups reports about the same event into one story.
 *
 * Signal: headline tokens (stop words and generic news verbs removed, light stemming), weighted by
 * IDF over everything being clustered so rare words ("Galaxy", "S26", "Binance") count more than
 * common ones ("Apple", "India"), plus word-bigram shingles. Two reports join when
 *   weighted-Jaccard + shingle bonus >= threshold, they share >= 2 significant tokens,
 *   and they were published within `windowMs` of each other.
 * Single-pass, newest-last, max-similarity to any member (with the time window preventing long chains).
 */

const STOP = new Set(
  (
    'a an the and or but of to in on for with at by from is are was were be been being its it this that these those ' +
    'as into over after before about than then up down out off new now just how why what who when where which will ' +
    'can could may might should would has have had do does did not no yes vs via per amid says said say report reports ' +
    'reported launch launches launched launching announce announces announced unveil unveils unveiled introduce ' +
    'introduces introduced release releases released update updates updated get gets got make makes made more most ' +
    'here heres your you our we us they their them his her he she i my all any some first latest big top now today ' +
    'week year years day days time set sets know need needs want wants every one two three ' +
    'india indian rs crore lakh price check details everything look'
  ).split(/\s+/)
);

export function normalizeTitle(title: string): string {
  return (title || '')
    .normalize('NFKC')
    .toLowerCase()
    .replace(/[\u2018\u2019'"`]/g, '')
    .replace(/[^\p{L}\p{N}\s]/gu, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function stem(w: string): string {
  if (w.length > 4 && w.endsWith('ies')) return w.slice(0, -3) + 'y';
  if (w.length > 4 && w.endsWith('es') && /(sh|ch|x|ss)es$/.test(w)) return w.slice(0, -2);
  if (w.length > 3 && w.endsWith('s') && !w.endsWith('ss') && !w.endsWith('us') && !w.endsWith('is')) return w.slice(0, -1);
  return w;
}

export function titleTokens(title: string): string[] {
  const out: string[] = [];
  for (const raw of normalizeTitle(title).split(' ')) {
    if (!raw || STOP.has(raw)) continue;
    if (raw.length < 2 && !/\d/.test(raw)) continue;
    const w = stem(raw);
    if (STOP.has(w)) continue;
    out.push(w);
  }
  return out;
}

export function shingles(tokens: string[]): Set<string> {
  const s = new Set<string>();
  for (let i = 0; i + 1 < tokens.length; i++) s.add(`${tokens[i]} ${tokens[i + 1]}`);
  return s;
}

export interface Clusterable {
  /** Unique key (canonical URL). */
  key: string;
  title: string;
  publishedAtMs: number;
}

export interface ClusterSeed<T extends Clusterable> {
  /** Existing story id the cluster belongs to. */
  storyId: string;
  /** Titles already in the story (its sources), used for matching only. */
  members: Clusterable[];
  payload?: T;
}

export interface Cluster<T extends Clusterable> {
  /** Set when the cluster is an existing story that new items joined (or that has no new items). */
  storyId?: string;
  /** New items in this cluster (newest last). */
  items: T[];
  /** All members used for matching (existing + new). */
  members: Clusterable[];
}

export interface ClusterOptions {
  threshold?: number;
  windowMs?: number;
  minSharedTokens?: number;
}

export const DEFAULT_CLUSTER_OPTIONS: Required<ClusterOptions> = {
  threshold: 0.35,
  windowMs: 36 * 60 * 60 * 1000,
  minSharedTokens: 2,
};

interface Sig {
  tokens: Set<string>;
  shingles: Set<string>;
  normalized: string;
  t: number;
}

export class IdfModel {
  private df = new Map<string, number>();
  private n = 0;
  constructor(titles: string[]) {
    for (const t of titles) {
      this.n++;
      for (const tok of new Set(titleTokens(t))) this.df.set(tok, (this.df.get(tok) ?? 0) + 1);
    }
  }
  idf(tok: string): number {
    const df = this.df.get(tok) ?? 0;
    return Math.log((this.n + 1) / (df + 1)) + 1;
  }
}

function sig(m: Clusterable): Sig {
  const toks = titleTokens(m.title);
  return { tokens: new Set(toks), shingles: shingles(toks), normalized: normalizeTitle(m.title), t: m.publishedAtMs };
}

/** Similarity 0..1(+bonus) of two headlines under an IDF model. Exposed for tests/tuning. */
export function titleSimilarity(a: string, b: string, idf: IdfModel): { score: number; shared: number } {
  return sigSimilarity(sig({ key: 'a', title: a, publishedAtMs: 0 }), sig({ key: 'b', title: b, publishedAtMs: 0 }), idf);
}

function sigSimilarity(a: Sig, b: Sig, idf: IdfModel): { score: number; shared: number } {
  if (a.normalized && a.normalized === b.normalized) return { score: 1, shared: a.tokens.size };
  let inter = 0;
  let union = 0;
  let shared = 0;
  for (const t of a.tokens) {
    const w = idf.idf(t);
    union += w;
    if (b.tokens.has(t)) {
      inter += w;
      shared++;
    }
  }
  for (const t of b.tokens) if (!a.tokens.has(t)) union += idf.idf(t);
  if (union === 0) return { score: 0, shared: 0 };
  let sharedShingles = 0;
  for (const s of a.shingles) if (b.shingles.has(s)) sharedShingles++;
  const bonus = Math.min(0.2, sharedShingles * 0.1);
  return { score: inter / union + bonus, shared };
}

/**
 * Clusters `items` (new reports) together and onto `seeds` (recent existing stories).
 * Returns only clusters that received at least one new item.
 */
export function clusterItems<T extends Clusterable>(
  items: T[],
  seeds: ClusterSeed<T>[] = [],
  opts: ClusterOptions = {}
): Cluster<T>[] {
  const o = { ...DEFAULT_CLUSTER_OPTIONS, ...opts };
  const idf = new IdfModel([...items.map((i) => i.title), ...seeds.flatMap((s) => s.members.map((m) => m.title))]);

  interface Work {
    cluster: Cluster<T>;
    sigs: Sig[];
  }
  const work: Work[] = seeds.map((s) => ({
    cluster: { storyId: s.storyId, items: [], members: [...s.members] },
    sigs: s.members.map(sig),
  }));

  const seen = new Set<string>(seeds.flatMap((s) => s.members.map((m) => m.key)));
  const sorted = [...items].sort((a, b) => a.publishedAtMs - b.publishedAtMs);

  for (const item of sorted) {
    if (seen.has(item.key)) continue;
    seen.add(item.key);
    const s = sig(item);
    let best: Work | undefined;
    let bestScore = 0;
    for (const w of work) {
      for (const ms of w.sigs) {
        if (Math.abs(ms.t - s.t) > o.windowMs) continue;
        const { score, shared } = sigSimilarity(s, ms, idf);
        if (score >= 1 || (shared >= o.minSharedTokens && score >= o.threshold)) {
          if (score > bestScore) {
            bestScore = score;
            best = w;
          }
        }
      }
    }
    if (best) {
      best.cluster.items.push(item);
      best.cluster.members.push(item);
      best.sigs.push(s);
    } else {
      work.push({ cluster: { items: [item], members: [item] }, sigs: [s] });
    }
  }
  return work.map((w) => w.cluster).filter((c) => c.items.length > 0);
}
