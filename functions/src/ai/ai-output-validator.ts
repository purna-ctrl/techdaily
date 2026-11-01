import { APPROVED_CATEGORIES, ApprovedCategory, SUMMARY_PROMPT_VERSION } from './prompt-templates';
import { AiSummarizationOutput, ArticlePriority, SimpleExplanationTranslations } from './ai-summarizer';

export class AiValidationError extends Error {
  constructor(message: string, public readonly details?: Record<string, any>) {
    super(`AiValidationError: ${message}`);
    this.name = 'AiValidationError';
  }
}

export class AiOutputValidator {
  /**
   * Helper to count sentences reliably by splitting on sentence-ending punctuation.
   */
  static countSentences(text: string): number {
    if (!text || !text.trim()) return 0;
    // Strip common non-terminating periods like "e.g.", "i.e.", "v1.0", "U.S." before splitting
    const normalized = text
      .replace(/\b(?:e\.g\.|i\.e\.|vs\.|approx\.|inc\.|corp\.|co\.|ltd\.|dr\.|mr\.|ms\.)/gi, (m) =>
        m.replace(/\./g, '')
      )
      .replace(/\b\d+\.\d+\b/g, (m) => m.replace(/\./g, '_'));

    const matches = normalized.split(/[.!?]+(?:\s+|$)/).filter((s) => s.trim().length > 3);
    return Math.max(1, matches.length);
  }

  /**
   * Validates raw parsed AI output against strict editorial quality and safety requirements.
   * Throws AiValidationError if constraints are violated.
   */
  static validate(
    raw: any,
    metadata: { model: string; promptVersion?: string }
  ): AiSummarizationOutput {
    if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
      throw new AiValidationError('AI output is not a valid JSON object');
    }

    // Check for common AI refusal / meta-language
    const stringified = JSON.stringify(raw).toLowerCase();
    if (
      stringified.includes('as an ai') ||
      stringified.includes('i am an ai') ||
      stringified.includes('as a large language model')
    ) {
      throw new AiValidationError('AI output contains assistant meta-commentary');
    }

    // 1. summary
    if (typeof raw.summary !== 'string' || raw.summary.trim().length < 25) {
      throw new AiValidationError('Field "summary" is missing or too short (< 25 chars)');
    }
    const summarySentences = this.countSentences(raw.summary);
    if (summarySentences < 2 || summarySentences > 5) {
      throw new AiValidationError(
        `Field "summary" must contain 2 to 4 sentences (found ${summarySentences})`,
        { summarySentences, summary: raw.summary }
      );
    }

    // 2. whatHappened
    if (typeof raw.whatHappened !== 'string' || raw.whatHappened.trim().length < 15) {
      throw new AiValidationError('Field "whatHappened" is missing or too short (< 15 chars)');
    }
    const whatHappenedSentences = this.countSentences(raw.whatHappened);
    if (whatHappenedSentences < 1 || whatHappenedSentences > 4) {
      throw new AiValidationError(
        `Field "whatHappened" must contain 1 to 3 sentences (found ${whatHappenedSentences})`,
        { whatHappenedSentences }
      );
    }

    // 3. whyItMatters
    if (typeof raw.whyItMatters !== 'string' || raw.whyItMatters.trim().length < 15) {
      throw new AiValidationError('Field "whyItMatters" is missing or too short (< 15 chars)');
    }
    const whyItMattersSentences = this.countSentences(raw.whyItMatters);
    if (whyItMattersSentences < 1 || whyItMattersSentences > 4) {
      throw new AiValidationError(
        `Field "whyItMatters" must contain 1 to 3 sentences (found ${whyItMattersSentences})`,
        { whyItMattersSentences }
      );
    }

    // 4. simpleExplanation
    if (typeof raw.simpleExplanation !== 'string' || raw.simpleExplanation.trim().length < 20) {
      throw new AiValidationError('Field "simpleExplanation" is missing or too short (< 20 chars)');
    }

    // 5. keyPoints
    if (!Array.isArray(raw.keyPoints)) {
      throw new AiValidationError('Field "keyPoints" must be an array');
    }
    if (raw.keyPoints.length < 3 || raw.keyPoints.length > 5) {
      throw new AiValidationError(
        `Field "keyPoints" must contain 3 to 5 items (found ${raw.keyPoints.length})`,
        { count: raw.keyPoints.length }
      );
    }
    const sanitizedKeyPoints: string[] = [];
    for (let i = 0; i < raw.keyPoints.length; i++) {
      const point = raw.keyPoints[i];
      if (typeof point !== 'string' || point.trim().length < 5) {
        throw new AiValidationError(`keyPoints[${i}] must be a non-empty string of >= 5 chars`);
      }
      sanitizedKeyPoints.push(point.trim());
    }

    // 6. category
    if (typeof raw.category !== 'string') {
      throw new AiValidationError('Field "category" must be a string');
    }
    const trimmedCategory = raw.category.trim();
    if (!APPROVED_CATEGORIES.includes(trimmedCategory as ApprovedCategory)) {
      throw new AiValidationError(
        `Category "${trimmedCategory}" is not an approved TechDaily category. Approved categories: ${APPROVED_CATEGORIES.join(', ')}`,
        { category: trimmedCategory }
      );
    }

    // 7. Optional translations (tolerant: invalid or missing languages are dropped, never fatal)
    const simpleExplanationTranslations = this.sanitizeTranslations(raw.simpleExplanationTranslations);

    // 8. Optional priority
    const priority = this.sanitizePriority(raw.priority);

    const result: AiSummarizationOutput = {
      summary: raw.summary.trim(),
      whatHappened: raw.whatHappened.trim(),
      whyItMatters: raw.whyItMatters.trim(),
      simpleExplanation: raw.simpleExplanation.trim(),
      keyPoints: sanitizedKeyPoints,
      category: trimmedCategory,
      aiModel: metadata.model,
      aiPromptVersion: metadata.promptVersion ?? SUMMARY_PROMPT_VERSION,
    };
    if (simpleExplanationTranslations) result.simpleExplanationTranslations = simpleExplanationTranslations;
    if (priority) result.priority = priority;
    return result;
  }

  static sanitizeTranslations(raw: any): SimpleExplanationTranslations | undefined {
    if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return undefined;
    const out: SimpleExplanationTranslations = {};
    for (const lang of ['te', 'ta', 'hi'] as const) {
      const v = raw[lang];
      if (typeof v === 'string' && v.trim().length >= 5 && v.trim().length <= 2000) {
        out[lang] = v.trim();
      }
    }
    return Object.keys(out).length > 0 ? out : undefined;
  }

  static sanitizePriority(raw: any): ArticlePriority | undefined {
    if (typeof raw !== 'string') return undefined;
    const v = raw.trim().toLowerCase();
    return v === 'breaking' || v === 'high' || v === 'normal' ? v : undefined;
  }
}
