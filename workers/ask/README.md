# techdaily-ask (Cloudflare Worker)

Answers the app's **"Ask your own question"** box for a story, using Gemini, **restricted to the
story context the app sends** (headline, the story's sections, key numbers, FAQ, source names). If
the story doesn't cover a question, it says so and the app offers the sources.

Not deployed automatically. Free Cloudflare Workers plan is enough.

## Deploy

```bash
cd workers/ask
npx wrangler login
npx wrangler secret put GEMINI_API_KEY     # Worker secret, never in code or wrangler.toml
npx wrangler deploy                        # prints https://techdaily-ask.<account>.workers.dev
```

Then point the app at it — either edit `kAskEndpoint` in `lib/core/config/app_config.dart` or build with

```bash
flutter build web --release --dart-define=ASK_ENDPOINT=https://techdaily-ask.<account>.workers.dev/ask
```

While `ASK_ENDPOINT` is empty (the default) the app answers on the device from the story's FAQ, the
jargon dictionary and its sections.

## Contract

`POST /ask` with JSON `{"slug": "...", "question": "...", "story": {headline, category, tldr,
whatHappened, affectsWho, whatToDo[], goodToKnow, whatItMeans, keyNumbers[], faq[], scam?, sources[]}}`
→ `200 {"answer": "..."}`.

| Status | When |
|---|---|
| 400 | invalid JSON, empty question, question > 300 characters, no story context |
| 403 | browser Origin not allowed (CORS allows `https://techdaily-prod.web.app` + `ALLOWED_ORIGINS`) |
| 413 | body > 20 kB |
| 429 | more than `RATE_LIMIT` (default 8) questions per IP per minute |
| 502 / 503 | Gemini failed / `GEMINI_API_KEY` not set — the app then answers on the device |

Rate limiting is in-memory per isolate; bind a KV namespace as `RL` (see `wrangler.toml`) to share
it across isolates.

## Test

```bash
cd workers/ask && npm test
```
