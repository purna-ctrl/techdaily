import { AiSummarizer, AiSummarizationInput, AiSummarizationOutput } from './ai-summarizer';
import { SUMMARY_PROMPT_VERSION, APPROVED_CATEGORIES, ApprovedCategory } from './prompt-templates';
import { AiOutputValidator, AiValidationError } from './ai-output-validator';
import { KeywordCategoryClassifier } from '../pipeline/category-classifier';

export class RuleBasedAiSummarizer implements AiSummarizer {
  private classifier = new KeywordCategoryClassifier();

  async summarize(input: AiSummarizationInput): Promise<AiSummarizationOutput> {
    if (!input.title || input.title.trim().length < 5) {
      throw new AiValidationError('Input title is missing or too short for AI processing');
    }
    if (!input.rawContent || input.rawContent.trim().length < 15) {
      throw new AiValidationError('Input content is missing or insufficient for AI processing');
    }

    const title = input.title.trim();
    const content = input.rawContent.trim();

    // Determine category
    let category = input.categoryHint && APPROVED_CATEGORIES.includes(input.categoryHint as ApprovedCategory)
      ? input.categoryHint
      : this.classifier.classify(title, content);

    // Extract sentences from content
    const rawSentences = content
      .split(/[.!?]+(?:\s+|$)/)
      .map((s) => s.trim())
      .filter((s) => s.length > 20);

    const firstSentence = rawSentences[0] || `${title} has been officially announced by ${input.sourceName}.`;
    const secondSentence = rawSentences[1] || `The official announcement was published via ${input.sourceName}'s verified communications channel.`;
    const thirdSentence = rawSentences[2] || `Further technical details and documentation are available in the official release.`;

    // 1. Summary: 2 to 3 sentences
    const summary = `${firstSentence.endsWith('.') ? firstSentence : firstSentence + '.'} ${secondSentence.endsWith('.') ? secondSentence : secondSentence + '.'}`;

    // 2. What Happened: 1 to 2 sentences
    const whatHappened = `${title}. This development was documented in an official dispatch by ${input.sourceName}.`;

    // 3. Why It Matters: 1 to 2 sentences
    const whyItMatters = `This release introduces notable updates within ${category}, providing engineering advancements and practical guidance for practitioners.`;

    // 4. Simple Explanation: plain language
    const simpleExplanation = `In everyday terms, ${input.sourceName} shared new details regarding ${title.toLowerCase().replace(/[.:]/g, '')}. This update provides developers and users with direct access to these improvements.`;

    // 5. Key Points: exactly 3 to 4 bullets
    const keyPoints: string[] = [
      `Official announcement: ${title}`,
      `Verified source channel: ${input.sourceName}`,
      rawSentences.length > 0
        ? rawSentences[0].slice(0, 140)
        : `Verified technical update documented on ${input.sourceName}.`,
    ];

    if (rawSentences.length > 1) {
      keyPoints.push(rawSentences[1].slice(0, 140));
    }

    const rawOutput = {
      summary,
      whatHappened,
      whyItMatters,
      simpleExplanation,
      keyPoints,
      category,
    };

    // Quality control verification
    return AiOutputValidator.validate(rawOutput, {
      model: 'techdaily-editorial-engine-v1',
      promptVersion: SUMMARY_PROMPT_VERSION,
    });
  }
}
