import * as fs from 'fs';
import * as path from 'path';
import {
  AiSummarizer,
  ServerAiSummarizer,
  RuleBasedAiSummarizer,
  AiOutputValidator,
  AiValidationError,
  SYSTEM_INSTRUCTION,
  SUMMARY_PROMPT_VERSION,
  APPROVED_CATEGORIES,
} from '../src/ai';
import { DuplicateDetector } from '../src/pipeline/duplicate-detector';

describe('AI Summarization & Safety Pipeline Tests', () => {
  const sampleArticleInput = {
    articleId: 'art-aws-k8s-kernel-bypass',
    title: 'Amazon EKS Introduces Kernel-Bypass Networking for Ultra-Low Latency',
    rawContent:
      'AWS has officially announced support for kernel-bypass networking in Amazon Elastic Kubernetes Service (EKS). ' +
      'This feature enables high-throughput containerized applications to communicate directly with underlying network interfaces. ' +
      'By avoiding Linux kernel packet processing overhead, packet latency is reduced by up to forty percent for specialized workloads. ' +
      'The capability is available starting today in all commercial AWS regions.',
    sourceName: 'AWS Official Blog',
    sourceUrl: 'https://aws.amazon.com/blogs/aws/eks-kernel-bypass/',
    publishedAt: '2026-09-16T10:00:00.000Z',
    categoryHint: 'Cloud',
  };

  describe('RuleBasedAiSummarizer & Baseline Quality Control', () => {
    const summarizer = new RuleBasedAiSummarizer();

    test('valid article: produces structured editorial output matching all constraints', async () => {
      const result = await summarizer.summarize(sampleArticleInput);

      expect(result).toBeDefined();
      expect(result.summary).toBeTruthy();
      expect(result.whatHappened).toBeTruthy();
      expect(result.whyItMatters).toBeTruthy();
      expect(result.simpleExplanation).toBeTruthy();
      expect(result.keyPoints.length).toBeGreaterThanOrEqual(3);
      expect(result.keyPoints.length).toBeLessThanOrEqual(5);
      expect(APPROVED_CATEGORIES).toContain(result.category);
      expect(result.aiPromptVersion).toBe(SUMMARY_PROMPT_VERSION);
      expect(result.aiModel).toBeTruthy();

      // Check sentence counts
      const summarySentences = AiOutputValidator.countSentences(result.summary);
      expect(summarySentences).toBeGreaterThanOrEqual(2);
      expect(summarySentences).toBeLessThanOrEqual(5);

      const whatHappenedSentences = AiOutputValidator.countSentences(result.whatHappened);
      expect(whatHappenedSentences).toBeGreaterThanOrEqual(1);
      expect(whatHappenedSentences).toBeLessThanOrEqual(4);

      const whyItMattersSentences = AiOutputValidator.countSentences(result.whyItMatters);
      expect(whyItMattersSentences).toBeGreaterThanOrEqual(1);
      expect(whyItMattersSentences).toBeLessThanOrEqual(4);
    });

    test('short article: handles concise story cleanly', async () => {
      const shortInput = {
        articleId: 'art-short-update',
        title: 'Python 3.14 Release Candidate 1 Available for Testing',
        rawContent:
          'The Python core development team has released Python 3.14.0rc1 for developer testing and feedback.',
        sourceName: 'Python Foundation',
        sourceUrl: 'https://python.org/news/3.14-rc1',
      };

      const result = await summarizer.summarize(shortInput);
      expect(result.summary).toBeTruthy();
      expect(result.keyPoints.length).toBeGreaterThanOrEqual(3);
      expect(result.category).toBe('Software');
    });

    test('long article: handles extensive documentation without crashing or truncation issues', async () => {
      const longContent = (
        'NVIDIA announced next-generation quantum computing integration for supercomputing facilities. ' +
        'The CUDA-Q platform now links superconducting quantum processors directly with GPU clusters. '
      ).repeat(30);

      const longInput = {
        articleId: 'art-nvidia-quantum-cluster',
        title: 'NVIDIA Expands CUDA-Q Platform Across Global Supercomputing Centers',
        rawContent: longContent,
        sourceName: 'NVIDIA Newsroom',
        sourceUrl: 'https://nvidianews.nvidia.com/releases/cuda-q-global',
      };

      const result = await summarizer.summarize(longInput);
      expect(result.summary).toBeTruthy();
      expect(result.keyPoints.length).toBeGreaterThanOrEqual(3);
      expect(result.keyPoints.length).toBeLessThanOrEqual(5);
    });

    test('missing content: rejects empty or insufficient article content with AiValidationError', async () => {
      const emptyContentInput = {
        articleId: 'art-empty',
        title: 'Valid Title Here',
        rawContent: '   ',
        sourceName: 'Source',
        sourceUrl: 'https://example.com/story',
      };

      await expect(summarizer.summarize(emptyContentInput)).rejects.toThrow(AiValidationError);
    });

    test('missing title: rejects empty title with AiValidationError', async () => {
      const emptyTitleInput = {
        articleId: 'art-no-title',
        title: '',
        rawContent: 'Adequate length article content that describes an engineering update.',
        sourceName: 'Source',
        sourceUrl: 'https://example.com/story',
      };

      await expect(summarizer.summarize(emptyTitleInput)).rejects.toThrow(AiValidationError);
    });
  });

  describe('AiOutputValidator Schema & Quality Enforcement', () => {
    const validMeta = { model: 'gemini-2.5-flash', promptVersion: 'v1' };

    test('validates correct JSON structure', () => {
      const validPayload = {
        summary:
          'AWS launched kernel-bypass networking for Kubernetes clusters today. The update reduces latency by bypassing the traditional Linux network stack.',
        whatHappened:
          'Amazon Web Services made kernel-bypass networking available in Amazon EKS for low-latency containerized applications.',
        whyItMatters:
          'This significantly improves throughput and reduces networking latency for high-performance workloads.',
        simpleExplanation:
          'AWS made container networking much faster by letting apps talk straight to network cards.',
        keyPoints: [
          'Direct network interface communication in EKS',
          'Avoids Linux kernel overhead for networking packets',
          'Available across all commercial regions immediately',
        ],
        category: 'Cloud',
      };

      const validated = AiOutputValidator.validate(validPayload, validMeta);
      expect(validated.summary).toBe(validPayload.summary);
      expect(validated.category).toBe('Cloud');
      expect(validated.aiModel).toBe('gemini-2.5-flash');
      expect(validated.aiPromptVersion).toBe('v1');
    });

    test('rejects malformed output: not an object', () => {
      expect(() => AiOutputValidator.validate('string instead of object', validMeta)).toThrow(
        AiValidationError
      );
    });

    test('rejects output with fewer than 3 key points', () => {
      const invalidPayload = {
        summary: 'Sentence one of summary. Sentence two of summary.',
        whatHappened: 'What happened sentence.',
        whyItMatters: 'Why it matters sentence.',
        simpleExplanation: 'Simple plain English explanation text.',
        keyPoints: ['Only one bullet point', 'Only second bullet point'],
        category: 'Cloud',
      };

      expect(() => AiOutputValidator.validate(invalidPayload, validMeta)).toThrow(
        /keyPoints.*must contain 3 to 5 items/
      );
    });

    test('rejects output with more than 5 key points', () => {
      const invalidPayload = {
        summary: 'Sentence one of summary. Sentence two of summary.',
        whatHappened: 'What happened sentence.',
        whyItMatters: 'Why it matters sentence.',
        simpleExplanation: 'Simple plain English explanation text.',
        keyPoints: ['Point 1', 'Point 2', 'Point 3', 'Point 4', 'Point 5', 'Point 6 excessive point'],
        category: 'Cloud',
      };

      expect(() => AiOutputValidator.validate(invalidPayload, validMeta)).toThrow(
        /keyPoints.*must contain 3 to 5 items/
      );
    });

    test('rejects unapproved category (e.g. Crypto Casino, Unofficial)', () => {
      const invalidCategoryPayload = {
        summary: 'Sentence one of summary. Sentence two of summary.',
        whatHappened: 'What happened sentence.',
        whyItMatters: 'Why it matters sentence.',
        simpleExplanation: 'Simple plain English explanation text.',
        keyPoints: ['Valid point one', 'Valid point two', 'Valid point three'],
        category: 'Crypto Gambling & Speculation',
      };

      expect(() => AiOutputValidator.validate(invalidCategoryPayload, validMeta)).toThrow(
        /not an approved TechDaily category/
      );
    });

    test('rejects assistant meta-commentary (as an AI language model)', () => {
      const metaCommentaryPayload = {
        summary:
          'As an AI language model, I cannot verify this story. However here is sentence two.',
        whatHappened: 'What happened sentence.',
        whyItMatters: 'Why it matters sentence.',
        simpleExplanation: 'Simple plain English explanation text.',
        keyPoints: ['Valid point one', 'Valid point two', 'Valid point three'],
        category: 'Software',
      };

      expect(() => AiOutputValidator.validate(metaCommentaryPayload, validMeta)).toThrow(
        /assistant meta-commentary/
      );
    });
  });

  describe('ServerAiSummarizer Integration & Fault Tolerance', () => {
    test('uses fallback when GEMINI_API_KEY is not configured (offline execution)', async () => {
      // Create with undefined apiKey
      const summarizer = new ServerAiSummarizer({ apiKey: undefined });
      const result = await summarizer.summarize(sampleArticleInput);

      expect(result).toBeDefined();
      expect(result.summary).toBeTruthy();
      expect(result.keyPoints.length).toBeGreaterThanOrEqual(3);
    });

    test('handles API HTTP error by falling back safely to deterministic summarizer', async () => {
      // Mock fetch returning HTTP 500 error
      const mockFailingFetch: any = jest.fn().mockResolvedValue({
        ok: false,
        status: 500,
        text: async () => 'Internal Server Error from Gemini API',
      });

      const summarizer = new ServerAiSummarizer({
        apiKey: 'mock-key-for-test',
        fetchFn: mockFailingFetch,
      });

      const result = await summarizer.summarize(sampleArticleInput);

      expect(mockFailingFetch).toHaveBeenCalled();
      // Should not throw, should return fallback output gracefully
      expect(result).toBeDefined();
      expect(result.summary).toBeTruthy();
      expect(result.keyPoints.length).toBeGreaterThanOrEqual(3);
    });

    test('handles malformed JSON from API by falling back safely', async () => {
      const mockMalformedFetch: any = jest.fn().mockResolvedValue({
        ok: true,
        status: 200,
        json: async () => ({
          candidates: [
            {
              content: {
                parts: [{ text: 'NOT VALID JSON {{{{' }],
              },
            },
          ],
        }),
      });

      const summarizer = new ServerAiSummarizer({
        apiKey: 'mock-key-for-test',
        fetchFn: mockMalformedFetch,
      });

      const result = await summarizer.summarize(sampleArticleInput);
      expect(mockMalformedFetch).toHaveBeenCalled();
      expect(result).toBeDefined();
      expect(result.summary).toBeTruthy();
    });

    test('successfully parses valid structured JSON when API succeeds', async () => {
      const mockValidApiResponse = {
        summary:
          'Amazon EKS now supports ultra-low latency networking. Applications can bypass the standard Linux kernel network stack for faster speeds.',
        whatHappened:
          'AWS launched kernel-bypass networking in Amazon Elastic Kubernetes Service.',
        whyItMatters:
          'Containerized network latency drops by forty percent for specialized high-throughput clusters.',
        simpleExplanation:
          'AWS lets programs connect directly to network cards for faster communication.',
        keyPoints: [
          'Direct network interface access in Amazon EKS',
          'Eliminates traditional operating system network bottlenecks',
          'Available in all AWS commercial cloud regions',
        ],
        category: 'Cloud',
      };

      const mockSuccessFetch: any = jest.fn().mockResolvedValue({
        ok: true,
        status: 200,
        json: async () => ({
          candidates: [
            {
              content: {
                parts: [{ text: JSON.stringify(mockValidApiResponse) }],
              },
            },
          ],
        }),
      });

      const summarizer = new ServerAiSummarizer({
        apiKey: 'mock-key-for-test',
        fetchFn: mockSuccessFetch,
      });

      const result = await summarizer.summarize(sampleArticleInput);
      expect(mockSuccessFetch).toHaveBeenCalled();
      expect(result.summary).toBe(mockValidApiResponse.summary);
      expect(result.category).toBe('Cloud');
      expect(result.aiModel).toBe('gemini-2.5-flash');
    });
  });

  describe('Factual Constraint & AI Safety Rules', () => {
    test('system instruction explicitly enforces zero-hallucination rules', () => {
      expect(SYSTEM_INSTRUCTION).toContain('Summarize ONLY the verified source information');
      expect(SYSTEM_INSTRUCTION).toContain('Invent facts or scenarios');
      expect(SYSTEM_INSTRUCTION).toContain('Invent or extrapolate statistics');
      expect(SYSTEM_INSTRUCTION).toContain('Invent quotes');
      expect(SYSTEM_INSTRUCTION).toContain('Invent dates');
      expect(SYSTEM_INSTRUCTION).toContain('state clearly that it is unclear or unspecified rather than guessing');
    });
  });

  describe('Cost Control & Deduplication', () => {
    test('DuplicateDetector skips articles already marked aiProcessed with current version', async () => {
      const fakeDb: any = {
        collection: (col: string) => ({
          doc: (docId: string) => ({
            get: async () => {
              if (docId === 'already-ai-processed') {
                return {
                  exists: true,
                  data: () => ({
                    aiProcessed: true,
                    aiPromptVersion: 'v1',
                    status: 'published',
                  }),
                };
              }
              if (docId === 'unprocessed-article') {
                return {
                  exists: true,
                  data: () => ({
                    aiProcessed: false,
                    status: 'published',
                  }),
                };
              }
              return { exists: false };
            },
          }),
        }),
      };

      const detector = new DuplicateDetector(fakeDb);

      // Already AI-processed article should be treated as duplicate (Cost Control)
      const isProcessedDup = await detector.isDuplicate('already-ai-processed', undefined, 'v1');
      expect(isProcessedDup).toBe(true);

      // Unprocessed article should NOT be skipped as duplicate so AI can enrich it
      const isUnprocessedDup = await detector.isDuplicate('unprocessed-article', undefined, 'v1');
      expect(isUnprocessedDup).toBe(false);
    });
  });

  describe('Security & Zero Secrets Leakage in Flutter Client', () => {
    test('verifies GEMINI_API_KEY is not present anywhere in client lib directory', () => {
      const flutterLibPath = path.resolve(__dirname, '../../lib');
      if (fs.existsSync(flutterLibPath)) {
        function scanDir(dir: string): string[] {
          let results: string[] = [];
          const list = fs.readdirSync(dir);
          for (const file of list) {
            const fullPath = path.join(dir, file);
            const stat = fs.statSync(fullPath);
            if (stat.isDirectory()) {
              results = results.concat(scanDir(fullPath));
            } else if (file.endsWith('.dart')) {
              results.push(fullPath);
            }
          }
          return results;
        }

        const dartFiles = scanDir(flutterLibPath);
        for (const file of dartFiles) {
          const content = fs.readFileSync(file, 'utf8');
          expect(content).not.toMatch(/GEMINI_API_KEY/i);
          expect(content).not.toMatch(/AIzaSy[A-Za-z0-9_-]{33}/); // Google API key regex pattern
          expect(content).not.toMatch(/generativelanguage\.googleapis\.com/i);
        }
      }
    });
  });
});
