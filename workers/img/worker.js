/**
 * TechDaily image pass-through — Cloudflare Worker.
 * GET /?u=<https image url>  -> the publisher's image with CORS headers, so the Flutter web app
 * can draw it inside its canvas (no <img> platform views, which made scrolling lag).
 * Not a re-host: bytes are streamed from the publisher and kept only in Cloudflare's edge cache
 * for a day. The app still shows the "Image: Source" credit.
 */
const ORIGINS = ['https://techdaily-prod.web.app', 'https://techdaily-prod.firebaseapp.com'];
const MAX_BYTES = 8 * 1024 * 1024;
const TTL = 86400;

export function cors(origin) {
  return {
    'Access-Control-Allow-Origin': ORIGINS.includes(origin) ? origin : '*',
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    Vary: 'Origin',
  };
}

export function targetFrom(url) {
  const u = url.searchParams.get('u');
  if (!u || u.length > 2000) return null;
  let t;
  try { t = new URL(u); } catch { return null; }
  if (t.protocol !== 'https:' && t.protocol !== 'http:') return null;
  const h = t.hostname;
  if (h === 'localhost' || /^(\d+\.){3}\d+$/.test(h) || h.endsWith('.local') || h.includes(':')) return null;
  return t;
}

export async function handle(request, env, ctx, fetchFn = fetch, cache = globalThis.caches?.default) {
  const origin = request.headers.get('Origin') || '';
  const h = cors(origin);
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: h });
  if (request.method !== 'GET') return new Response('use GET', { status: 405, headers: h });
  const url = new URL(request.url);
  const target = targetFrom(url);
  if (!target) return new Response('bad url', { status: 400, headers: h });
  const key = new Request(`https://img-cache.techdaily/${encodeURIComponent(target.href)}`);
  let res = cache ? await cache.match(key) : null;
  if (!res) {
    let up;
    try {
      up = await fetchFn(target.href, {
        headers: { 'User-Agent': 'Mozilla/5.0 (compatible; TechDailyImage/1.0)', Accept: 'image/avif,image/webp,image/*' },
        cf: { cacheTtl: TTL, cacheEverything: true },
        redirect: 'follow',
      });
    } catch {
      return new Response('upstream failed', { status: 502, headers: h });
    }
    const type = up.headers.get('Content-Type') || '';
    const len = Number(up.headers.get('Content-Length') || 0);
    if (!up.ok || !type.startsWith('image/') || len > MAX_BYTES) {
      return new Response('not an image', { status: 502, headers: h });
    }
    res = new Response(up.body, {
      status: 200,
      headers: { 'Content-Type': type, 'Cache-Control': `public, max-age=${TTL}` },
    });
    if (cache && ctx) ctx.waitUntil(cache.put(key, res.clone()));
  }
  const out = new Response(res.body, res);
  for (const [k, v] of Object.entries(h)) out.headers.set(k, v);
  out.headers.set('Cache-Control', `public, max-age=${TTL}`);
  return out;
}

export default { fetch: (req, env, ctx) => handle(req, env, ctx) };
