/**
 * Deterministic simplification for the rule-based writer: turns a feed description into short,
 * plain sentences (simpler words, no asides) and guarantees no run of `n` (10) consecutive words is
 * copied from the reports — a sentence that can't be made original enough is dropped.
 */
import { findCopiedRun, wordList } from './text';

/** Publisher boilerplate that is never news. */
const JUNK = [
  /the post .{3,200}? appeared first on .{2,80}?\.?$/i,
  /\b(read more|continue reading|click here|also read|watch video|subscribe now|sign up)\b.*$/i,
  /\[(?:…|\.\.\.|&#8230;)\]/g,
  /\s*(?:…|\.\.\.)\s*$/,
];

/** Plain-word swaps (longest first). Applied case-insensitively, keeping the first letter's case. */
const SWAPS: Array<[string, string]> = [
  ['in order to', 'to'],
  ['a number of', 'several'],
  ['at this point in time', 'now'],
  ['with regard to', 'about'],
  ['in the wake of', 'after'],
  ['on the back of', 'after'],
  ['in a bid to', 'to'],
  ['is set to', 'will'],
  ['are set to', 'will'],
  ['is slated to', 'will'],
  ['is poised to', 'will'],
  ['is expected to', 'should'],
  ['are expected to', 'should'],
  ['prior to', 'before'],
  ['as well as', 'and'],
  ['announced', 'said'],
  ['announces', 'says'],
  ['unveiled', 'revealed'],
  ['unveils', 'reveals'],
  ['unveil', 'reveal'],
  ['launched', 'released'],
  ['launches', 'releases'],
  ['introduced', 'added'],
  ['introduces', 'adds'],
  ['rolled out', 'released'],
  ['rolls out', 'releases'],
  ['rolling out', 'releasing'],
  ['commenced', 'started'],
  ['commence', 'start'],
  ['approximately', 'about'],
  ['utilise', 'use'],
  ['utilize', 'use'],
  ['utilising', 'using'],
  ['utilizing', 'using'],
  ['purchase', 'buy'],
  ['purchased', 'bought'],
  ['additional', 'extra'],
  ['additionally', 'also'],
  ['however', 'but'],
  ['therefore', 'so'],
  ['consequently', 'so'],
  ['numerous', 'many'],
  ['individuals', 'people'],
  ['enables', 'lets'],
  ['enable', 'let'],
  ['allows', 'lets'],
  ['facilitate', 'help'],
  ['facilitates', 'helps'],
  ['leverage', 'use'],
  ['leverages', 'uses'],
  ['acquire', 'buy'],
  ['acquired', 'bought'],
  ['acquires', 'buys'],
  ['slashed', 'cut'],
  ['slashes', 'cuts'],
  ['hiked', 'raised'],
  ['soared', 'rose sharply'],
  ['plunged', 'fell sharply'],
  ['amid', 'during'],
  ['currently', 'now'],
  ['significant', 'big'],
  ['significantly', 'a lot'],
  ['substantial', 'large'],
  ['assist', 'help'],
  ['obtain', 'get'],
  ['sufficient', 'enough'],
  ['terminate', 'end'],
  ['regarding', 'about'],
  ['demonstrated', 'showed'],
  ['subsequently', 'later'],
  ['nevertheless', 'still'],
];

const SWAP_RE = SWAPS.map(([from, to]) => [new RegExp(`\\b${from.replace(/ /g, '\\s+')}\\b`, 'gi'), to] as const);

const SUBORDINATE_START = /^(after|while|as|since|when|although|though|if|because|whereas|unless|until|before|which|who|that|and|but|or|with|amid|during)\b/i;
const DANGLING_END = /\b(the|a|an|of|to|with|for|in|on|at|by|as|from|that|which|and|or|but|its|their|his|her)[.!?]?$/i;

/** A sentence a reader can take on its own: not a dangling clause or fragment. */
export function isStandalone(sentence: string): boolean {
  const t = sentence.trim();
  if (SUBORDINATE_START.test(t) && !/,/.test(t)) return false;
  if (DANGLING_END.test(t)) return false;
  // Unbalanced brackets = a cut-off aside.
  if (t.split('(').length !== t.split(')').length) return false;
  // Contact lines, photo credits and other page furniture.
  if (/\b(for more information|contact us|contact:|click here|follow us|subscribe|image credit|photo credit|credit:|all rights reserved)\b/i.test(t)) return false;
  if (/^[A-Z][\w.-]*\/[A-Z]/.test(t)) return false;
  // A short participle fragment ("Using the James Webb Space Telescope.").
  if (/^[A-Z][a-z]+ing\b/.test(t) && wordList(t).length < 9) return false;
  return wordList(t).length >= 6;
}

/** Small words that can be dropped to break up a copied run without changing the meaning much. */
const DROPPABLE = new Set(['the', 'a', 'an', 'that', 'its', 'their', 'also', 'now', 'very', 'just', 'has', 'have', 'really', 'currently']);

export function cleanSnippet(text: string): string {
  let t = (text || '').replace(/\s+/g, ' ').trim();
  for (const re of JUNK) t = t.replace(re, '').trim();
  return t;
}

export function splitSentences(text: string): string[] {
  const ABBR = /(?:\b(?:Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec|Mr|Mrs|Ms|Dr|Prof|Inc|Ltd|Co|Corp|vs|No|St|approx|est)|\b[ap]\.m|\b(?:[A-Z]\.){1,3}[A-Z]?|\be\.g|\bi\.e)\.$/i;
  const raw = (text || '').split(/(?<=[.!?])\s+(?=[A-Z₹"“'‘(0-9])/);
  const parts: string[] = [];
  for (const piece of raw) {
    const prev = parts[parts.length - 1];
    // Join back splits after abbreviations ("Nov.", "a.m.", "U.S.") and inside open brackets.
    if (prev !== undefined && (ABBR.test(prev) || (prev.split('(').length > prev.split(')').length))) parts[parts.length - 1] = `${prev} ${piece}`;
    else parts.push(piece);
  }
  for (let i = 0; i < parts.length; i++) parts[i] = parts[i].trim();
  // A feed description cut off mid-sentence ("... compared to about 25 km for s") loses its tail.
  if (parts.length && !/[.!?"”')]$/.test(parts[parts.length - 1])) parts.pop();
  return parts;
}

function swap(s: string): string {
  let out = s;
  for (const [re, to] of SWAP_RE) {
    out = out.replace(re, (m) => (m[0] === m[0].toUpperCase() && m[0] !== m[0].toLowerCase() ? to.charAt(0).toUpperCase() + to.slice(1) : to));
  }
  return out;
}

/** Simpler words, no brackets/asides/quotes-attribution tails, single spaces, ends with a full stop. */
export function simplifySentence(sentence: string): string {
  let s = sentence
    .replace(/\s*\([^)]{0,120}\)/g, '')
    .replace(/\s*\[[^\]]{0,120}\]/g, '')
    .replace(/,\s*(?:he|she|they|the company|the firm|it)\s+(?:said|added|noted|told [A-Z][\w ]{0,40})\.?$/i, '.')
    .replace(/,\s*according to [^,.]{2,80}/gi, '')
    .replace(/\s+—\s+[^—]{0,80}\s+—\s+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  s = swap(s);
  s = s.replace(/\s+([,.;:!?])/g, '$1');
  if (s && !/[.!?]$/.test(s)) s += '.';
  return s.charAt(0).toUpperCase() + s.slice(1);
}

/** Removes small words inside copied runs until no run of `n` words is copied. Null when it can't. */
export function breakCopies(sentence: string, sources: string[], n = 10): string | null {
  let words = sentence.split(/\s+/).filter(Boolean);
  for (let guard = 0; guard < 8; guard++) {
    const text = words.join(' ');
    const run = findCopiedRun(text, sources, n);
    if (!run) return text;
    const runWords = run.split(' ');
    // Locate the run in the sentence (compare normalised words).
    const norm = words.map((w) => wordList(w).join(' '));
    let start = -1;
    for (let i = 0; i + runWords.length <= norm.length && start < 0; i++) {
      let j = 0;
      let k = i;
      while (j < runWords.length && k < norm.length) {
        if (!norm[k]) {
          k++;
          continue;
        }
        if (norm[k] !== runWords[j]) break;
        j++;
        k++;
      }
      if (j === runWords.length) start = i;
    }
    if (start < 0) return null;
    // Drop the droppable word nearest the middle of the run; otherwise cut the sentence there.
    const mid = start + Math.floor(runWords.length / 2);
    let drop = -1;
    for (let d = 0; d < runWords.length && drop < 0; d++) {
      for (const idx of [mid - d, mid + d]) {
        if (idx > start && idx < start + runWords.length - 1 && DROPPABLE.has(norm[idx])) {
          drop = idx;
          break;
        }
      }
    }
    if (drop >= 0) {
      words.splice(drop, 1);
      continue;
    }
    // Cut at the last comma/semicolon before the copied run ends, if that leaves a full clause.
    const end = start + n - 1;
    let cut = -1;
    for (let i = end - 1; i >= 6; i--) {
      if (/[,;:]$/.test(words[i])) {
        cut = i + 1;
        break;
      }
    }
    if (cut < 0) return null;
    words = words.slice(0, cut);
    while (words.length && /^(and|or|but|the|a|an|of|to|with|for|in|on|at|by|as|from|that|which)[,;:]?$/i.test(words[words.length - 1])) words.pop();
    if (words.length < 7) return null;
    const last = words.length - 1;
    words[last] = words[last].replace(/[,;:]+$/, '');
    if (!/[.!?]$/.test(words[last])) words[last] += '.';
  }
  return null;
}

const CONNECTORS = /\s+(?:,\s*)?(?:in which|under which|through which|which|who|whereas|while|because|after|so that|and then|but|and)\s+|,\s+/i;

/**
 * Last resort for a long sentence that copies too much: split it at connector words (dropping the
 * connector), then rebuild "clause — clause, clause" from the pieces that are original enough.
 */
export function condense(sentence: string, sources: string[], n = 10, maxWords = 32): string | null {
  const body = sentence.replace(/[.!?]+$/, '');
  const clauses = body
    .split(CONNECTORS)
    .map((c) => c.trim().replace(/^(?:which|who|that|and|but)\s+/i, ''))
    .filter((c) => wordList(c).length >= 3);
  if (SUBORDINATE_START.test(clauses[0] ?? '')) return null;
  if (clauses.length < 2) return null;
  let acc = '';
  for (const c of clauses) {
    const cand = acc ? `${acc}${acc.includes(' — ') ? ', ' : ' — '}${c}` : c;
    if (wordList(cand).length > maxWords) break;
    const ok = breakCopies(`${cand}.`, sources, n);
    if (!ok) {
      if (!acc) return null;
      break;
    }
    acc = ok.replace(/[.!?]+$/, '');
  }
  if (wordList(acc).length < 6) return null;
  return `${acc.charAt(0).toUpperCase()}${acc.slice(1)}.`;
}

/**
 * Up to `max` plain sentences from the reports' descriptions (first report first), each 6-40 words,
 * never repeating the headline and never copying 10+ consecutive words.
 */
export interface PlainSentence {
  text: string;
  /** Index of the report the sentence came from, and of the sentence inside it. */
  report: number;
  index: number;
}

export function plainSentences(snippets: string[], headline: string, max = 3, n = 10): string[] {
  return plainSentencesAt(snippets, headline, max, n).map((x) => x.text);
}

/** Like plainSentences, with where each sentence came from (the lead sentence makes the best one-liner). */
export function plainSentencesAt(snippets: string[], headline: string, max = 3, n = 10): PlainSentence[] {
  const out: PlainSentence[] = [];
  const headWords = new Set(wordList(headline));
  const seen = new Set<string>();
  for (let r = 0; r < snippets.length; r++) {
    const list = splitSentences(cleanSnippet(snippets[r]));
    for (let index = 0; index < list.length; index++) {
      const raw = list[index];
      if (out.length >= max) return out;
      // Quotes are someone's exact words: never re-used.
      if (/[“”"]/.test(raw)) continue;
      const w = wordList(raw);
      if (w.length < 6) continue;
      // Skip near-copies of the headline (they add nothing under it).
      const overlap = w.filter((x) => headWords.has(x)).length / w.length;
      if (overlap > 0.85) continue;
      let s = simplifySentence(raw);
      if (wordList(s).length > 40) {
        // Keep the first clause(s) up to ~32 words.
        const parts = s.split(/(?<=[,;:])\s+/);
        let acc = '';
        for (const p of parts) {
          if (wordList(acc + ' ' + p).length > 32) break;
          acc = acc ? `${acc} ${p}` : p;
        }
        if (!acc) continue;
        s = acc.replace(/[,;:]+$/, '') + (/[.!?]$/.test(acc) ? '' : '.');
      }
      let fixed = breakCopies(s, snippets, n) ?? condense(s, snippets, n);
      if (!fixed || !isStandalone(fixed)) continue;
      // Two report sentences in a row can form a copied run across the boundary: "Also," breaks it.
      const prev = out[out.length - 1]?.text;
      if (prev && findCopiedRun(`${prev} ${fixed}`, snippets, n)) {
        fixed = `Also, ${fixed.charAt(0).toLowerCase()}${fixed.slice(1)}`;
        if (findCopiedRun(`${prev} ${fixed}`, snippets, n)) continue;
      }
      const key = wordList(fixed).slice(0, 8).join(' ');
      if (seen.has(key)) continue;
      seen.add(key);
      out.push({ text: fixed, report: r, index });
    }
  }
  return out;
}
