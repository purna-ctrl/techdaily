import { decode } from 'html-entities';

export interface NormalizedContent {
  title: string;
  summary: string;
  simpleExplanation: string;
  keyPoints: string[];
  whatHappened: string;
  whyItMatters: string;
  imageUrl?: string;
  publishedAt: Date;
}

export class ContentNormalizer {
  private static readonly MAX_SUMMARY_LENGTH = 320;

  /**
   * Strips HTML tags, CDATA, and trims extra whitespace.
   */
  static stripHtml(rawText: string): string {
    if (!rawText) return '';
    let text = rawText;

    // Remove CDATA markers
    text = text.replace(/<!\[CDATA\[([\s\S]*?)\]\]>/gi, '$1');

    // Remove script and style elements and their contents
    text = text.replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '');
    text = text.replace(/<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>/gi, '');

    // Remove remaining HTML tags
    text = text.replace(/<\/?[^>]+(>|$)/g, ' ');

    // Decode HTML entities
    text = decode(text);

    // Normalize whitespace
    text = text.replace(/\s+/g, ' ').trim();

    return text;
  }

  /**
   * Cleans and truncates a summary string to respect fair-use copyright guidelines.
   */
  static normalizeSummary(rawSummary: string, title?: string): string {
    const cleaned = this.stripHtml(rawSummary);
    if (!cleaned || cleaned.length < 15) {
      return title ? `Official technology briefing: ${title}` : 'Technology dispatch.';
    }

    if (cleaned.length <= this.MAX_SUMMARY_LENGTH) {
      return cleaned;
    }

    // Truncate at word boundary
    const truncated = cleaned.substring(0, this.MAX_SUMMARY_LENGTH);
    const lastSpace = truncated.lastIndexOf(' ');
    if (lastSpace > 0) {
      return truncated.substring(0, lastSpace) + '...';
    }
    return truncated + '...';
  }

  /**
   * Normalizes title: strips HTML, decodes entities, trims.
   */
  static normalizeTitle(rawTitle: string): string {
    return this.stripHtml(rawTitle);
  }

  /**
   * Parses publication date safely with fallback to now.
   */
  static normalizeDate(rawDate: any): Date {
    if (!rawDate) return new Date();
    if (rawDate instanceof Date && !isNaN(rawDate.getTime())) {
      return rawDate;
    }
    const parsed = new Date(rawDate);
    if (!isNaN(parsed.getTime())) {
      return parsed;
    }
    return new Date();
  }

  /**
   * Validates and cleans image URLs.
   */
  static normalizeImageUrl(rawUrl?: string): string | undefined {
    if (!rawUrl || typeof rawUrl !== 'string') return undefined;
    const trimmed = rawUrl.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      // Basic image extension or query check
      return trimmed;
    }
    return undefined;
  }

  /**
   * Generates structured editorial fields ("In simple words", "What happened?", "Why it matters", keyPoints)
   * conforming to the TechDaily schema without scraping or inventing facts.
   */
  static structureEditorial(
    title: string,
    summary: string,
    sourceName: string
  ): {
    simpleExplanation: string;
    keyPoints: string[];
    whatHappened: string;
    whyItMatters: string;
  } {
    const cleanSummary = summary.length > 0 ? summary : title;

    // Sentence splitting for key points
    const sentences = cleanSummary
      .split(/(?<=[.!?])\s+/)
      .filter((s) => s.trim().length > 15);

    const keyPoints: string[] = [];
    if (sentences.length >= 2) {
      keyPoints.push(sentences[0]);
      keyPoints.push(sentences[1]);
    } else {
      keyPoints.push(title);
      keyPoints.push(`Reported by ${sourceName}`);
    }

    return {
      simpleExplanation: `In brief: ${title}`,
      whatHappened: cleanSummary,
      whyItMatters: `This update from ${sourceName} highlights ongoing technological architecture and ecosystem developments.`,
      keyPoints,
    };
  }
}
