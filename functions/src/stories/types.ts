/**
 * TechDaily v2 "stories" model. A story is one news event, written in simple words, that can be
 * backed by several original reports (sources). Stored in Firestore collection `stories`.
 *
 * In memory (and in JSON caches / rendered data files) dates are ISO-8601 strings; story-store.ts
 * converts them to Firestore Timestamps on write.
 */
import type { CategoryId } from './categories';
import type { ImageCandidate, StoryImage } from './images';
import type { KeyNumber } from './facts';

export type { KeyNumber } from './facts';

export type { StoryImage } from './images';

export type Confidence = 'high' | 'medium' | 'low';

export interface StorySource {
  /** Registry id of the feed (e.g. "gadgets360"). Empty for legacy/migrated items without one. */
  sourceId: string;
  /** Publisher name shown to readers ("Gadgets 360"). */
  name: string;
  /** Exact URL of the original report. */
  url: string;
  /** Publisher's own headline, used only as link text for "Read original". */
  title: string;
  /** ISO time the original was published. */
  publishedAt: string;
}

/** One "Ask about this" question with a short answer. */
export interface FaqItem {
  q: string;
  a: string;
}

export interface ScamDetails {
  howItWorks: string;
  warningSigns: string[];
  ifTargeted: string[];
  /** Official advisory link (government / regulator / vendor security page) when one exists. */
  advisoryUrl: string | null;
}

export interface Story {
  id: string;
  slug: string;
  headline: string;
  category: CategoryId;
  /** Earliest publish time among the sources (ISO). */
  publishedAt: string;
  /** Last time TechDaily changed the story (ISO). */
  updatedAt: string;
  sources: StorySource[];
  /** "In one line" TL;DR (stories-v3; empty on older stories). */
  tldr?: string;
  /** "Key numbers" chips: numbers that appear in the reports. */
  keyNumbers?: KeyNumber[];
  /** Section keys are stable; the question shown above each depends on the category (questions.ts). */
  whatHappened: string;
  affectsWho: string;
  whatToDo: string[];
  /** Shown as "Good to know" when whatToDo is empty (instead of a fake "Nothing to do"). */
  goodToKnow?: string;
  whatItMeans: string;
  /** "Ask about this": likely reader questions with short answers. */
  faq?: FaqItem[];
  scam: ScamDetails | null;
  confidence: Confidence;
  /** Low confidence, or a single source reporting an unconfirmed claim. Shown as a "Developing" badge. */
  developing: boolean;
  /** Model that wrote the text, or "techdaily-fallback-v2" for the rule-based writer. */
  aiModel: string;
  /** True while only the rule-based writer has written it; later runs re-enrich with Gemini. */
  needsEnrichment: boolean;
  enrichAttempts: number;
  /** 'IN' when any source is an Indian publisher. */
  region: 'IN' | 'GLOBAL';
  /** The AI flagged the report as unconfirmed (leak / rumour / "reportedly"). */
  unconfirmed: boolean;
  promptVersion: string;
  /**
   * The publisher's lead image (hotlinked URL + credit), best across the story's sources. Null when
   * none was found yet; the app and static pages then show generated category art.
   */
  image?: StoryImage | null;
  /** og:image page fetches tried so far for a story without an image (capped, see images.ts). */
  imageTries?: number;
}

/** One feed item after fetching + normalisation, before clustering. */
export interface NewsItem {
  sourceId: string;
  sourceName: string;
  url: string;
  canonicalUrl: string;
  title: string;
  /** Plain-text description from the feed (input to the writer only, never published). */
  snippet: string;
  publishedAt: string;
  region: 'IN' | 'GLOBAL';
  /** Official/regulator/vendor source (e.g. RBI, CISA, Apple Newsroom). */
  official: boolean;
  /** The feed's default category for this source. */
  defaultCategory: CategoryId;
  /** Image declared in the feed item (media:content / thumbnail / enclosure / first <img>). */
  image?: ImageCandidate;
}

export const STORY_PROMPT_VERSION = 'stories-v3';
export const FALLBACK_MODEL = 'techdaily-fallback-v3';
