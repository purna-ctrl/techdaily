import { test } from 'node:test';
import assert from 'node:assert/strict';
import { handle, _resetRateLimit, cleanItems, mergeTranslation, cleanVerdict, parseJson, MAX_SCAM_TEXT, MAX_TR_ITEMS } from '../worker.js';

const ORIGIN = 'https://techdaily-prod.web.app';
const post = (path, body, { ip = '1.1.1.1', origin = ORIGIN } = {}) =>
  new Request(`https://w.example${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Origin: origin, 'CF-Connecting-IP': ip },
    body: typeof body === 'string' ? body : JSON.stringify(body),
  });
const env = { GEMINI_API_KEY: 'k', RETRY_DELAY_MS: '0' };
const reply = (obj, calls = []) => async (_url, init) => {
  calls.push(JSON.parse(init.body));
  return new Response(JSON.stringify({ candidates: [{ content: { parts: [{ text: typeof obj === 'function' ? obj(JSON.parse(init.body)) : JSON.stringify(obj) }] } }] }), { status: 200 });
};
const SBI = 'Dear customer your SBI account will be blocked today, update PAN at http://sbi-kyc.co/x';

test('/scam returns a clean verdict in strict JSON, translated into the chosen language', async () => {
  _resetRateLimit();
  const calls = [];
  const verdict = { verdict: 'scam', summary: 'Fake SBI KYC message.', reasons: ['Threat to block today', 'Odd link sbi-kyc.co', 'Asks PAN'], actions: ['Do not click', 'Report on Chakshu'] };
  const f = reply((req) => {
    if (calls.length === 1) return JSON.stringify(verdict);
    const it = JSON.parse(req.contents[0].parts[0].text).items[0];
    return JSON.stringify({ items: [{ id: it.id, fields: { summary: 'TE summary', reasons: it.fields.reasons.map((r) => `TE ${r}`), actions: it.fields.actions.map((r) => `TE ${r}`) } }] });
  }, calls);
  const res = await handle(post('/scam', { text: SBI, sender: 'VM-SBIINB', lang: 'te' }), env, f);
  assert.equal(res.status, 200);
  assert.equal(res.headers.get('Access-Control-Allow-Origin'), ORIGIN);
  const body = await res.json();
  assert.equal(body.verdict, 'scam');
  assert.equal(body.summary, 'TE summary');
  assert.deepEqual(body.reasons, ['TE Threat to block today', 'TE Odd link sbi-kyc.co', 'TE Asks PAN']);
  assert.equal(body.lang, 'te');
  assert.equal(calls.length, 2);
  const g = calls[0];
  assert.equal(g.generationConfig.responseMimeType, 'application/json');
  assert.match(g.system_instruction.parts[0].text, /"verdict":"scam\|suspicious\|safe"/);
  assert.match(g.system_instruction.parts[0].text, /sancharsaathi\.gov\.in/);
  assert.match(g.contents[0].parts[0].text, /SENDER: VM-SBIINB/);
  assert.match(calls[1].system_instruction.parts[0].text, /Telugu/);
});

test('/scam keeps the English verdict when the translation fails', async () => {
  _resetRateLimit();
  let n = 0;
  const f = async () => {
    n++;
    if (n === 1) return new Response(JSON.stringify({ candidates: [{ content: { parts: [{ text: JSON.stringify({ verdict: 'safe', summary: 'Normal delivery update.', reasons: ['No link'], actions: ['Nothing to do'] }) }] } }] }));
    return new Response('busy', { status: 503 });
  };
  const body = await (await handle(post('/scam', { text: 'Your Amazon parcel was delivered.', lang: 'hi' }, { ip: '8.8.4.4' }), env, f)).json();
  assert.equal(body.verdict, 'safe');
  assert.equal(body.lang, 'en');
  assert.equal(body.requestedLang, 'hi');
});

test('/scam caps the message, validates input and has its own rate limit', async () => {
  _resetRateLimit();
  const calls = [];
  const f = reply({ verdict: 'weird', summary: 'x', reasons: ['a'], actions: [] }, calls);
  const res = await handle(post('/scam', { text: 'a'.repeat(5000) }, { ip: '2.2.2.2' }), env, f);
  assert.equal(res.status, 200);
  assert.equal((await res.json()).verdict, 'suspicious'); // unknown verdict -> suspicious
  assert.ok(calls[0].contents[0].parts[0].text.length < MAX_SCAM_TEXT + 100);
  assert.equal((await handle(post('/scam', { text: '' }, { ip: '3.3.3.3' }), env, f)).status, 400);
  assert.equal((await handle(post('/scam', 'nope', { ip: '3.3.3.4' }), env, f)).status, 400);
  assert.equal((await handle(post('/scam', { text: SBI }, { ip: '3.3.3.5' }), {}, f)).status, 503);
  const codes = [];
  for (let i = 0; i < 7; i++) codes.push((await handle(post('/scam', { text: SBI }, { ip: '4.4.4.4' }), env, f)).status);
  assert.deepEqual(codes, [200, 200, 200, 200, 200, 200, 429]);
  // the ask bucket for the same IP is untouched
  const ask = await handle(post('/ask', { question: 'Why?', story: { headline: 'H' } }, { ip: '4.4.4.4' }), env, reply('ok'));
  assert.equal(ask.status, 200);
});

test('/scam returns 502 when Gemini fails or answers garbage', async () => {
  _resetRateLimit();
  let n = 0;
  const bad = async () => {
    n++;
    return new Response('x', { status: 503 });
  };
  const r = await handle(post('/scam', { text: SBI }, { ip: '5.5.5.5' }), env, bad);
  assert.equal(r.status, 502);
  assert.equal((await r.json()).code, 'gemini 503,503,503');
  assert.equal(n, 3); // retry once, then the fallback model
  const junk = async () => new Response(JSON.stringify({ candidates: [{ content: { parts: [{ text: 'not json' }] } }] }));
  assert.equal((await handle(post('/scam', { text: SBI }, { ip: '5.5.5.6' }), env, junk)).status, 502);
});

test('/translate batches items into one call and keeps field shapes', async () => {
  _resetRateLimit();
  const calls = [];
  const f = reply((req) => {
    const items = JSON.parse(req.contents[0].parts[0].text).items;
    return JSON.stringify({ items: items.map((it) => ({ id: it.id, fields: Object.fromEntries(Object.entries(it.fields).map(([k, v]) => [k, Array.isArray(v) ? v.map((x) => `HI:${x}`) : `HI:${v}`])) })) });
  }, calls);
  const items = [
    { id: 's1', fields: { headline: 'Jio raises 5G prices', whatToDo: ['Check your plan', 'Recharge early'] } },
    { id: 's2', fields: { headline: 'New UPI rule', tldr: 'Limits change' } },
  ];
  const res = await handle(post('/translate', { lang: 'hi', items }), env, f);
  assert.equal(res.status, 200);
  const body = await res.json();
  assert.equal(calls.length, 1);
  assert.match(calls[0].system_instruction.parts[0].text, /Hindi/);
  assert.equal(body.items.length, 2);
  assert.deepEqual(body.items[0].fields.whatToDo, ['HI:Check your plan', 'HI:Recharge early']);
  assert.equal(body.items[1].fields.tldr, 'HI:Limits change');
});

test('/translate serves repeat items from cache (no second Gemini call)', async () => {
  _resetRateLimit();
  const store = new Map();
  const kvEnv = { ...env, TR: { get: async (k) => (store.has(k) ? JSON.parse(store.get(k)) : null), put: async (k, v) => store.set(k, v) } };
  const calls = [];
  const f = reply({ items: [{ id: 's1', fields: { headline: 'తెలుగు శీర్షిక' } }] }, calls);
  const req = () => post('/translate', { lang: 'te', items: [{ id: 's1', fields: { headline: 'English headline' } }] }, { ip: '6.6.6.6' });
  const a = await (await handle(req(), kvEnv, f)).json();
  const b = await (await handle(req(), kvEnv, f)).json();
  assert.equal(calls.length, 1);
  assert.equal(a.items[0].fields.headline, 'తెలుగు శీర్షిక');
  assert.equal(b.items[0].fields.headline, 'తెలుగు శీర్షిక');
  assert.equal(b.cached, 1);
  // changed content -> new hash -> translated again
  await handle(post('/translate', { lang: 'te', items: [{ id: 's1', fields: { headline: 'Edited headline' } }] }, { ip: '6.6.6.6' }), kvEnv, f);
  assert.equal(calls.length, 2);
});

test('/translate validation and helpers', async () => {
  _resetRateLimit();
  assert.equal((await handle(post('/translate', { lang: 'fr', items: [{ id: 'a', fields: { t: 'x' } }] }), env)).status, 400);
  const many = Array.from({ length: MAX_TR_ITEMS + 1 }, (_, i) => ({ id: `s${i}`, fields: { headline: 'x' } }));
  assert.equal((await handle(post('/translate', { lang: 'te', items: many }), env)).status, 400);
  assert.throws(() => cleanItems([{ id: 'a', fields: { headline: 'x'.repeat(1500) } }, ...Array.from({ length: 7 }, (_, i) => ({ id: `b${i}`, fields: { t: 'y'.repeat(1500) } }))]));
  assert.deepEqual(cleanItems([{ id: 'a', fields: { 'bad key': 'x', ok: 'y', n: 5 } }]), [{ id: 'a', fields: { ok: 'y' } }]);
  assert.equal(mergeTranslation({ a: 'x', b: ['1', '2'] }, { a: 'X', b: ['1'] }), null);
  assert.deepEqual(mergeTranslation({ a: 'x' }, { a: ' X ', extra: 'drop' }), { a: 'X' });
  assert.deepEqual(parseJson('```json\n{"a":1}\n```'), { a: 1 });
  assert.throws(() => cleanVerdict({ verdict: 'scam', summary: '', reasons: [] }));
});

test('unknown routes 404, GET 405', async () => {
  assert.equal((await handle(new Request('https://w.example/nope', { method: 'POST' }), env)).status, 404);
  assert.equal((await handle(new Request('https://w.example/scam'), env)).status, 405);
});

test('busy Gemini: retries, then answers from the fallback model', async () => {
  _resetRateLimit();
  const models = [];
  const f = async (url) => {
    models.push(decodeURIComponent(url.split('/models/')[1].split(':')[0]));
    if (models.length < 3) return new Response('busy', { status: 503 });
    return new Response(JSON.stringify({ candidates: [{ content: { parts: [{ text: JSON.stringify({ verdict: 'scam', summary: 's', reasons: ['r'], actions: ['a'] }) }] } }] }));
  };
  const res = await handle(post('/scam', { text: SBI }, { ip: '7.7.7.7' }), env, f);
  assert.equal(res.status, 200);
  assert.deepEqual(models, ['gemini-flash-lite-latest', 'gemini-flash-lite-latest', 'gemini-flash-latest']);
});
