import { TRUSTED_SOURCE_REGISTRY } from '../src/config/sources';
import { AdminService } from '../src/admin/admin-service';
import { StructuredLogger } from '../src/monitoring/logger';
import { DailyBriefGenerator } from '../src/pipeline/daily-brief-generator';

describe('Admin System, Monitoring & Daily Brief Tests', () => {
  describe('StructuredLogger Security & Formatting', () => {
    test('masks Google API keys and bearer tokens in logs', () => {
      const sensitiveMsg = 'Call failed with AIzaSyD9876543210AbCdEfGhIjKlMnOpQrStU and Bearer secret-jwt-token-123';
      const logEvent = StructuredLogger.log('warn', 'test_event', sensitiveMsg);

      expect(logEvent.message).not.toContain('AIzaSyD9876543210AbCdEfGhIjKlMnOpQrStU');
      expect(logEvent.message).toContain('[MASKED_API_KEY]');
      expect(logEvent.message).not.toContain('secret-jwt-token-123');
      expect(logEvent.message).toContain('Bearer [MASKED_TOKEN]');
    });

    test('redacts password, secret, and auth fields in metadata', () => {
      const logEvent = StructuredLogger.log('info', 'auth_event', 'User login attempt', {
        metadata: {
          username: 'editor@techdaily.news',
          password: 'SecretPassword123!',
          apiSecret: 'SuperSecretKey999',
          authToken: 'token-xyz',
        },
      });

      expect(logEvent.metadata?.password).toBe('[REDACTED]');
      expect(logEvent.metadata?.apiSecret).toBe('[REDACTED]');
      expect(logEvent.metadata?.authToken).toBe('[REDACTED]');
      expect(logEvent.metadata?.username).toBe('editor@techdaily.news');
    });
  });

  describe('AdminService Source Management', () => {
    test('initializes every trusted source in the registry', async () => {
      const adminService = new AdminService();
      const status = await adminService.getAllSourcesStatus();

      expect(status.length).toBe(TRUSTED_SOURCE_REGISTRY.length);
      expect(status.length).toBeGreaterThanOrEqual(16);
      const awsSource = status.find((s) => s.sourceId === 'aws-blog');
      expect(awsSource).toBeDefined();
      expect(awsSource?.enabled).toBe(true);
      expect(awsSource?.failureCount).toBe(0);
    });

    test('toggles source enabled status', async () => {
      const adminService = new AdminService();

      const toggled = await adminService.toggleSource('aws-blog', false);
      expect(toggled).toBe(true);

      const status = await adminService.getAllSourcesStatus();
      const awsSource = status.find((s) => s.sourceId === 'aws-blog');
      expect(awsSource?.enabled).toBe(false);

      // Re-enable
      await adminService.toggleSource('aws-blog', true);
      const updated = await adminService.getAllSourcesStatus();
      expect(updated.find((s) => s.sourceId === 'aws-blog')?.enabled).toBe(true);
    });

    test('records source failure and increments count', async () => {
      const adminService = new AdminService();

      await adminService.recordSourceFailure('broken-feed', '503 Service Unavailable');
      const status = await adminService.getAllSourcesStatus();
      const record = status.find((s) => s.sourceId === 'broken-feed');

      expect(record).toBeUndefined(); // 'broken-feed' is not in default registry, handled gracefully

      await adminService.recordSourceFailure('github-blog', '429 Rate Limit Exceeded');
      const ghRecord = (await adminService.getAllSourcesStatus()).find((s) => s.sourceId === 'github-blog');
      expect(ghRecord?.failureCount).toBe(1);
      expect(ghRecord?.lastFailure).toContain('429');

      // Success resets failure count
      await adminService.recordSourceSuccess('github-blog');
      const ghRecordReset = (await adminService.getAllSourcesStatus()).find((s) => s.sourceId === 'github-blog');
      expect(ghRecordReset?.failureCount).toBe(0);
      expect(ghRecordReset?.lastSuccessfulFetch).toBeTruthy();
    });

    test('soft-deletes invalid article', async () => {
      let updatedStatus = '';
      const fakeDb: any = {
        collection: () => ({
          doc: (docId: string) => ({
            get: async () => ({ exists: true }),
            update: async (data: any) => {
              updatedStatus = data.status;
            },
          }),
        }),
      };

      const adminService = new AdminService(fakeDb);
      const removed = await adminService.removeArticle('art-invalid-1', 'Editorial retraction');

      expect(removed).toBe(true);
      expect(updatedStatus).toBe('removed');
    });
  });

  describe('DailyBriefGenerator Logic', () => {
    test('generates 10-item structured daily brief from Firestore articles', async () => {
      const mockArticles = Array.from({ length: 15 }, (_, i) => ({
        id: `art-${i}`,
        data: () => ({
          title: `Technology Breakthrough ${i + 1}`,
          summary: `Summary for article ${i + 1}`,
          whyItMatters: `This matters significantly for industry sector ${i + 1}`,
          category: 'Software',
          sourceName: `Source ${i % 5}`,
          sourceUrl: `https://example.com/story-${i}`,
          publishedAt: new Date(),
          status: 'published',
        }),
      }));

      let savedBrief: any;
      const fakeDb: any = {
        collection: (col: string) => ({
          where: () => ({
            orderBy: () => ({
              limit: () => ({
                get: async () => ({
                  empty: false,
                  docs: mockArticles,
                }),
              }),
            }),
          }),
          doc: (docId: string) => ({
            set: async (data: any) => {
              savedBrief = data;
            },
          }),
        }),
      };

      const generator = new DailyBriefGenerator(fakeDb);
      const brief = await generator.generateDailyBrief(new Date('2026-09-16T12:00:00Z'));

      expect(brief).toBeDefined();
      expect(brief?.items.length).toBe(10);
      expect(brief?.title).toBe('TODAY IN TECH');
      expect(brief?.items[0].rank).toBe(1);
      expect(brief?.items[0].headline).toBe('Technology Breakthrough 1');
      expect(brief?.items[0].whyItMatters).toContain('This matters significantly');
      expect(savedBrief).toBeDefined();
      expect(savedBrief.id).toBe('brief-2026-09-16');
    });
  });
});
