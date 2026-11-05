# techdaily-ask (Cloudflare Worker)

TechDaily's AI Worker. Three routes, one Gemini key (Worker secret `GEMINI_API_KEY`), free plans only.

| Route | What it does | Limit per IP |
|---|---|---|
| `POST /ask` | "Ask your own question" about a story — answers **only** from the story context the app sends | `RATE_LIMIT` (8/min) |
| `POST /scam` | "Is this a scam?" — checks one pasted SMS / WhatsApp / email | `SCAM_RATE_LIMIT` (6/min) |
| `POST /translate` | Story text into simple Telugu / Hindi, cached per story | `TRANSLATE_RATE_LIMIT` (30/min) |

CORS allows `https://techdaily-prod.web.app` (+ `ALLOWED_ORIGINS`). Rate limits are in-memory per
isolate; bind a KV namespace as `RL` to share them across isolates.

When Gemini is busy (429 / 5xx / 15 s timeout) each call retries once, then tries
`GEMINI_FALLBACK_MODEL` (default `gemini-flash-latest`). Errors return `{error, code}` (code like
`gemini 503,503,504 timeout`); the app then falls back on the device.

## Deploy

```bash
cd workers/ask
CLOUDFLARE_API_TOKEN=... CLOUDFLARE_ACCOUNT_ID=... npx wrangler@4 deploy   # keeps the GEMINI_API_KEY secret
npx wrangler secret put GEMINI_API_KEY                                    # only the first time
```

The app points at it through `kAskEndpoint` in `lib/core/config/app_config.dart`
(`--dart-define=ASK_ENDPOINT=...`).

## Contracts

### `/ask`
`{"slug", "question" (≤300), "story": {headline, category, tldr, whatHappened, affectsWho, whatToDo[],
goodToKnow, whatItMeans, keyNumbers[], faq[], scam?, sources[]}}` → `{"answer"}`.

### `/scam`
`{"text" (cut at 2000 chars), "sender"? (≤80), "lang": "en"|"te"|"hi"}` →
`{"verdict": "scam"|"suspicious"|"safe", "summary", "reasons": [2-4], "actions": [≤4], "lang"}`.

The check runs in English with JSON output (shape enforced by `cleanVerdict`), then — for te / hi —
one translation call. If only the translation fails, the English verdict comes back with
`"lang": "en", "requestedLang": "te"` and the app shows a "Showing English" note. Actions only use
real Indian channels: Chakshu on sancharsaathi.gov.in (fraud SMS/calls/WhatsApp), 1909 (spam
marketing SMS), 1930 / cybercrime.gov.in (money lost or OTP shared). **Messages are never stored or
logged.**

### `/translate`
`{"lang": "te"|"hi", "items": [{"id", "fields": {name: string | string[]}}]}` (≤12 items,
≤9000 characters) → `{"lang", "items": [{"id", "fields"}], "cached", "missing"}`.

Field names and shapes come back unchanged (lists keep their length); brand names, numbers and tech
words (UPI, 5G, OTP, app) stay in English. Each item is cached by `lang + id + SHA-256(fields)` in the
Cloudflare Cache API (works on custom domains) **and** the `TR` KV namespace (works on
`*.workers.dev`; 30-day TTL; free plan 1,000 writes/day), so a story is translated once per language
and every reader after that gets the cached copy. The app sends its own cache key
(`lang|storyId|card|full|hash`) as the item id.

| Status | When |
|---|---|
| 400 | invalid JSON / missing or too long input / bad lang |
| 403 | browser Origin not allowed |
| 413 | body too large |
| 429 | over the route's per-minute limit |
| 502 / 503 | Gemini failed / `GEMINI_API_KEY` not set — the app falls back on the device |

## Test

```bash
cd workers/ask && npm test     # node --test, no network
```
