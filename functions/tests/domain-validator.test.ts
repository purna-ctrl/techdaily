import { DomainValidator } from '../src/pipeline/domain-validator';
import { TrustedSourceConfig } from '../src/config/sources';

describe('DomainValidator Security Tests', () => {
  const sampleSource: TrustedSourceConfig = {
    sourceId: 'aws-blog',
    sourceName: 'AWS Official Blog',
    domain: 'aws.amazon.com',
    feedUrl: 'https://aws.amazon.com/blogs/aws/feed/',
    defaultCategory: 'Cloud',
    enabled: true,
    trustLevel: 'high',
  };

  test('accepts exact approved domain', () => {
    const res = DomainValidator.validate('https://aws.amazon.com/blogs/aws/ec2-update', sampleSource);
    expect(res.isValid).toBe(true);
    expect(res.hostname).toBe('aws.amazon.com');
  });

  test('accepts approved subdomains', () => {
    const parentSource: TrustedSourceConfig = {
      ...sampleSource,
      domain: 'amazon.com',
    };
    const res = DomainValidator.validate('https://aws.amazon.com/blogs/aws/s3', parentSource);
    expect(res.isValid).toBe(true);
  });

  test('REJECTS malicious suffix spoofing (e.g. trusted.com.attacker.com)', () => {
    // Specifically mandated test case in instructions
    const maliciousUrl = 'https://aws.amazon.com.attacker.com/article';
    const res = DomainValidator.validate(maliciousUrl, sampleSource);
    expect(res.isValid).toBe(false);
    expect(res.reason).toContain('does not match approved domain');
  });

  test('REJECTS malicious path impersonation (e.g. attacker.com/trusted.com)', () => {
    const maliciousUrl = 'https://evil-hacker.com/aws.amazon.com/steal-creds';
    const res = DomainValidator.validate(maliciousUrl, sampleSource);
    expect(res.isValid).toBe(false);
  });

  test('REJECTS basic auth URL spoofing (e.g. http://trusted.com@attacker.com)', () => {
    const spoofedUrl = 'https://aws.amazon.com@attacker-site.com/exploit';
    const res = DomainValidator.validate(spoofedUrl, sampleSource);
    expect(res.isValid).toBe(false);
    expect(res.hostname).toBe('attacker-site.com');
  });

  test('REJECTS insecure and non-HTTP protocols', () => {
    expect(DomainValidator.validate('javascript:alert(1)', sampleSource).isValid).toBe(false);
    expect(DomainValidator.validate('file:///etc/passwd', sampleSource).isValid).toBe(false);
    expect(DomainValidator.validate('ftp://aws.amazon.com/file', sampleSource).isValid).toBe(false);
    expect(DomainValidator.validate('data:text/html,<script>', sampleSource).isValid).toBe(false);
  });

  test('REJECTS numeric IP addresses', () => {
    expect(DomainValidator.validate('https://192.168.1.1/article', sampleSource).isValid).toBe(false);
    expect(DomainValidator.validate('http://10.0.0.1/exploit', sampleSource).isValid).toBe(false);
  });

  test('REJECTS malformed and empty URLs', () => {
    expect(DomainValidator.validate('', sampleSource).isValid).toBe(false);
    expect(DomainValidator.validate('not a url', sampleSource).isValid).toBe(false);
    expect(DomainValidator.validate('http://', sampleSource).isValid).toBe(false);
  });

  test('validates against global registry when no source passed', () => {
    // Approved source in global registry
    const resGithub = DomainValidator.validate('https://github.blog/2026-09-update');
    expect(resGithub.isValid).toBe(true);

    // Unregistered domain
    const resUnknown = DomainValidator.validate('https://untrusted-blog-random.xyz/post');
    expect(resUnknown.isValid).toBe(false);
  });
});
