import test from 'node:test';
import assert from 'node:assert';
import { handle, targetFrom } from '../worker.js';
const req = (u, o = 'https://techdaily-prod.web.app') => new Request('https://w.dev/?u=' + encodeURIComponent(u), { headers: { Origin: o } });
test('rejects bad and private urls', () => {
  for (const u of ['ftp://x/a.png', 'http://127.0.0.1/a.png', 'http://localhost/a', 'notaurl']) assert.equal(targetFrom(new URL('https://w/?u=' + encodeURIComponent(u))), null);
});
test('passes images with CORS', async () => {
  const f = async () => new Response('IMG', { headers: { 'Content-Type': 'image/jpeg' } });
  const r = await handle(req('https://cdn.example.com/a.jpg'), {}, null, f, null);
  assert.equal(r.status, 200);
  assert.equal(r.headers.get('Access-Control-Allow-Origin'), 'https://techdaily-prod.web.app');
  assert.equal(await r.text(), 'IMG');
});
test('refuses non-images', async () => {
  const f = async () => new Response('<html>', { headers: { 'Content-Type': 'text/html' } });
  assert.equal((await handle(req('https://e.com/p'), {}, null, f, null)).status, 502);
});
