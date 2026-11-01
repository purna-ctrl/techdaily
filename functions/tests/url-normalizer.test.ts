import { UrlNormalizer } from '../src/pipeline/url-normalizer';

describe('UrlNormalizer Tests', () => {
  test('strips tracking query parameters (utm_*, fbclid, ref)', () => {
    const rawUrl = 'https://aws.amazon.com/blogs/aws/bedrock-news/?utm_source=twitter&utm_medium=social&utm_campaign=launch&fbclid=IwAR123&ref=techdaily&id=100';
    const clean = UrlNormalizer.canonicalize(rawUrl);

    expect(clean).toContain('id=100');
    expect(clean).not.toContain('utm_source');
    expect(clean).not.toContain('utm_medium');
    expect(clean).not.toContain('fbclid');
    expect(clean).not.toContain('ref=');
  });

  test('removes trailing slashes from path', () => {
    const rawUrl = 'https://github.blog/news/ai-models/';
    const clean = UrlNormalizer.canonicalize(rawUrl);
    expect(clean).toBe('https://github.blog/news/ai-models');
  });

  test('preserves root domain slash', () => {
    const rawUrl = 'https://github.blog/';
    const clean = UrlNormalizer.canonicalize(rawUrl);
    expect(clean).toBe('https://github.blog/');
  });

  test('drops hash fragments', () => {
    const rawUrl = 'https://blog.google/technology/ai/gemini-update#section-benchmark';
    const clean = UrlNormalizer.canonicalize(rawUrl);
    expect(clean).toBe('https://blog.google/technology/ai/gemini-update');
  });

  test('generates deterministic article ID', () => {
    const urlA = 'https://aws.amazon.com/blogs/aws/ec2-announcement';
    const urlB = 'https://aws.amazon.com/blogs/aws/ec2-announcement';
    const urlC = 'https://aws.amazon.com/blogs/aws/different-post';

    const idA = UrlNormalizer.generateArticleId(urlA);
    const idB = UrlNormalizer.generateArticleId(urlB);
    const idC = UrlNormalizer.generateArticleId(urlC);

    expect(idA).toBe(idB);
    expect(idA).not.toBe(idC);
    expect(idA).toMatch(/^art-[0-9a-f]{24}$/);
  });
});
