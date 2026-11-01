import { IngestionEngine } from '../src/pipeline/ingestion-engine';
import { TrustedSourceConfig } from '../src/config/sources';

describe('IngestionEngine End-to-End Tests', () => {
  const mockSourceA: TrustedSourceConfig = {
    sourceId: 'aws-blog',
    sourceName: 'AWS Official Blog',
    domain: 'aws.amazon.com',
    feedUrl: 'https://aws.amazon.com/blogs/aws/feed/',
    defaultCategory: 'Cloud',
    enabled: true,
    trustLevel: 'high',
  };

  const sampleValidRss = `<?xml version="1.0" encoding="UTF-8"?>
  <rss version="2.0">
    <channel>
      <title>AWS News</title>
      <item>
        <title>New Kubernetes Automated Kernel-Bypass Networking on AWS</title>
        <link>https://aws.amazon.com/blogs/aws/k8s-kernel-bypass/</link>
        <description><![CDATA[Data center networking throughput improvements for container clusters.]]></description>
        <pubDate>Wed, 16 Sep 2026 10:00:00 GMT</pubDate>
      </item>
      <item>
        <title>Spoofed Article Attempting Impersonation</title>
        <link>https://aws.amazon.com.attacker.com/malicious-phishing-story</link>
        <description><![CDATA[Attackers attempting to inject malicious URLs into the database.]]></description>
        <pubDate>Wed, 16 Sep 2026 10:05:00 GMT</pubDate>
      </item>
    </channel>
  </rss>`;

  test('accepts valid domain articles and rejects spoofed domain articles', async () => {
    const mockFetcher = async () => sampleValidRss;
    const engine = new IngestionEngine(undefined, undefined, mockFetcher);

    const stats = await engine.processSource(mockSourceA, true);

    expect(stats.status).toBe('success');
    expect(stats.totalFound).toBe(2);
    expect(stats.accepted).toBe(1); // The authentic aws.amazon.com article
    expect(stats.rejected).toBe(1); // The spoofed aws.amazon.com.attacker.com article
    expect(stats.duplicates).toBe(0);
  });

  test('prevents duplicate articles when run repeatedly', async () => {
    const mockFetcher = async () => sampleValidRss;
    const engine = new IngestionEngine(undefined, undefined, mockFetcher);

    // Run 1
    const run1 = await engine.processSource(mockSourceA, true);
    expect(run1.accepted).toBe(1);
    expect(run1.duplicates).toBe(0);

    // Run 2 on same feed
    const run2 = await engine.processSource(mockSourceA, true);
    expect(run2.accepted).toBe(0);
    expect(run2.duplicates).toBe(1); // Previously accepted article detected as duplicate!
  });

  test('isolates failures: failing source does not crash other sources', async () => {
    const failingSource: TrustedSourceConfig = {
      sourceId: 'broken-feed',
      sourceName: 'Broken Feed',
      domain: 'broken.com',
      feedUrl: 'https://broken.com/feed',
      defaultCategory: 'Software',
      enabled: true,
      trustLevel: 'high',
    };

    const mockFetcher = async (url: string) => {
      if (url.includes('broken.com')) {
        throw new Error('500 Internal Server Error');
      }
      return sampleValidRss;
    };

    const engine = new IngestionEngine(undefined, undefined, mockFetcher);

    // Process failing source
    const failStats = await engine.processSource(failingSource, true);
    expect(failStats.status).toBe('failed');
    expect(failStats.error).toContain('500');

    // Process healthy source immediately after
    const healthyStats = await engine.processSource(mockSourceA, true);
    expect(healthyStats.status).toBe('success');
    expect(healthyStats.accepted).toBe(1);
  });
});
