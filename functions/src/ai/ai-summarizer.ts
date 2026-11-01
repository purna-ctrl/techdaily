export type ArticlePriority = 'breaking' | 'high' | 'normal';

export interface SimpleExplanationTranslations {
  te?: string;
  ta?: string;
  hi?: string;
}

export interface AiSummarizationInput {
  articleId: string;
  title: string;
  rawContent: string;
  sourceName: string;
  sourceUrl: string;
  publishedAt?: string;
  categoryHint?: string;
}

export interface AiSummarizationOutput {
  summary: string;
  whatHappened: string;
  whyItMatters: string;
  simpleExplanation: string;
  keyPoints: string[];
  category: string;
  /** "In simple words" translated: te = Telugu, ta = Tamil, hi = Hindi. Any language may be missing. */
  simpleExplanationTranslations?: SimpleExplanationTranslations;
  /** Editorial urgency; 'breaking' / 'high' can trigger a push notification. */
  priority?: ArticlePriority;
  aiModel: string;
  aiPromptVersion: string;
}

export interface AiSummarizer {
  summarize(input: AiSummarizationInput): Promise<AiSummarizationOutput>;
}
