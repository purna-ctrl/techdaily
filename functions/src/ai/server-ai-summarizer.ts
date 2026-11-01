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

/**
 * Free-tier guard (shared across instances in one process): caps Gemini calls per run, spaces them
 * out, and stops calling after a 429 so the rest of the run uses the rule-based fallback. Articles
 * left on the fallback are re-enriched by later runs.
 *   GEMINI_MAX_CALLS_PER_RUN (default: unlimited), GEMINI_MIN_INTERVAL_MS (default: 0)
 */
const geminiBudget = { calls: 0, rateLimited: false, nextSlot: 0 };
/** Stops all further Gemini calls in this process (called on HTTP 429). */
export function markGeminiRateLimited(): void {
  geminiBudget.rateLimited = true;
}
/** True while Gemini may still be called this run (key set, not rate-limited, budget left). */
export function geminiBudgetLeft(): boolean {
  const max = parseInt(process.env.GEMINI_MAX_CALLS_PER_RUN || '', 10);
  if (geminiBudget.rateLimited) return false;
  return !(Number.isFinite(max) && max >= 0 && geminiBudget.calls >= max);
}
export function geminiCallsUsed(): number {
  return geminiBudget.calls;
}
export function resetGeminiBudget(): void {
  geminiBudget.calls = 0;
  geminiBudget.rateLimited = false;
  geminiBudget.nextSlot = 0;
}
/** Reserves one Gemini call under the shared per-run budget (false = use the fallback). */
export async function takeGeminiSlot(): Promise<boolean> {
  const max = parseInt(process.env.GEMINI_MAX_CALLS_PER_RUN || '', 10);
  if (geminiBudget.rateLimited) return false;
  if (Number.isFinite(max) && max >= 0 && geminiBudget.calls >= max) return false;
  geminiBudget.calls++;
  const gap = parseInt(process.env.GEMINI_MIN_INTERVAL_MS || '', 10);
  if (Number.isFinite(gap) && gap > 0) {
    const now = Date.now();
    const at = Math.max(now, geminiBudget.nextSlot);
    geminiBudget.nextSlot = at + gap;
    if (at > now) await new Promise((r) => setTimeout(r, at - now));
  }
  return !geminiBudget.rateLimited;
}

export class ServerAiSummarizer implements AiSummarizer {
  private apiKey?: string;
  private model: string;
  private timeoutMs: number;
  private fallback: AiSummarizer;
  private fetchFn: typeof fetch;

  constructor(config: ServerAiSummarizerConfig = {}) {
    this.apiKey = config.apiKey || process.env.GEMINI_API_KEY;
    this.model = config.model || process.env.GEMINI_MODEL || 'gemini-flash-latest';
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

    if (!(await takeGeminiSlot())) {
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
        if (response.status === 429) geminiBudget.rateLimited = true;
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
