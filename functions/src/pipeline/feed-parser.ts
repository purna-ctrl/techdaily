import { XMLParser } from 'fast-xml-parser';
import { decode } from 'html-entities';
import { ImageExtractor } from './image-extractor';
import { feedImageCandidate, ImageCandidate } from '../stories/images';

export interface RawFeedItem {
  title?: string;
  /** The exact post URL taken from the item's own <link>/<guid isPermaLink>. Never the channel link. */
  link?: string;
  description?: string;
  pubDate?: string;
  imageUrl?: string;
  /** Best usable image of the item with its declared size (v2 stories). */
  image?: ImageCandidate;
}

export class FeedParser {
  private static parser = new XMLParser({
    ignoreAttributes: false,
    attributeNamePrefix: '@_',
    trimValues: true,
    processEntities: false,
    htmlEntities: false,
    isArray: (name) => name === 'item' || name === 'entry',
  });

  /**
   * Parses raw XML string into an array of RawFeedItems.
   * Handles RSS 2.0, Atom, and RDF formats.
   */
  static parse(xmlString: string): RawFeedItem[] {
    if (!xmlString || typeof xmlString !== 'string') {
      return [];
    }

    let parsed: any;
    try {
      // Strip a UTF-8 BOM, which some publishers (e.g. PIB) prepend
      parsed = this.parser.parse(xmlString.replace(/^\uFEFF/, ''));
    } catch {
      return [];
    }

    if (!parsed) return [];

    const keep = (item: RawFeedItem): boolean => Boolean(item.link && item.title);

    // RSS 2.0
    if (parsed.rss && parsed.rss.channel) {
      const channel = Array.isArray(parsed.rss.channel) ? parsed.rss.channel[0] : parsed.rss.channel;
      const items = channel.item || [];
      return (Array.isArray(items) ? items : [items]).map((item: any) => this.extractRssItem(item)).filter(keep);
    }

    // Atom 1.0
    if (parsed.feed) {
      const entries = parsed.feed.entry || [];
      return (Array.isArray(entries) ? entries : [entries]).map((entry: any) => this.extractAtomEntry(entry)).filter(keep);
    }

    // RDF / RSS 1.0
    if (parsed['rdf:RDF']) {
      const items = parsed['rdf:RDF'].item || [];
      return (Array.isArray(items) ? items : [items]).map((item: any) => this.extractRssItem(item)).filter(keep);
    }

    return [];
  }

  /** Reads a text node that may be a plain string, a {#text} object, or an array of either. */
  static text(node: any): string {
    if (node == null) return '';
    if (typeof node === 'string') return node;
    if (typeof node === 'number') return String(node);
    if (Array.isArray(node)) return this.text(node[0]);
    if (typeof node === 'object' && node['#text'] != null) return String(node['#text']);
    return '';
  }

  /** Decodes entities and CDATA wrappers in a URL and validates it is http(s). */
  static cleanLink(raw: string): string {
    if (!raw) return '';
    const decoded = decode(raw.replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1').trim());
    try {
      const u = new URL(decoded);
      if (u.protocol !== 'http:' && u.protocol !== 'https:') return '';
      return decoded;
    } catch {
      return '';
    }
  }

  private static extractRssItem(item: any): RawFeedItem {
    const title = this.text(item.title);

    // Exact post URL: <link>, falling back to <guid isPermaLink="true"> (or a guid that is a URL),
    // and finally feedburner:origLink. Never the channel link.
    let link = this.cleanLink(this.text(item['feedburner:origLink'])) || this.cleanLink(this.text(item.link));
    if (!link && item.link && typeof item.link === 'object' && item.link['@_href']) {
      link = this.cleanLink(item.link['@_href']);
    }
    if (!link && item.guid) {
      const guidText = this.text(item.guid);
      const isPermaLink = typeof item.guid === 'object' ? item.guid['@_isPermaLink'] !== 'false' : true;
      if (isPermaLink) link = this.cleanLink(guidText);
    }

    const description =
      this.text(item['content:encoded']) || this.text(item.description) || this.text(item.summary) || '';
    const pubDate = this.text(item.pubDate) || this.text(item['dc:date']) || this.text(item.published) || '';

    return {
      title,
      link,
      description,
      pubDate,
      imageUrl: ImageExtractor.fromFeedItem(item, link || undefined),
      image: feedImageCandidate(item, link || undefined),
    };
  }

  private static extractAtomEntry(entry: any): RawFeedItem {
    const title = this.text(entry.title);

    let link = '';
    const links = entry.link == null ? [] : Array.isArray(entry.link) ? entry.link : [entry.link];
    const candidates = links
      .map((l: any) =>
        typeof l === 'string'
          ? { href: l, rel: 'alternate', type: '' }
          : { href: l?.['@_href'] || '', rel: l?.['@_rel'] || 'alternate', type: l?.['@_type'] || '' }
      )
      .filter((l: any) => l.href);
    const alt =
      candidates.find((l: any) => l.rel === 'alternate' && (!l.type || l.type.includes('html'))) ||
      candidates.find((l: any) => l.rel === 'alternate');
    if (alt) link = this.cleanLink(alt.href);
    if (!link && entry.id) {
      // Some Atom feeds only carry the permalink in <id>
      link = this.cleanLink(this.text(entry.id));
    }

    const description = this.text(entry.content) || this.text(entry.summary) || this.text(entry['content:encoded']) || '';
    const pubDate = this.text(entry.published) || this.text(entry.updated) || '';

    return {
      title,
      link,
      description,
      pubDate,
      imageUrl: ImageExtractor.fromFeedItem(entry, link || undefined),
      image: feedImageCandidate(entry, link || undefined),
    };
  }
}
