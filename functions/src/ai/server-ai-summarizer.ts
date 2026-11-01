import { AiSummarizer, AiSummarizationInput, AiSummarizationOutput } from './ai-summarizer';
import { SYSTEM_INSTRUCTION, SUMMARY_PROMPT_VERSION, buildUserPrompt } from './prompt-templates';
import { AiOutputValidator } from './ai-output-validator';
import { RuleBasedAiSummarizer } from './rule-based-summarizer';

export interface ServerAiSummarizerConfig {
  apiKey?: string;
  model?: string;
  timeoutMs?: number;
  fallback?: AiSummarizer;
  fetchFn?: typeof fetch;
}

export class ServerAiSummarizer implements AiSummarizer {
  private apiKey?: string;
  private model: string;
  private timeoutMs: number;
  private fallback: AiSummarizer;
  private fetchFn: typeof fetch;

  constructor(config: ServerAiSummarizerConfig = {}) {
    this.apiKey = config.apiKey || process.env.GEMINI_API_KEY;
    this.model = config.model || process.env.GEMINI_MODEL || 'gemini-2.5-flash';
    this.timeoutMs = config.timeoutMs || 30000;
    this.fallback = config.fallback || new RuleBasedAiSummarizer();
    this.fetchFn = config.fetchFn || (globalThis.fetch as typeof fetch);
  }

  /** True when a Gemini key is configured (otherwise the rule-based fallback is used). */
  hasApiKey(): boolean {
    return Boolean(this.apiKey);
  }

  async summarize(input: AiSummarizationInput): Promise<AiSummarizationOutput> {
    if (!this.apiKey) {
      // Offline / Keyless environment -> use deterministic fallback
      return this.fallback.summarize(input);
    }

    try {
      const userPrompt = buildUserPrompt({
        title: input.title,
        sourceName: input.sourceName,
        sourceUrl: input.sourceUrl,
        rawContent: input.rawContent,
        categoryHint: input.categoryHint,
      });

      const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(
        this.model
      )}:generateContent`;

      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), this.timeoutMs);

      const response = await this.fetchFn(endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': this.apiKey,
        },
        body: JSON.stringify({
          system_instruction: {
            parts: [{ text: SYSTEM_INSTRUCTION }],
          },
          contents: [
            {
              role: 'user',
              parts: [{ text: userPrompt }],
            },
          ],
          generationConfig: {
            responseMimeType: 'application/json',
            temperature: 0.1,
            // Translations (te/ta/hi) need room; thinking is disabled so the budget goes to the answer.
            maxOutputTokens: 4096,
            thinkingConfig: { thinkingBudget: 0 },
          },
        }),
        signal: controller.signal,
      });

      clearTimeout(timer);

      if (!response.ok) {
        const errorBody = await response.text();
        throw new Error(`Gemini API responded with HTTP ${response.status}: ${errorBody}`);
      }

      const data = await response.json();
      const parts = data?.candidates?.[0]?.content?.parts;
      const rawText = Array.isArray(parts)
        ? parts.map((p: any) => (typeof p?.text === 'string' && !p?.thought ? p.text : '')).join('')
        : undefined;
      if (!rawText) {
        throw new Error('Gemini API returned empty candidate text');
      }

      const parsed = JSON.parse(rawText.replace(/^```(?:json)?\s*|\s*```$/g, '').trim());

      // Quality control and schema validation
      return AiOutputValidator.validate(parsed, {
        model: this.model,
        promptVersion: SUMMARY_PROMPT_VERSION,
      });
    } catch (err: any) {
      console.warn(
        `[ServerAiSummarizer] Gemini summarization failed for "${input.title}": ${err.message}. Engaging fallback summarizer.`
      );
      return this.fallback.summarize(input);
    }
  }
}
