/**
 * Static HTML for crawlers, link previews and no-JS readers. Every page is self-contained (inline
 * CSS, optional tiny inline JS for copy/native share/newsletter), dark theme, mobile-first.
 */
import { CATEGORIES, categoryLabel, TOP_STORIES } from '../categories';
import { escapeHtml as h, escapeXml, formatIst, jsonForScript, truncate } from '../text';
import { Story } from '../types';
import { TodayInFive } from '../ranking';

export interface SiteContext {
  siteUrl: string; // no trailing slash
  firebaseProjectId: string;
  now: number;
}

export const SITE_NAME = 'TechDaily';
export const SITE_TAGLINE = 'Tech news in simple words';
export const DEFAULT_SITE_URL = 'https://techdaily-prod.web.app';

export const storyPath = (s: Pick<Story, 'slug'>) => `/story/${encodeURIComponent(s.slug)}/`;
export const categoryPath = (id: string) => `/c/${id}/`;
export const ogImageFor = (ctx: SiteContext, category: string) => `${ctx.siteUrl}/og/${category}.png`;

/** WhatsApp share link: headline + story URL. */
export function whatsappUrl(headline: string, url: string): string {
  return `https://wa.me/?text=${encodeURIComponent(`${headline}\n\n${url}`)}`;
}

export function metaDescription(s: Story): string {
  return truncate(`${s.whatHappened} ${s.whatItMeans}`.replace(/\s+/g, ' '), 158);
}

export function sourceNames(s: Story): string[] {
  return [...new Set(s.sources.map((x) => x.name).filter(Boolean))];
}

// Contrast (on #0B0B0F): ink 17.6:1, muted #B9B5AD 9.6:1, accent #FF6A33 6.9:1, focus #FFD166 13.6:1.
// On card surface #15151B: muted 8.9:1, accent 6.3:1. Button text #0B0B0F on #FF6A33: 6.9:1.
export const CSS = `:root{color-scheme:dark;--bg:#0B0B0F;--sf:#15151B;--sf2:#1E1E26;--ink:#F4F2EC;--mu:#B9B5AD;--ac:#FF6A33;--bd:#2E2E38;--warn:#FFD166}
*{box-sizing:border-box}html{-webkit-text-size-adjust:100%}
body{margin:0;background:var(--bg);color:var(--ink);font:17px/1.6 Inter,system-ui,-apple-system,"Segoe UI",Roboto,"Noto Sans",sans-serif}
a{color:var(--ac);text-underline-offset:3px}a:hover{text-decoration-thickness:2px}
a:focus-visible,button:focus-visible,input:focus-visible,summary:focus-visible{outline:3px solid var(--warn);outline-offset:2px;border-radius:6px}
.skip{position:absolute;left:-9999px;top:8px}.skip:focus{left:8px;z-index:10;background:var(--ink);color:var(--bg);padding:8px 12px;border-radius:6px}
.top{border-bottom:1px solid var(--bd);background:var(--bg)}
.bar{max-width:760px;margin:0 auto;padding:12px 16px;display:flex;align-items:center;justify-content:space-between;gap:12px}
.brand{font:700 21px/1 "Space Grotesk",system-ui,sans-serif;color:var(--ink);text-decoration:none;letter-spacing:-.3px}.brand span{color:var(--ac)}
.cats{max-width:760px;margin:0 auto;padding:0 16px 10px;display:flex;gap:6px;overflow-x:auto;scrollbar-width:none}
.cats a{flex:none;padding:6px 12px;border:1px solid var(--bd);border-radius:999px;color:var(--ink);text-decoration:none;font-size:14px;line-height:1.3}
.cats a[aria-current=page]{background:var(--ink);color:var(--bg);border-color:var(--ink)}
main{max-width:760px;margin:0 auto;padding:16px 16px 40px}
.tag{display:inline-block;font:700 12px/1 Inter,system-ui,sans-serif;letter-spacing:.08em;text-transform:uppercase;color:var(--ac);text-decoration:none}
.dev{display:inline-block;margin-left:8px;padding:3px 8px;border-radius:999px;font:700 11px/1.2 Inter,system-ui,sans-serif;letter-spacing:.04em;text-transform:uppercase;background:#2B2205;color:var(--warn);border:1px solid #5C4A0B}
h1{font:700 clamp(26px,6.4vw,38px)/1.15 "Space Grotesk",system-ui,sans-serif;letter-spacing:-.5px;margin:.35em 0 .3em}
h2{font:700 19px/1.3 "Space Grotesk",system-ui,sans-serif;margin:0 0 6px}
.meta{color:var(--mu);font-size:14.5px;margin:0 0 8px}
.card{background:var(--sf);border:1px solid var(--bd);border-radius:16px;padding:16px 18px;margin:14px 0}
.card p{margin:0}.card ol,.card ul{margin:4px 0 0;padding-left:22px}.card li{margin:4px 0}
.card.scam{border-color:#7A2E12;background:#1A1210}
.card.mean{border-color:var(--ac)}
.note{color:var(--mu);font-size:14px}
.btn{display:inline-flex;align-items:center;gap:6px;min-height:44px;background:var(--ac);color:#0B0B0F;font:700 15px/1 Inter,system-ui,sans-serif;padding:12px 16px;border-radius:999px;text-decoration:none;border:0;cursor:pointer}
.btn.alt{background:transparent;color:var(--ink);border:1px solid var(--bd)}
.row{display:flex;flex-wrap:wrap;gap:8px;margin-top:8px}
.list{list-style:none;padding:0;margin:0}
.item{border-bottom:1px solid var(--bd);padding:14px 0}.item:last-child{border-bottom:0}
.item h3{font:700 19px/1.3 "Space Grotesk",system-ui,sans-serif;margin:4px 0}.item h3 a{color:var(--ink);text-decoration:none}.item h3 a:hover{text-decoration:underline}
.item p{margin:4px 0 0;color:var(--mu);font-size:15.5px}
.five{counter-reset:n;list-style:none;padding:0;margin:0}.five li{counter-increment:n;display:flex;gap:12px;padding:10px 0;border-bottom:1px solid var(--bd)}
.five li:before{content:counter(n);font:700 22px/1 "Space Grotesk",system-ui,sans-serif;color:var(--ac);min-width:20px}
.five a{color:var(--ink);font-weight:600;text-decoration:none}.five a:hover{text-decoration:underline}
form.signup{display:flex;flex-wrap:wrap;gap:8px;align-items:center;margin-top:8px}
form.signup label{flex-basis:100%;font-weight:600}
form.signup input{flex:1 1 220px;min-height:44px;padding:10px 14px;border-radius:12px;border:1px solid #55555F;background:var(--sf2);color:var(--ink);font:16px Inter,system-ui,sans-serif}
.msg{flex-basis:100%;margin:4px 0 0;color:var(--mu);font-size:14px;min-height:1em}
footer{border-top:1px solid var(--bd);color:var(--mu);font-size:14px}footer .bar{display:block}footer a{color:var(--ink)}
@media (prefers-reduced-motion:no-preference){a,.btn{transition:opacity .15s}}`;

function head(ctx: SiteContext, o: { title: string; description: string; path: string; image: string; type: 'article' | 'website'; extra?: string; jsonLd?: unknown }): string {
  const url = `${ctx.siteUrl}${o.path}`;
  return `<!doctype html>
<html lang="en-IN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>${h(o.title)}</title>
<meta name="description" content="${h(o.description)}">
<link rel="canonical" href="${h(url)}">
<meta name="theme-color" content="#0B0B0F">
<meta name="color-scheme" content="dark">
<meta property="og:site_name" content="${SITE_NAME}">
<meta property="og:type" content="${o.type}">
<meta property="og:title" content="${h(o.title)}">
<meta property="og:description" content="${h(o.description)}">
<meta property="og:url" content="${h(url)}">
<meta property="og:image" content="${h(o.image)}">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta property="og:image:alt" content="${h(o.title)}">
<meta property="og:locale" content="en_IN">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="${h(o.title)}">
<meta name="twitter:description" content="${h(o.description)}">
<meta name="twitter:image" content="${h(o.image)}">
${o.extra ?? ''}<link rel="icon" type="image/png" href="/favicon.png">
<link rel="apple-touch-icon" href="/icons/apple-touch-icon.png">
<link rel="manifest" href="/manifest.json">
<link rel="alternate" type="application/rss+xml" title="TechDaily" href="/rss.xml">
${o.jsonLd ? `<script type="application/ld+json">${jsonForScript(o.jsonLd)}</script>\n` : ''}<style>${CSS}</style>
</head>`;
}

function topBar(current?: string): string {
  const links = [
    `<a href="/"${current === TOP_STORIES.id ? ' aria-current="page"' : ''}>${TOP_STORIES.label}</a>`,
    ...CATEGORIES.map((c) => `<a href="${categoryPath(c.id)}"${current === c.id ? ' aria-current="page"' : ''}>${h(c.label)}</a>`),
  ];
  return `<a class="skip" href="#main">Skip to content</a>
<header class="top"><div class="bar"><a class="brand" href="/">Tech<span>Daily</span></a><a class="btn alt" href="/app/">Open app</a></div>
<nav class="cats" aria-label="Categories">${links.join('')}</nav></header>`;
}

export function signupForm(ctx: SiteContext, source: string): string {
  return `<form class="signup" action="/app/newsletter" method="get" data-source="${h(source)}" data-project="${h(ctx.firebaseProjectId)}">
<label for="td-email">Get “Today in 5” by email — free</label>
<input id="td-email" name="email" type="email" inputmode="email" autocomplete="email" required maxlength="254" placeholder="you@example.com">
<button class="btn" type="submit">Sign up</button>
<p class="msg" role="status" aria-live="polite"></p>
</form>`;
}

function footer(ctx: SiteContext, withSignup = true): string {
  return `<footer><div class="bar">
${withSignup ? `<section class="card" aria-labelledby="nl-h"><h2 id="nl-h">Newsletter</h2>${signupForm(ctx, 'web-footer')}</section>` : ''}
<p>TechDaily explains technology news for everyday people in India, in simple words. Story cards are written by AI from the original reports and checked automatically; always read the original before acting on money or security advice. If you lost money to a scam, call <strong>1930</strong> or report at <a href="https://cybercrime.gov.in">cybercrime.gov.in</a>.</p>
<p><a href="/app/about">About</a> · <a href="/rss.xml">RSS</a> · <a href="/sitemap.xml">Sitemap</a> · <a href="/app/">Open the app</a></p>
</div></footer>`;
}

/** Progressive enhancement only: copy link, native share sheet, and the newsletter POST. */
export function pageScript(): string {
  return `<script>
(function(){
var d=document;
d.querySelectorAll('[data-copy]').forEach(function(b){b.hidden=false;b.addEventListener('click',function(){var u=b.getAttribute('data-copy');(navigator.clipboard?navigator.clipboard.writeText(u):Promise.reject()).then(function(){b.textContent='Link copied';},function(){window.prompt('Copy this link',u);});});});
d.querySelectorAll('[data-share]').forEach(function(b){if(!navigator.share)return;b.hidden=false;b.addEventListener('click',function(){navigator.share({title:b.getAttribute('data-title'),url:b.getAttribute('data-share')}).catch(function(){});});});
d.querySelectorAll('form.signup').forEach(function(f){f.addEventListener('submit',function(e){
var i=f.querySelector('input[type=email]'),m=f.querySelector('.msg'),v=(i.value||'').trim().toLowerCase();
if(!/^[^\\s@]+@[^\\s@]+\\.[^\\s@]{2,}$/.test(v)||v.length>254){e.preventDefault();m.textContent='Please enter a valid email address.';i.focus();return;}
if(!window.fetch)return;e.preventDefault();m.textContent='Signing you up…';
var p=f.getAttribute('data-project'),id=Date.now().toString(36)+Math.random().toString(36).slice(2,10),base='projects/'+p+'/databases/(default)/documents';
fetch('https://firestore.googleapis.com/v1/'+base+':commit',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({writes:[{update:{name:base+'/signups/'+id,fields:{email:{stringValue:v},source:{stringValue:f.getAttribute('data-source')||'web'}}},updateTransforms:[{fieldPath:'createdAt',setToServerValue:'REQUEST_TIME'}],currentDocument:{exists:false}}]})})
.then(function(r){if(!r.ok)throw 0;m.textContent='Thanks! You are on the list.';f.reset();}).catch(function(){m.textContent='Could not sign you up right now. Please try again later.';});
});});
})();
</script>`;
}

function timeTag(iso: string): string {
  return `<time datetime="${h(iso)}">${h(formatIst(iso))}</time>`;
}

function shareBlock(s: Story, url: string): string {
  return `<div class="row">
<a class="btn" href="${h(whatsappUrl(s.headline, url))}" rel="noopener">Share on WhatsApp</a>
<button class="btn alt" type="button" data-share="${h(url)}" data-title="${h(s.headline)}" hidden>Share…</button>
<button class="btn alt" type="button" data-copy="${h(url)}" hidden>Copy link</button>
<a class="btn alt" href="https://t.me/share/url?url=${encodeURIComponent(url)}&amp;text=${encodeURIComponent(s.headline)}" rel="noopener">Telegram</a>
<a class="btn alt" href="https://twitter.com/intent/tweet?url=${encodeURIComponent(url)}&amp;text=${encodeURIComponent(s.headline)}" rel="noopener">X</a>
</div>`;
}

export function newsArticleJsonLd(s: Story, ctx: SiteContext): Record<string, unknown> {
  const url = `${ctx.siteUrl}${storyPath(s)}`;
  return {
    '@context': 'https://schema.org',
    '@type': 'NewsArticle',
    headline: truncate(s.headline, 110),
    description: metaDescription(s),
    datePublished: s.publishedAt,
    dateModified: s.updatedAt,
    articleSection: categoryLabel(s.category),
    inLanguage: 'en-IN',
    url,
    mainEntityOfPage: { '@type': 'WebPage', '@id': url },
    image: [ogImageFor(ctx, s.category)],
    author: { '@type': 'Organization', name: SITE_NAME, url: ctx.siteUrl },
    publisher: {
      '@type': 'Organization',
      name: SITE_NAME,
      url: ctx.siteUrl,
      logo: { '@type': 'ImageObject', url: `${ctx.siteUrl}/icons/Icon-512.png`, width: 512, height: 512 },
    },
    isBasedOn: s.sources.map((x) => x.url),
    citation: s.sources.map((x) => ({ '@type': 'CreativeWork', name: x.title || x.name, url: x.url, publisher: { '@type': 'Organization', name: x.name } })),
  };
}

export function renderStoryPage(s: Story, ctx: SiteContext, related: Story[] = []): string {
  const url = `${ctx.siteUrl}${storyPath(s)}`;
  const names = sourceNames(s);
  const title = `${s.headline} | ${SITE_NAME}`;
  const desc = metaDescription(s);
  const extra = `<meta property="article:published_time" content="${h(s.publishedAt)}">
<meta property="article:modified_time" content="${h(s.updatedAt)}">
<meta property="article:section" content="${h(categoryLabel(s.category))}">
`;
  const scam = s.scam
    ? `<section class="card scam" aria-labelledby="h-how"><h2 id="h-how">How the trick works</h2><p>${h(s.scam.howItWorks)}</p></section>
<section class="card scam" aria-labelledby="h-signs"><h2 id="h-signs">Warning signs</h2><ul>${s.scam.warningSigns.map((x) => `<li>${h(x)}</li>`).join('')}</ul></section>
<section class="card scam" aria-labelledby="h-target"><h2 id="h-target">What to do if you’re targeted</h2><ol>${s.scam.ifTargeted.map((x) => `<li>${h(x)}</li>`).join('')}</ol>
<p class="note" style="margin-top:8px">India: call the cyber-crime helpline <strong>1930</strong> or report at <a href="https://cybercrime.gov.in">cybercrime.gov.in</a>.</p></section>
${s.scam.advisoryUrl ? `<p><a class="btn alt" href="${h(s.scam.advisoryUrl)}" rel="noopener">Read the official advisory</a></p>` : ''}`
    : '';
  const rel = related.length
    ? `<section aria-labelledby="h-more"><h2 id="h-more">More in ${h(categoryLabel(s.category))}</h2><ul class="list">${related
        .map((r) => `<li class="item"><h3><a href="${h(storyPath(r))}">${h(r.headline)}</a></h3><p class="meta">${timeTag(r.publishedAt)}</p></li>`)
        .join('')}</ul></section>`
    : '';
  return `${head(ctx, { title, description: desc, path: storyPath(s), image: ogImageFor(ctx, s.category), type: 'article', extra, jsonLd: newsArticleJsonLd(s, ctx) })}
<body>
${topBar(s.category)}
<main id="main">
<article>
<p><a class="tag" href="${categoryPath(s.category)}">${h(categoryLabel(s.category))}</a>${s.developing ? '<span class="dev" title="Few or unconfirmed reports so far — details may change">Developing</span>' : ''}</p>
<h1>${h(s.headline)}</h1>
<p class="meta">${timeTag(s.publishedAt)} · ${names.length > 1 ? `${names.length} sources: ` : 'Source: '}${h(names.join(', '))}</p>
<section class="card" aria-labelledby="h-what"><h2 id="h-what">What happened</h2><p>${h(s.whatHappened)}</p></section>
<section class="card" aria-labelledby="h-who"><h2 id="h-who">Does it affect me?</h2><p>${h(s.affectsWho)}</p></section>
${s.scam ? '' : `<section class="card" aria-labelledby="h-todo"><h2 id="h-todo">What to do</h2><ol>${s.whatToDo.map((x) => `<li>${h(x)}</li>`).join('')}</ol></section>`}
${scam}
${s.scam ? `<section class="card" aria-labelledby="h-todo"><h2 id="h-todo">What to do</h2><ol>${s.whatToDo.map((x) => `<li>${h(x)}</li>`).join('')}</ol></section>` : ''}
<section class="card mean" aria-labelledby="h-mean"><h2 id="h-mean">What this means for you</h2><p>${h(s.whatItMeans)}</p></section>
<section class="card" aria-labelledby="h-orig"><h2 id="h-orig">Read the original${s.sources.length > 1 ? 's' : ''}</h2><ul>${s.sources
    .map((x) => `<li><a href="${h(x.url)}" rel="noopener">${h(x.name)}${x.title ? `: ${h(x.title)}` : ''}</a> <span class="note">· ${timeTag(x.publishedAt)}</span></li>`)
    .join('')}</ul>
<p class="note" style="margin-top:8px">${s.aiModel.startsWith('techdaily-fallback') ? 'Short version written automatically from the report headline' : 'Written in simple words by AI from the reports above'}; last updated ${timeTag(s.updatedAt)}.</p></section>
<section aria-labelledby="h-share"><h2 id="h-share">Share this story</h2>${shareBlock(s, url)}
<p class="row"><a class="btn alt" href="/app/story/${encodeURIComponent(s.slug)}">Open in app</a></p></section>
</article>
${rel}
</main>
${footer(ctx)}
${pageScript()}
</body>
</html>
`;
}

function storyListItem(s: Story): string {
  return `<li class="item"><a class="tag" href="${categoryPath(s.category)}">${h(categoryLabel(s.category))}</a>${s.developing ? '<span class="dev">Developing</span>' : ''}
<h3><a href="${h(storyPath(s))}">${h(s.headline)}</a></h3>
<p class="meta">${timeTag(s.publishedAt)} · ${h(sourceNames(s).join(', '))}</p>
${s.aiModel.startsWith('techdaily-fallback') ? '' : `<p>${h(truncate(s.whatHappened, 220))}</p>`}</li>`;
}

export function renderCategoryPage(categoryId: string, stories: Story[], ctx: SiteContext): string {
  const label = categoryLabel(categoryId);
  const title = `${label} news in simple words | ${SITE_NAME}`;
  const desc = truncate(
    `The latest ${label} news for India, explained in simple words: what happened, does it affect you and what to do. ${stories[0] ? 'Latest: ' + stories[0].headline : ''}`,
    158
  );
  const jsonLd = {
    '@context': 'https://schema.org',
    '@type': 'CollectionPage',
    name: title,
    url: `${ctx.siteUrl}${categoryPath(categoryId)}`,
    mainEntity: {
      '@type': 'ItemList',
      itemListElement: stories.slice(0, 20).map((s, i) => ({ '@type': 'ListItem', position: i + 1, url: `${ctx.siteUrl}${storyPath(s)}`, name: s.headline })),
    },
  };
  return `${head(ctx, { title, description: desc, path: categoryPath(categoryId), image: ogImageFor(ctx, categoryId), type: 'website', jsonLd })}
<body>
${topBar(categoryId)}
<main id="main">
<h1>${h(label)}</h1>
<p class="meta">Updated ${timeTag(new Date(ctx.now).toISOString())}</p>
${stories.length ? `<ul class="list">${stories.map(storyListItem).join('')}</ul>` : '<p>No stories yet — check back soon.</p>'}
</main>
${footer(ctx)}
${pageScript()}
</body>
</html>
`;
}

/** Block injected into the Flutter index.html so crawlers and no-JS readers see real content. */
export function renderIndexSeoBlock(today: TodayInFive, latest: Story[], ctx: SiteContext, bySlug: Map<string, Story>): string {
  const five = today.items
    .map((i) => {
      const s = bySlug.get(i.slug);
      return `<li><div><a href="/story/${encodeURIComponent(i.slug)}/">${h(i.headline)}</a>${s ? `<div class="meta">${h(categoryLabel(i.category))} · ${timeTag(s.publishedAt)}</div>` : ''}</div></li>`;
    })
    .join('');
  return `<!--TD-SEO-->
<div id="td-seo">
<style>${CSS}#td-seo{min-height:100vh}</style>
${topBar(TOP_STORIES.id)}
<main id="main">
<h1>TechDaily — tech news in simple words</h1>
<p class="meta">AI, phones, chips, startups, money, privacy, and scams &amp; security — explained for everyday people in India. Updated ${timeTag(today.generatedAt)}.</p>
<section class="card" aria-labelledby="t5"><h2 id="t5">Today in 5 stories</h2><ol class="five">${five}</ol></section>
<section aria-labelledby="lt"><h2 id="lt">Latest stories</h2><ul class="list">${latest.map(storyListItem).join('')}</ul></section>
</main>
${footer(ctx)}
</div>
<!--/TD-SEO-->`;
}

/** Inserts/replaces the SEO block and Today-in-5 description in the Flutter index.html. */
export function injectIntoIndex(indexHtml: string, block: string, today: TodayInFive): string {
  let out = indexHtml;
  const re = /<!--TD-SEO-->[\s\S]*?<!--\/TD-SEO-->/;
  if (re.test(out)) out = out.replace(re, () => block);
  else out = out.replace(/<body([^>]*)>/i, (m) => `${m}\n${block}`);
  if (today.items[0]) {
    const desc = truncate(`Today in 5: ${today.items.map((i) => i.headline).join(' · ')}`, 158);
    out = out.replace(/(<meta name="description" content=")[^"]*(")/, (_m, a, b) => `${a}${h(desc)}${b}`);
  }
  return out;
}

export function renderSitemap(stories: Story[], ctx: SiteContext): string {
  const urls = [
    { loc: `${ctx.siteUrl}/`, lastmod: new Date(ctx.now).toISOString(), freq: 'hourly', pri: '1.0' },
    ...CATEGORIES.map((c) => ({ loc: `${ctx.siteUrl}${categoryPath(c.id)}`, lastmod: new Date(ctx.now).toISOString(), freq: 'hourly', pri: '0.8' })),
    ...stories.map((s) => ({ loc: `${ctx.siteUrl}${storyPath(s)}`, lastmod: s.updatedAt, freq: 'daily', pri: '0.6' })),
  ];
  return `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${urls.map((u) => `<url><loc>${escapeXml(u.loc)}</loc><lastmod>${escapeXml(u.lastmod)}</lastmod><changefreq>${u.freq}</changefreq><priority>${u.pri}</priority></url>`).join('\n')}
</urlset>
`;
}

export function renderRss(stories: Story[], ctx: SiteContext): string {
  const items = stories
    .map((s) => {
      const link = `${ctx.siteUrl}${storyPath(s)}`;
      const desc = `${s.whatHappened} What this means for you: ${s.whatItMeans} Sources: ${sourceNames(s).join(', ')}.`;
      return `<item><title>${escapeXml(s.headline)}</title><link>${escapeXml(link)}</link><guid isPermaLink="true">${escapeXml(link)}</guid><pubDate>${new Date(s.publishedAt).toUTCString()}</pubDate><category>${escapeXml(categoryLabel(s.category))}</category><description>${escapeXml(desc)}</description></item>`;
    })
    .join('\n');
  return `<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
<channel>
<title>TechDaily — tech news in simple words</title>
<link>${escapeXml(ctx.siteUrl)}/</link>
<atom:link href="${escapeXml(ctx.siteUrl)}/rss.xml" rel="self" type="application/rss+xml"/>
<description>Technology news for everyday people in India, explained simply, with what it means for you.</description>
<language>en-in</language>
<lastBuildDate>${new Date(ctx.now).toUTCString()}</lastBuildDate>
${items}
</channel>
</rss>
`;
}

export function renderRobots(ctx: SiteContext): string {
  return `User-agent: *
Allow: /
Disallow: /app/

Sitemap: ${ctx.siteUrl}/sitemap.xml
`;
}
