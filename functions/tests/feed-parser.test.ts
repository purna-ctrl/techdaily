import { FeedParser } from '../src/pipeline/feed-parser';

describe('FeedParser Tests', () => {
  test('parses RSS 2.0 feed', () => {
    const rssXml = `<?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0">
      <channel>
        <title>Tech News</title>
        <link>https://example.com</link>
        <item>
          <title>AWS Announces MicroVM Acceleration</title>
          <link>https://aws.amazon.com/blogs/aws/microvm-fast-boot/</link>
          <description><![CDATA[New copy-on-write memory snapshot capabilities reduce cold starts.]]></description>
          <pubDate>Wed, 16 Sep 2026 10:00:00 GMT</pubDate>
          <enclosure url="https://aws.amazon.com/images/arch.jpg" type="image/jpeg" />
        </item>
      </channel>
    </rss>`;

    const items = FeedParser.parse(rssXml);
    expect(items.length).toBe(1);
    expect(items[0].title).toBe('AWS Announces MicroVM Acceleration');
    expect(items[0].link).toBe('https://aws.amazon.com/blogs/aws/microvm-fast-boot/');
    expect(items[0].description).toContain('copy-on-write memory snapshot');
    expect(items[0].imageUrl).toBe('https://aws.amazon.com/images/arch.jpg');
  });

  test('parses Atom feed', () => {
    const atomXml = `<?xml version="1.0" encoding="utf-8"?>
    <feed xmlns="http://www.w3.org/2005/Atom">
      <title>GitHub Blog</title>
      <entry>
        <title>Git 3.0 Standardizes Cryptographic Hash Agility</title>
        <link rel="alternate" href="https://github.blog/git-3-0-release" />
        <summary>Upstream maintainers formalize SHA-256 object transitions.</summary>
        <published>2026-09-16T08:30:00Z</published>
      </entry>
    </feed>`;

    const items = FeedParser.parse(atomXml);
    expect(items.length).toBe(1);
    expect(items[0].title).toBe('Git 3.0 Standardizes Cryptographic Hash Agility');
    expect(items[0].link).toBe('https://github.blog/git-3-0-release');
    expect(items[0].description).toContain('SHA-256 object transitions');
  });

  test('returns empty array on malformed XML without throwing', () => {
    expect(FeedParser.parse('<broken <<xml>>>')).toEqual([]);
    expect(FeedParser.parse('')).toEqual([]);
  });
});
