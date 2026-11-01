import { TrustedSourceConfig, TRUSTED_SOURCE_REGISTRY } from '../config/sources';

export interface DomainValidationResult {
  isValid: boolean;
  hostname?: string;
  reason?: string;
}

export class DomainValidator {
  /**
   * Validates an article URL against the trusted source configuration.
   * Defends strictly against malformed URLs, non-HTTP protocols, and domain spoofing.
   * e.g., "example.com.attacker.com" is strictly rejected for approved domain "example.com".
   */
  static validate(
    urlStr: string,
    expectedSource?: TrustedSourceConfig
  ): DomainValidationResult {
    if (!urlStr || typeof urlStr !== 'string') {
      return { isValid: false, reason: 'URL is empty or not a string' };
    }

    let parsedUrl: URL;
    try {
      parsedUrl = new URL(urlStr.trim());
    } catch {
      return { isValid: false, reason: 'Malformed URL could not be parsed' };
    }

    // Protocol check: strictly http or https
    if (parsedUrl.protocol !== 'http:' && parsedUrl.protocol !== 'https:') {
      return {
        isValid: false,
        reason: `Unsupported protocol "${parsedUrl.protocol}". Only HTTP/HTTPS allowed.`,
      };
    }

    const hostname = parsedUrl.hostname.toLowerCase().trim();

    // Reject IP addresses (IPv4 or IPv6)
    if (/^(\d{1,3}\.){3}\d{1,3}$/.test(hostname) || hostname.startsWith('[') || hostname.includes(':')) {
      return { isValid: false, hostname, reason: 'Numeric IP addresses are prohibited' };
    }

    // Reject empty or invalid hostnames
    if (!hostname || !hostname.includes('.')) {
      return { isValid: false, hostname, reason: 'Hostname is missing or has no top-level domain' };
    }

    // If expected source is provided, validate specifically against that source's domain
    if (expectedSource) {
      if (!this.matchesSource(hostname, expectedSource)) {
        return {
          isValid: false,
          hostname,
          reason: `Hostname "${hostname}" does not match approved domain "${expectedSource.domain}" for source ${expectedSource.sourceName}. Potential spoofing rejected.`,
        };
      }
      return { isValid: true, hostname };
    }

    // Otherwise, validate against ANY registered and enabled trusted domain
    const matchedSource = TRUSTED_SOURCE_REGISTRY.find(
      (source) => source.enabled && this.matchesSource(hostname, source)
    );

    if (!matchedSource) {
      return {
        isValid: false,
        hostname,
        reason: `Hostname "${hostname}" is not present in the trusted source registry.`,
      };
    }

    return { isValid: true, hostname };
  }

  /**
   * Checks whether hostname exactly equals approved domain or is a valid subdomain of it.
   * Examples:
   *  - "aws.amazon.com" matches "amazon.com" (ends with ".amazon.com")
   *  - "aws.amazon.com" matches "aws.amazon.com" (exact match)
   *  - "amazon.com.attacker.com" does NOT match "amazon.com"
   *  - "notamazon.com" does NOT match "amazon.com"
   */
  private static matchesSource(hostname: string, source: TrustedSourceConfig): boolean {
    const domains = [source.domain, ...(source.additionalDomains ?? [])];
    return domains.some((d) => this.matchesDomain(hostname, d));
  }

  private static matchesDomain(hostname: string, approvedDomain: string): boolean {
    const cleanHost = hostname.toLowerCase().trim();
    const cleanApproved = approvedDomain.toLowerCase().trim();

    if (cleanHost === cleanApproved) {
      return true;
    }

    return cleanHost.endsWith('.' + cleanApproved);
  }
}
