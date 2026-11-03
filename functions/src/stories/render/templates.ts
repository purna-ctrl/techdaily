/**
 * Static HTML for crawlers, link previews and no-JS readers (v3 design). Every page is
 * self-contained (inline CSS, optional tiny inline JS for copy / native share / newsletter / image
 * fallback), dark, image-led and mobile-first.
 *
 * Images: the publisher's lead image is hotlinked (never copied) with a visible "Image: <Source>"
 * credit linking to the source article. Behind every image sits the category artwork
 * (/art/<category>.svg), so a missing or broken image never leaves a blank box — even without JS
 * (images use alt="" and no-referrer; with JS a failed image is removed and its credit hidden).
 * Layout never shifts: media boxes have a fixed aspect ratio and <img> carries width/height.
 */
import { CATEGORIES, categoryLabel, TOP_STORIES } from '../categories';
import { displayFields, FALLBACK_PILL, GOOD_TO_KNOW_LABEL, KEY_NUMBERS_LABEL, ListStyle, questionsFor, TLDR_LABEL } from '../questions';
import { escapeHtml as h, escapeXml, formatIst, jsonForScript, truncate } from '../text';
import { Story } from '../types';
import { TodayInFive } from '../ranking';
import { catStyle, iconSvg, UI_ICONS } from './theme';

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
export const artPath = (category: string) => `/art/${category}.svg`;

/** WhatsApp share link: headline + story URL. */
export function whatsappUrl(headline: string, url: string): string {
  return `https://wa.me/?text=${encodeURIComponent(`${headline}\n\n${url}`)}`;
}

export function metaDescription(s: Story): string {
  const d = displayFields(s);
  const text = [d.tldr, d.whatHappened, d.whatItMeans].filter(Boolean).join(' ') || `${s.headline}. Explained in simple words by TechDaily.`;
  return truncate(text.replace(/\s+/g, ' '), 158);
}

export function sourceNames(s: Story): string[] {
  return [...new Set(s.sources.map((x) => x.name).filter(Boolean))];
}

const isFallback = (s: Story) => s.aiModel.startsWith('techdaily-fallback');

function rgba(hex: string, a: number): string {
  const v = hex.replace('#', '');
  const n = (i: number) => parseInt(v.slice(i, i + 2), 16);
  return `rgba(${n(0)},${n(2)},${n(4)},${a})`;
}

/** Inline CSS custom properties for a category (colour, text tint, soft fill, glow). */
export function catVars(category: string): string {
  const c = catStyle(category);
  return `--c:${c.color};--ct:${c.tint};--cs:${rgba(c.color, 0.16)};--cg:${rgba(c.color, 0.38)}`;
}

/** Solid category chip (ink text on the category colour: >= 4.6:1 for every category). */
function chip(category: string, link = true, small = false): string {
  const label = category === TOP_STORIES.id ? TOP_STORIES.label : categoryLabel(category);
  const inner = `${iconSvg(catStyle(category).icon, small ? 12 : 14)}<span>${h(label)}</span>`;
  const cls = `chip${small ? ' sm' : ''}`;
  return link ? `<a class="${cls}" href="${categoryPath(category)}" style="${catVars(category)}">${inner}</a>` : `<span class="${cls}" style="${catVars(category)}">${inner}</span>`;
}

const devPill = '<span class="dev" title="Few or unconfirmed reports so far — details may change">Developing</span>';

// Contrast on #0B0B0F: ink #F4F2EC 17.6:1, muted #B9B5AD 9.6:1, focus #FFD166 13.6:1; on glass
// cards (~#16161C) muted 8.9:1. Category tints >= 6:1 on their tinted surfaces. Text over images
// sits on a >= 88% ink scrim.
export const CSS = `@font-face{font-family:"TD Display";src:url(/assets/assets/fonts/SpaceGrotesk-700.ttf) format("truetype");font-weight:700;font-display:swap}
:root{color-scheme:dark;--bg:#0B0B0F;--sf:#15151B;--sf2:#1E1E26;--gl:rgba(255,255,255,.05);--gb:rgba(255,255,255,.1);--ink:#F4F2EC;--mu:#B9B5AD;--ac:#FF5A1F;--act:#FF8255;--warn:#FFD166;--red:#FF3B4E;--redt:#FF7683;--c:#FF5A1F;--ct:#FF8255;--cs:rgba(255,90,31,.16);--cg:rgba(255,90,31,.38);--disp:"TD Display","Space Grotesk",ui-sans-serif,system-ui,sans-serif}
*{box-sizing:border-box}html{-webkit-text-size-adjust:100%}
body{margin:0;background:var(--bg);color:var(--ink);font:16.5px/1.6 Inter,ui-sans-serif,system-ui,-apple-system,"Segoe UI",Roboto,"Noto Sans",sans-serif;background-image:radial-gradient(900px 500px at 85% -10%,var(--cs),transparent 70%),radial-gradient(700px 400px at -10% 10%,rgba(139,92,246,.08),transparent 70%);background-repeat:no-repeat}
a{color:var(--act);text-underline-offset:3px}a:hover{text-decoration-thickness:2px}
a:focus-visible,button:focus-visible,input:focus-visible,summary:focus-visible{outline:3px solid var(--warn);outline-offset:3px;border-radius:10px}
.ic{flex:none;vertical-align:-2px}
.skip{position:absolute;left:-9999px;top:8px}.skip:focus{left:8px;z-index:20;background:var(--ink);color:var(--bg);padding:8px 12px;border-radius:8px}
.top{position:sticky;top:0;z-index:10;background:rgba(11,11,15,.78);-webkit-backdrop-filter:blur(18px) saturate(1.4);backdrop-filter:blur(18px) saturate(1.4);border-bottom:1px solid var(--gb)}
.bar{max-width:1080px;margin:0 auto;padding:10px 16px;display:flex;align-items:center;justify-content:space-between;gap:12px}
.brand{display:inline-flex;align-items:center;gap:10px;font:700 21px/1 var(--disp);color:var(--ink);text-decoration:none;letter-spacing:-.4px}.brand b{font-weight:700}.brand b span{color:var(--act)}
.logo{width:30px;height:30px;border-radius:9px;display:grid;place-items:center;background:linear-gradient(135deg,#FF5A1F,#FF3B4E 55%,#8B5CF6);color:#fff;font:700 13px/1 var(--disp);box-shadow:0 4px 18px rgba(255,90,31,.35)}
.cats{max-width:1080px;margin:0 auto;padding:2px 16px 12px;display:flex;gap:8px;overflow-x:auto;scrollbar-width:none}.cats::-webkit-scrollbar{display:none}
.cats a{flex:none;display:inline-flex;align-items:center;gap:6px;padding:7px 13px;border:1px solid var(--gb);border-radius:999px;background:var(--gl);color:var(--ink);text-decoration:none;font-size:14px;font-weight:600;line-height:1.2}
.cats a .ic{color:var(--ct)}
.cats a[aria-current=page]{background:var(--c);border-color:var(--c);color:#0B0B0F;box-shadow:0 0 22px var(--cg)}.cats a[aria-current=page] .ic{color:#0B0B0F}
main{max-width:1080px;margin:0 auto;padding:18px 16px 48px}
.narrow{max-width:760px;margin:0 auto}
.chips{display:flex;flex-wrap:wrap;gap:8px;align-items:center;margin:0 0 10px}
.chip{display:inline-flex;align-items:center;gap:6px;padding:6px 11px;border-radius:999px;background:var(--c);color:#0B0B0F;font:800 12px/1 Inter,system-ui,sans-serif;letter-spacing:.05em;text-transform:uppercase;text-decoration:none;box-shadow:0 0 18px var(--cg)}
.chip.sm{padding:5px 9px;font-size:10.5px;box-shadow:none}
.dev{display:inline-flex;align-items:center;gap:6px;padding:5px 10px;border-radius:999px;font:800 11px/1.2 Inter,system-ui,sans-serif;letter-spacing:.06em;text-transform:uppercase;background:rgba(43,34,5,.92);color:var(--warn);border:1px solid #6B560E}
.dev:before{content:"";width:7px;height:7px;border-radius:50%;background:var(--warn);box-shadow:0 0 8px var(--warn)}
h1{font:700 clamp(28px,7vw,46px)/1.08 var(--disp);letter-spacing:-.8px;margin:.2em 0 .3em}
h2{font:700 20px/1.25 var(--disp);letter-spacing:-.2px;margin:0 0 8px}
.meta{color:var(--mu);font-size:14px;margin:0}
.art{background-color:var(--sf);background-position:center;background-size:cover}
.media{position:relative;overflow:hidden;aspect-ratio:16/9}
.media img{position:absolute;inset:0;width:100%;height:100%;object-fit:cover;display:block}
.credit{position:absolute;z-index:3;top:10px;right:10px;max-width:70%;padding:4px 9px;border-radius:999px;background:rgba(11,11,15,.82);color:#E9E6DF;font-size:11.5px;line-height:1.3;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;-webkit-backdrop-filter:blur(8px);backdrop-filter:blur(8px)}
.credit a{color:#fff;font-weight:600}
.noimg .credit{display:none}
/* story hero */
.hero{position:relative;isolation:isolate;display:flex;align-items:flex-end;min-height:clamp(400px,64vh,580px);border-radius:28px;overflow:hidden;margin:4px 0 6px;border:1px solid var(--gb);box-shadow:0 30px 80px -30px var(--cg)}
.hero .media{position:absolute;inset:0;aspect-ratio:auto;z-index:-2}
.hero:after{content:"";position:absolute;inset:0;z-index:-1;background:linear-gradient(to top,rgba(11,11,15,.98) 0%,rgba(11,11,15,.9) 42%,rgba(11,11,15,.45) 72%,rgba(11,11,15,.25) 100%)}
.hero-body{padding:22px 20px 22px;width:100%;text-shadow:0 1px 12px rgba(0,0,0,.5)}
.hero .meta{color:#D2CEC6}
.lede{font-size:18px;color:var(--ink);margin:16px 0 0}
/* cards */
.card{position:relative;background:linear-gradient(180deg,rgba(255,255,255,.055),rgba(255,255,255,.025));border:1px solid var(--gb);border-radius:24px;padding:18px 20px;margin:14px 0;-webkit-backdrop-filter:blur(14px);backdrop-filter:blur(14px)}
.card p{margin:0}.card ol,.card ul{margin:6px 0 0;padding-left:0;list-style:none}
.card h2{display:flex;align-items:center;gap:10px}
.hi{width:34px;height:34px;border-radius:12px;display:inline-grid;place-items:center;background:var(--cs);color:var(--ct);flex:none}
.todo li{position:relative;padding:8px 0 8px 38px;border-top:1px solid var(--gb)}.todo li:first-child{border-top:0}
.todo li:before{content:"";position:absolute;left:2px;top:10px;width:24px;height:24px;border-radius:50%;background:var(--c) url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='%230B0B0F' stroke-width='3' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='M6 12.5l4 4 8-9'/%3E%3C/svg%3E") center/16px no-repeat}
.card.mean{border:1.5px solid transparent;background:linear-gradient(#16161C,#16161C) padding-box,linear-gradient(135deg,var(--c),rgba(255,255,255,.08) 55%,var(--c)) border-box;box-shadow:0 20px 50px -28px var(--cg)}
.card.mean p{font-size:18px;line-height:1.55}
.auto{margin:12px 0 0}.auto span{display:inline-flex;align-items:center;gap:6px;padding:5px 11px;border-radius:999px;background:var(--gl);border:1px solid var(--gb);color:var(--mu);font:600 12.5px/1.2 Inter,system-ui,sans-serif}
.tldr{margin:14px 0;padding:16px 18px;border-radius:22px;background:var(--cs);border:1px solid var(--cg)}
.tldr h2,.kn h2{margin:0 0 6px;font:800 11.5px/1.2 Inter,system-ui,sans-serif;letter-spacing:.08em;text-transform:uppercase;color:var(--ct)}
.tldr p{margin:0;font-size:18.5px;line-height:1.45;font-weight:600}
.kn{margin:14px 0}.kn ul{display:flex;flex-wrap:wrap;gap:8px;margin:0;padding:0;list-style:none}
.kn li{display:flex;flex-direction:column;padding:9px 13px;border-radius:16px;background:var(--gl);border:1px solid var(--gb);min-width:92px}
.kn b{font:700 18px/1.15 var(--disp);color:var(--ink)}.kn span{font-size:12px;color:var(--mu)}
.bul li{position:relative;padding:6px 0 6px 22px}.bul li:before{content:"";position:absolute;left:4px;top:15px;width:8px;height:8px;border-radius:50%;background:var(--c)}
.fact{font-size:17.5px;line-height:1.5;padding-left:12px;border-left:3px solid var(--c)}
.faq details{border:1px solid var(--gb);border-radius:16px;margin:8px 0;background:var(--gl)}
.faq summary{cursor:pointer;list-style:none;padding:11px 40px 11px 14px;font-weight:600;position:relative;min-height:44px}
.faq summary::-webkit-details-marker{display:none}
.faq summary:after{content:"+";position:absolute;right:14px;top:9px;font:700 20px/1 var(--disp);color:var(--ct)}
.faq details[open] summary:after{content:"–"}
.faq details p{margin:0;padding:0 14px 12px;color:var(--ink)}
.card.scam{border-color:rgba(255,59,78,.55);background:linear-gradient(180deg,rgba(255,59,78,.1),rgba(255,59,78,.04));box-shadow:0 0 0 1px rgba(255,59,78,.15),0 18px 50px -30px rgba(255,59,78,.6)}
.card.scam h2{color:var(--redt)}.card.scam .hi{background:rgba(255,59,78,.18);color:var(--redt)}
.signs li{position:relative;padding:7px 0 7px 32px}.signs li .ic{position:absolute;left:2px;top:10px;color:var(--warn)}
.steps{counter-reset:s}.steps li{counter-increment:s;position:relative;padding:7px 0 7px 38px}
.steps li:before{content:counter(s);position:absolute;left:0;top:7px;width:26px;height:26px;border-radius:50%;display:grid;place-items:center;background:rgba(255,59,78,.2);color:var(--redt);font:700 14px/1 var(--disp)}
.help{display:flex;flex-wrap:wrap;gap:10px;align-items:center;margin-top:14px;padding:14px;border-radius:18px;background:rgba(11,11,15,.55);border:1px dashed rgba(255,59,78,.5)}
.help .big{font:700 30px/1 var(--disp);color:#fff;text-decoration:none;display:inline-flex;align-items:center;gap:10px}
.help .big .ic{color:var(--redt)}
.note{color:var(--mu);font-size:14px}
.btn{display:inline-flex;align-items:center;justify-content:center;gap:8px;min-height:46px;background:var(--ac);color:#0B0B0F;font:700 15px/1 Inter,system-ui,sans-serif;padding:12px 18px;border-radius:999px;text-decoration:none;border:0;cursor:pointer}
.btn.wa{background:#25D366;color:#0B0B0F;box-shadow:0 10px 30px -12px rgba(37,211,102,.7)}
.btn.alt{background:var(--gl);color:var(--ink);border:1px solid var(--gb)}
.btn.sm{min-height:40px;padding:9px 15px;font-size:14px}
.btn.red{background:var(--red);color:#0B0B0F}
.row{display:flex;flex-wrap:wrap;gap:10px;margin-top:10px}
.srcs li{padding:10px 0;border-top:1px solid var(--gb)}.srcs li:first-child{border-top:0}
.srcs a{font-weight:600}
/* story cards + grids */
.sec-h{display:flex;align-items:center;justify-content:space-between;gap:12px;margin:34px 0 14px}
.sec-h h2{margin:0;font-size:24px}.sec-h a{font-weight:600;text-decoration:none}
.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px;list-style:none;margin:0;padding:0}
@media (min-width:720px){.grid{grid-template-columns:repeat(3,minmax(0,1fr));gap:18px}}
.sc{position:relative;border-radius:22px;overflow:hidden;background:var(--sf);border:1px solid var(--gb);transition:transform .2s ease,box-shadow .2s ease}
.sc:hover{transform:translateY(-3px);box-shadow:0 18px 40px -22px var(--cg)}
.sc>a.cover{display:block;color:var(--ink);text-decoration:none;height:100%}
.sc>a.cover:focus-visible{outline-offset:-3px;border-radius:22px}
.sc .media{aspect-ratio:16/10}
.sc .media:after{content:"";position:absolute;inset:auto 0 0 0;height:3px;background:var(--c)}
.sc-body{padding:12px 13px 14px}
.sc h3{font:700 16px/1.25 var(--disp);margin:8px 0 6px;letter-spacing:-.1px;display:-webkit-box;-webkit-line-clamp:4;-webkit-box-orient:vertical;overflow:hidden}
.sc .one{color:var(--mu);font-size:13.5px;line-height:1.45;margin:0 0 6px;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}
.sc .meta{font-size:12.5px}
.sc .credit{top:8px;right:8px;font-size:10.5px;padding:3px 7px}
@media (min-width:720px){.sc h3{font-size:18.5px}}
.feat{position:relative;border-radius:28px;overflow:hidden;border:1px solid var(--gb);margin:6px 0 18px;box-shadow:0 30px 70px -36px var(--cg)}
.feat>a.cover{display:flex;align-items:flex-end;min-height:clamp(340px,56vh,500px);color:var(--ink);text-decoration:none;position:relative;isolation:isolate}
.feat .media{position:absolute;inset:0;aspect-ratio:auto;z-index:-2}
.feat>a.cover:after{content:"";position:absolute;inset:0;z-index:-1;background:linear-gradient(to top,rgba(11,11,15,.98),rgba(11,11,15,.88) 45%,rgba(11,11,15,.2) 80%)}
.feat .fb{padding:20px}
.feat h3{font:700 clamp(24px,6vw,36px)/1.1 var(--disp);margin:10px 0 8px;letter-spacing:-.5px}
.feat .one{color:#D2CEC6;margin:0 0 8px}
.feat .meta{color:#D2CEC6}
/* category header */
.cathead{position:relative;border-radius:28px;overflow:hidden;padding:30px 22px 26px;margin:4px 0 18px;border:1px solid var(--gb);isolation:isolate}
.cathead .art{position:absolute;inset:0;z-index:-2}
.cathead:after{content:"";position:absolute;inset:0;z-index:-1;background:linear-gradient(90deg,rgba(11,11,15,.95),rgba(11,11,15,.7) 60%,rgba(11,11,15,.35))}
.cathead h1{margin:.25em 0 .2em}
.cathead .bigic{width:52px;height:52px;border-radius:16px;display:grid;place-items:center;background:var(--c);color:#0B0B0F;box-shadow:0 0 30px var(--cg)}
/* today in 5 */
.five{display:flex;gap:12px;overflow-x:auto;list-style:none;margin:0 -16px;padding:4px 16px 12px;scroll-snap-type:x mandatory;scrollbar-width:none}.five::-webkit-scrollbar{display:none}
.five li{flex:none;width:156px;scroll-snap-align:start;position:relative}
.five .tile{position:relative;display:flex;align-items:flex-end;height:232px;border-radius:22px;overflow:hidden;color:var(--ink);text-decoration:none;isolation:isolate;border:2px solid var(--c);box-shadow:0 0 0 3px var(--bg),0 0 0 5px var(--cs),0 12px 30px -14px var(--cg)}
.five .tile .media{position:absolute;inset:0;aspect-ratio:auto;z-index:-2}
.five .tile:after{content:"";position:absolute;inset:0;z-index:-1;background:linear-gradient(to top,rgba(11,11,15,.97) 8%,rgba(11,11,15,.82) 50%,rgba(11,11,15,.15))}
.five .n{position:absolute;top:8px;left:10px;font:700 30px/1 var(--disp);color:#fff;text-shadow:0 2px 12px rgba(0,0,0,.6)}
.five .t{margin:0 11px 12px;padding:0;max-height:calc(5 * 1.25em);font:700 14.5px/1.25 var(--disp);display:-webkit-box;-webkit-line-clamp:5;-webkit-box-orient:vertical;overflow:hidden}
.five .credit{top:auto;bottom:auto;top:10px;right:8px;font-size:10px;max-width:58%}
.intro{display:flex;flex-wrap:wrap;align-items:flex-end;justify-content:space-between;gap:10px;margin:8px 0 14px}
.intro h1{font-size:clamp(28px,7vw,44px);margin:0}
.intro p{margin:4px 0 0}
.radar{border-color:rgba(255,59,78,.6)}
/* list */
.list{list-style:none;padding:0;margin:0}
.li{display:flex;gap:14px;align-items:flex-start;padding:14px 0;border-top:1px solid var(--gb)}
.li .media{flex:none;width:112px;aspect-ratio:1;border-radius:16px}
.li h3{font:700 17px/1.28 var(--disp);margin:6px 0 4px}.li h3 a{color:var(--ink);text-decoration:none}.li h3 a:hover{text-decoration:underline}
form.signup{display:flex;flex-wrap:wrap;gap:8px;align-items:center;margin-top:8px}
form.signup label{flex-basis:100%;font-weight:600}
form.signup input{flex:1 1 220px;min-height:46px;padding:10px 16px;border-radius:999px;border:1px solid #55555F;background:var(--sf2);color:var(--ink);font:16px Inter,system-ui,sans-serif}
.msg{flex-basis:100%;margin:4px 0 0;color:var(--mu);font-size:14px;min-height:1em}
footer{border-top:1px solid var(--gb);color:var(--mu);font-size:14px;margin-top:20px}footer .bar{display:block;max-width:760px}footer a{color:var(--ink)}
@media (min-width:720px){.hero-body{padding:34px 36px}.card{padding:22px 26px}.feat .fb{padding:30px 34px}}
@media (prefers-reduced-motion:reduce){*{transition:none!important;scroll-behavior:auto!important}}`;

function head(
  ctx: SiteContext,
  o: { title: string; description: string; path: string; image: string; imageSize?: { width?: number; height?: number }; type: 'article' | 'website'; extra?: string; jsonLd?: unknown; vars?: string }
): string {
  const url = `${ctx.siteUrl}${o.path}`;
  const w = o.imageSize ? o.imageSize.width : 1200;
  const hgt = o.imageSize ? o.imageSize.height : 630;
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
${w ? `<meta property="og:image:width" content="${w}">\n` : ''}${hgt ? `<meta property="og:image:height" content="${hgt}">\n` : ''}<meta property="og:image:alt" content="${h(o.title)}">
<meta property="og:locale" content="en_IN">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="${h(o.title)}">
<meta name="twitter:description" content="${h(o.description)}">
<meta name="twitter:image" content="${h(o.image)}">
${o.extra ?? ''}<link rel="icon" type="image/png" href="/favicon.png">
<link rel="apple-touch-icon" href="/icons/apple-touch-icon.png">
<link rel="manifest" href="/manifest.json">
<link rel="alternate" type="application/rss+xml" title="TechDaily" href="/rss.xml">
<link rel="preload" href="/assets/assets/fonts/SpaceGrotesk-700.ttf" as="font" type="font/ttf" crossorigin>
${o.jsonLd ? `<script type="application/ld+json">${jsonForScript(o.jsonLd)}</script>\n` : ''}<style>${CSS}</style>
</head>`;
}

function topBar(current?: string): string {
  const links = [
    `<a href="/" style="${catVars(TOP_STORIES.id)}"${current === TOP_STORIES.id ? ' aria-current="page"' : ''}>${iconSvg(catStyle(TOP_STORIES.id).icon, 14)}${TOP_STORIES.label}</a>`,
    ...CATEGORIES.map(
      (c) =>
        `<a href="${categoryPath(c.id)}" style="${catVars(c.id)}"${current === c.id ? ' aria-current="page"' : ''}>${iconSvg(catStyle(c.id).icon, 14)}${h(c.label)}</a>`
    ),
  ];
  return `<a class="skip" href="#main">Skip to content</a>
<header class="top"><div class="bar"><a class="brand" href="/"><span class="logo" aria-hidden="true">TD</span><b>Tech<span>Daily</span></b></a><a class="btn alt sm" href="/app/">Open app</a></div>
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
<p>TechDaily explains technology news for everyday people in India, in simple words. Story cards are written by AI from the original reports and checked automatically; always read the original before acting on money or security advice. Images belong to the publishers credited on them and link to their reports. If you lost money to a scam, call <strong>1930</strong> or report at <a href="https://cybercrime.gov.in">cybercrime.gov.in</a>.</p>
<p><a href="/app/about">About</a> · <a href="/rss.xml">RSS</a> · <a href="/sitemap.xml">Sitemap</a> · <a href="/app/">Open the app</a></p>
</div></footer>`;
}

/** Progressive enhancement only: copy link, native share sheet, newsletter POST, broken-image fallback. */
export function pageScript(): string {
  return `<script>
(function(){
var d=document;
function noimg(i){var b=i.closest('[data-img]');if(b)b.classList.add('noimg');i.remove();}
var cur=d.querySelector('.cats [aria-current]');if(cur&&cur.offsetLeft>window.innerWidth*0.6)cur.parentNode.scrollLeft=cur.offsetLeft-16;
d.querySelectorAll('img[data-pub]').forEach(function(i){if(i.complete&&i.naturalWidth===0)noimg(i);else i.addEventListener('error',function(){noimg(i);});});
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

/**
 * Media box: category art behind the (optional) publisher image. `eager` for the one above-the-fold
 * hero (fetchpriority high); everything else is lazy + async-decoded.
 */
function media(s: Story, opts: { eager?: boolean; sizes?: string; cls?: string } = {}): string {
  const img = s.image;
  const w = img?.width ?? 1200;
  const hh = img?.height ?? 675;
  const tag = img
    ? `<img data-pub src="${h(img.url)}" alt="" width="${w}" height="${hh}" ${opts.eager ? 'loading="eager" fetchpriority="high"' : 'loading="lazy"'} decoding="async" referrerpolicy="no-referrer">`
    : '';
  return `<div class="media art${opts.cls ? ' ' + opts.cls : ''}" style="background-image:url(${artPath(s.category)})">${tag}</div>`;
}

/** Visible image credit linking to the source article (sibling of the card's main link). */
function credit(s: Story): string {
  if (!s.image) return '';
  return `<p class="credit">Image: <a href="${h(s.image.sourceUrl)}" rel="noopener nofollow">${h(s.image.sourceName)}</a></p>`;
}

function shareBlock(s: Story, url: string): string {
  return `<div class="row">
<a class="btn wa" href="${h(whatsappUrl(s.headline, url))}" rel="noopener">${iconSvg(UI_ICONS.whatsapp, 18)}Share on WhatsApp</a>
<button class="btn alt" type="button" data-share="${h(url)}" data-title="${h(s.headline)}" hidden>${iconSvg(UI_ICONS.share, 16)}Share…</button>
<button class="btn alt" type="button" data-copy="${h(url)}" hidden>${iconSvg(UI_ICONS.link, 16)}Copy link</button>
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
    image: s.image ? [s.image.url, ogImageFor(ctx, s.category)] : [ogImageFor(ctx, s.category)],
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

function section(id: string, title: string, icon: string, body: string, cls = ''): string {
  return `<section class="card${cls ? ' ' + cls : ''}" aria-labelledby="${id}"><h2 id="${id}"><span class="hi">${iconSvg(icon, 18)}</span>${h(title)}</h2>${body}</section>`;
}

const todoList = (items: string[]) => `<ol class="todo">${items.map((x) => `<li>${h(x)}</li>`).join('')}</ol>`;
const bulletList = (items: string[]) => `<ul class="bul">${items.map((x) => `<li>${h(x)}</li>`).join('')}</ul>`;

function listBody(items: string[], style: ListStyle): string {
  if (style === 'fact') return `<p class="fact">${h(items.join(' '))}</p>`;
  return style === 'bullets' ? bulletList(items) : todoList(items);
}

/** "In one line" TL;DR + "Key numbers" chips + the fallback pill. */
function storyTop(s: Story): string {
  const d = displayFields(s);
  const nums = (s.keyNumbers ?? []).filter((k) => k.value && k.label);
  const pill = isFallback(s) ? `<p class="auto"><span>${h(FALLBACK_PILL)}</span></p>` : '';
  const tl = d.tldr ? `<section class="tldr" aria-labelledby="h-tldr"><h2 id="h-tldr">${h(TLDR_LABEL)}</h2><p>${h(d.tldr)}</p></section>` : '';
  const kn = nums.length
    ? `<section class="kn" aria-labelledby="h-kn"><h2 id="h-kn">${h(KEY_NUMBERS_LABEL)}</h2><ul>${nums.map((k) => `<li><b>${h(k.value)}</b><span>${h(k.label)}</span></li>`).join('')}</ul></section>`
    : '';
  return pill + tl + kn;
}

/** "Ask about this": tappable questions that open to short answers (no JS needed). */
function faqSection(s: Story): string {
  const faq = (s.faq ?? []).filter((f) => f.q && f.a);
  if (!faq.length) return '';
  return section(
    'h-ask',
    'Ask about this',
    UI_ICONS.ask,
    `<div class="faq">${faq.map((f) => `<details><summary>${h(f.q)}</summary><p>${h(f.a)}</p></details>`).join('')}</div>`
  );
}

/** The per-category question sections (scam stories use the scam set). */
function storySections(s: Story): string {
  const d = displayFields(s);
  const qs = questionsFor(s.category, Boolean(s.scam));
  const out: string[] = [];
  const text = (id: string, label: string, icon: string, t: string, cls = '') => (t ? out.push(section(id, label, icon, `<p>${h(t)}</p>`, cls)) : 0);
  const todo = () => {
    if (d.whatToDo.length) out.push(section('h-todo', qs.whatToDo.label, qs.whatToDo.style === 'fact' ? UI_ICONS.spark : qs.whatToDo.style === 'bullets' ? UI_ICONS.tag : UI_ICONS.check, listBody(d.whatToDo, qs.whatToDo.style)));
    else if (d.goodToKnow) out.push(section('h-todo', GOOD_TO_KNOW_LABEL, UI_ICONS.info, `<p>${h(d.goodToKnow)}</p>`));
  };
  if (s.scam) {
    const trick = [d.whatHappened, s.scam.howItWorks].filter(Boolean).join(' ');
    text('h-what', qs.whatHappened.label, UI_ICONS.hook, trick, 'scam');
    text('h-who', qs.affectsWho.label, UI_ICONS.person, d.affectsWho);
    out.push(section('h-signs', 'Spot the signs', UI_ICONS.alert, `<ul class="signs">${s.scam.warningSigns.map((x) => `<li>${iconSvg(UI_ICONS.alert, 16)}${h(x)}</li>`).join('')}</ul>`, 'scam'));
    todo();
    out.push(
      section(
        'h-target',
        'If it happened to you',
        UI_ICONS.shield,
        `<ol class="steps">${s.scam.ifTargeted.map((x) => `<li>${h(x)}</li>`).join('')}</ol>
<div class="help"><a class="big" href="tel:1930" aria-label="Call the cyber-crime helpline 1930">${iconSvg(UI_ICONS.phone, 26)}1930</a><p class="note" style="flex:1 1 200px;margin:0">India’s cyber-crime helpline. Or report at <a href="https://cybercrime.gov.in">cybercrime.gov.in</a>.</p></div>
${s.scam.advisoryUrl ? `<p class="row"><a class="btn red" href="${h(s.scam.advisoryUrl)}" rel="noopener">${iconSvg(UI_ICONS.shield, 16)}Read the official advisory</a></p>` : ''}`,
        'scam'
      )
    );
    text('h-mean', qs.whatItMeans.label, UI_ICONS.bulb, d.whatItMeans, 'mean');
  } else {
    text('h-what', qs.whatHappened.label, UI_ICONS.news, d.whatHappened);
    text('h-who', qs.affectsWho.label, UI_ICONS.person, d.affectsWho);
    todo();
    text('h-mean', qs.whatItMeans.label, /next/i.test(qs.whatItMeans.label) ? UI_ICONS.next : UI_ICONS.bulb, d.whatItMeans, 'mean');
  }
  return out.join('\n');
}

/** Image card for grids (related stories, category pages, home). */
export function storyCard(s: Story): string {
  return `<li class="sc" data-img style="${catVars(s.category)}">
<a class="cover" href="${h(storyPath(s))}">${media(s)}<div class="sc-body">${chip(s.category, false, true)}${s.developing ? ' ' + devPill.replace('class="dev"', 'class="dev" style="font-size:9.5px;padding:3px 7px"') : ''}
<h3>${h(s.headline)}</h3>${isFallback(s) ? '' : `<p class="one">${h(truncate(s.whatItMeans, 120))}</p>`}<p class="meta">${timeTag(s.publishedAt)}</p></div></a>${credit(s)}</li>`;
}

/** Big full-bleed feature card (first story of a category / home). */
function featureCard(s: Story, eager = false): string {
  return `<article class="feat" data-img style="${catVars(s.category)}">
<a class="cover" href="${h(storyPath(s))}">${media(s, { eager })}<div class="fb"><p class="chips">${chip(s.category, false)}${s.developing ? devPill : ''}</p>
<h3>${h(s.headline)}</h3>${isFallback(s) ? '' : `<p class="one">${h(truncate(s.whatItMeans, 170))}</p>`}<p class="meta">${timeTag(s.publishedAt)} · ${h(sourceNames(s).join(', '))}</p></div></a>${credit(s)}</article>`;
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
  const image = s.image ? s.image.url : ogImageFor(ctx, s.category);
  const imageSize = s.image ? { width: s.image.width, height: s.image.height } : undefined;
  const rel = related.length
    ? `<section aria-labelledby="h-more"><div class="sec-h"><h2 id="h-more">More in ${h(categoryLabel(s.category))}</h2><a href="${categoryPath(s.category)}">See all</a></div><ul class="grid">${related.map(storyCard).join('')}</ul></section>`
    : '';
  return `${head(ctx, { title, description: desc, path: storyPath(s), image, imageSize, type: 'article', extra, jsonLd: newsArticleJsonLd(s, ctx) })}
<body style="${catVars(s.category)}">
${topBar(s.category)}
<main id="main">
<article class="narrow">
<header class="hero" data-img>
${media(s, { eager: true })}${credit(s)}
<div class="hero-body">
<p class="chips">${chip(s.category)}${s.developing ? devPill : ''}</p>
<h1>${h(s.headline)}</h1>
<p class="meta">${timeTag(s.publishedAt)} · ${names.length > 1 ? `${names.length} sources: ` : 'Source: '}${h(names.join(', '))}</p>
</div>
</header>
${storyTop(s)}
${storySections(s)}
${faqSection(s)}
${section(
  'h-orig',
  `Read the original${s.sources.length > 1 ? 's' : ''}`,
  UI_ICONS.link,
  `<ul class="srcs">${s.sources
    .map((x) => `<li><a href="${h(x.url)}" rel="noopener">${h(x.name)}${x.title ? `: ${h(x.title)}` : ''}</a><br><span class="note">${timeTag(x.publishedAt)}</span></li>`)
    .join('')}</ul>
<p class="note" style="margin-top:8px">${isFallback(s) ? 'A simplified summary of the reports above; a fuller explanation is on its way' : 'Written in simple words by AI from the reports above'}; last updated ${timeTag(s.updatedAt)}.${s.image ? ` Image: ${h(s.image.sourceName)}, linked from the original report.` : ''}</p>`
)}
<section aria-labelledby="h-share" class="card"><h2 id="h-share">Share this story</h2>${shareBlock(s, url)}
<p class="row"><a class="btn alt" href="/app/story/${encodeURIComponent(s.slug)}">${iconSvg(UI_ICONS.arrow, 16)}Open in app</a></p></section>
</article>
${rel}
</main>
${footer(ctx)}
${pageScript()}
</body>
</html>
`;
}

/** Compact row: thumbnail left, headline + meta (used under the grids). */
function storyListItem(s: Story): string {
  return `<li class="li" data-img style="${catVars(s.category)}">${media(s)}<div>${chip(s.category, true, true)}${s.developing ? ' ' + devPill : ''}
<h3><a href="${h(storyPath(s))}">${h(s.headline)}</a></h3>
<p class="meta">${timeTag(s.publishedAt)} · ${h(sourceNames(s).join(', '))}</p>
${isFallback(s) ? '' : `<p class="note" style="margin:4px 0 0">${h(truncate(s.whatHappened, 160))}</p>`}${s.image ? `<p class="note" style="margin:2px 0 0;font-size:12px">Image: <a href="${h(s.image.sourceUrl)}" rel="noopener nofollow">${h(s.image.sourceName)}</a></p>` : ''}</div></li>`;
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
  const [lead, ...rest] = stories;
  const grid = rest.slice(0, 24);
  const more = rest.slice(24);
  return `${head(ctx, { title, description: desc, path: categoryPath(categoryId), image: ogImageFor(ctx, categoryId), type: 'website', jsonLd })}
<body style="${catVars(categoryId)}">
${topBar(categoryId)}
<main id="main">
<header class="cathead"><div class="art" style="background-image:url(${artPath(categoryId)})"></div>
<span class="bigic">${iconSvg(catStyle(categoryId).icon, 28)}</span>
<h1>${h(label)}</h1>
<p class="meta">Explained in simple words · updated ${timeTag(new Date(ctx.now).toISOString())}</p>
</header>
${lead ? featureCard(lead, true) : '<p>No stories yet — check back soon.</p>'}
${grid.length ? `<ul class="grid" aria-label="${h(label)} stories">${grid.map(storyCard).join('')}</ul>` : ''}
${more.length ? `<section aria-labelledby="older"><div class="sec-h"><h2 id="older">Earlier</h2></div><ul class="list">${more.map(storyListItem).join('')}</ul></section>` : ''}
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
    .map((i, n) => {
      const s = bySlug.get(i.slug);
      const fake = { category: i.category, image: s?.image ?? null } as Story;
      return `<li style="${catVars(i.category)}" data-img><a class="tile" href="/story/${encodeURIComponent(i.slug)}/">${media(fake)}<span class="n">${n + 1}</span><span class="t">${h(i.headline)}</span></a>${s ? credit(s) : ''}${s ? `<span class="meta" style="position:absolute;left:-9999px">${h(categoryLabel(i.category))} · ${timeTag(s.publishedAt)}</span>` : ''}</li>`;
    })
    .join('');
  const [lead, ...others] = latest;
  const scam = latest.find((s) => s.category === 'scams-security' && s.scam && s !== lead);
  return `<!--TD-SEO-->
<div id="td-seo">
<style>${CSS}#td-seo{min-height:100vh}</style>
${topBar(TOP_STORIES.id)}
<main id="main">
<div class="intro"><div><h1>TechDaily</h1><p class="meta">Tech news in simple words for India — updated ${timeTag(today.generatedAt)}.</p></div></div>
<section aria-labelledby="t5"><div class="sec-h" style="margin-top:6px"><h2 id="t5">Today in 5 stories</h2></div><ol class="five">${five}</ol></section>
${lead ? featureCard(lead) : ''}
${scam ? `<section aria-labelledby="radar"><div class="sec-h"><h2 id="radar" style="color:var(--redt)">Scam Radar</h2><a href="/c/scams-security/">All scam alerts</a></div>${section('radar-b', scam.headline, UI_ICONS.alert, `<ul class="signs">${scam.scam!.warningSigns.slice(0, 3).map((x) => `<li>${iconSvg(UI_ICONS.alert, 16)}${h(x)}</li>`).join('')}</ul><p class="row"><a class="btn red" href="${h(storyPath(scam))}">Read the alert</a><a class="btn alt" href="tel:1930">Call 1930</a><a class="btn alt" href="https://cybercrime.gov.in">cybercrime.gov.in</a></p>`, 'scam radar')}</section>` : ''}
<section aria-labelledby="lt"><div class="sec-h"><h2 id="lt">Latest stories</h2></div><ul class="grid">${others.slice(0, 12).map(storyCard).join('')}</ul></section>
${others.length > 12 ? `<ul class="list" style="margin-top:12px">${others.slice(12).map(storyListItem).join('')}</ul>` : ''}
</main>
${footer(ctx)}
${pageScript()}
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

function imageMime(url: string): string {
  const p = url.toLowerCase().split('?')[0];
  if (p.endsWith('.png')) return 'image/png';
  if (p.endsWith('.webp')) return 'image/webp';
  if (p.endsWith('.avif')) return 'image/avif';
  return 'image/jpeg';
}

export function renderRss(stories: Story[], ctx: SiteContext): string {
  const items = stories
    .map((s) => {
      const link = `${ctx.siteUrl}${storyPath(s)}`;
      const desc = `${s.whatHappened} What this means for you: ${s.whatItMeans} Sources: ${sourceNames(s).join(', ')}.${s.image ? ` Image: ${s.image.sourceName}.` : ''}`;
      const img = s.image
        ? `<media:content url="${escapeXml(s.image.url)}" medium="image"${s.image.width ? ` width="${s.image.width}"` : ''}${s.image.height ? ` height="${s.image.height}"` : ''}/><media:credit>${escapeXml(s.image.sourceName)}</media:credit><enclosure url="${escapeXml(s.image.url)}" type="${imageMime(s.image.url)}" length="0"/>`
        : `<media:content url="${escapeXml(ogImageFor(ctx, s.category))}" medium="image" width="1200" height="630"/>`;
      return `<item><title>${escapeXml(s.headline)}</title><link>${escapeXml(link)}</link><guid isPermaLink="true">${escapeXml(link)}</guid><pubDate>${new Date(s.publishedAt).toUTCString()}</pubDate><category>${escapeXml(categoryLabel(s.category))}</category><description>${escapeXml(desc)}</description>${img}</item>`;
    })
    .join('\n');
  return `<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom" xmlns:media="http://search.yahoo.com/mrss/">
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
