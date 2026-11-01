# Deploying the TechDaily backend (Firebase project `techdaily-prod`)

Everything below runs from the repo root (the folder that contains `firebase.json`), unless a step says `cd functions`.
Region: **us-central1**. Runtime: **Node.js 22**.

## 0. Prerequisites (one time)

```bash
npm install -g firebase-tools        # v13 or newer
firebase login                       # opens a browser; sign in with the Google account that owns techdaily-prod
firebase use techdaily-prod
```

### Upgrade the project to the Blaze (pay-as-you-go) plan
Scheduled functions, Secret Manager and outbound network calls (RSS feeds, Gemini) require Blaze.

1. Open https://console.firebase.google.com/project/techdaily-prod/usage/details
2. Click **Modify plan** → **Blaze** → attach a billing account.
3. Recommended: set a budget alert (e.g. ₹500/month) in Google Cloud Billing → Budgets & alerts.

Expected cost at this volume is small (hourly function runs + Firestore reads/writes are mostly inside the free quota).
Gemini cost depends on your AI Studio plan (see below).

## 1. Secrets

### GEMINI_API_KEY
1. Go to https://aistudio.google.com/app/apikey → **Create API key** (pick the `techdaily-prod` Google Cloud project).
2. Store it in Secret Manager:

```bash
firebase functions:secrets:set GEMINI_API_KEY
# paste the key when prompted
```

> The free Gemini tier is rate limited (a few requests per minute). The first ingestion run processes up to ~200 articles,
> so with a free key many of them will fall back to the rule-based summary (still published, no translations).
> They are automatically re-enriched with Gemini on later hourly runs. Enabling billing on the AI Studio key removes this limit.

### ADMIN_SECRET
Admin endpoints are **denied** when this is not set.

```bash
# generate a long random value and keep it somewhere safe (password manager)
openssl rand -hex 32
firebase functions:secrets:set ADMIN_SECRET
# paste the generated value when prompted
```

Check both exist: `firebase functions:secrets:access GEMINI_API_KEY` (prints the value) — or view them in
Google Cloud Console → Security → Secret Manager.

## 2. Build, test, deploy

```bash
cd functions
npm ci
npm run build
npm test
cd ..
firebase deploy --only functions,firestore
```

`firestore` deploys `firestore.rules` and `firestore.indexes.json` (new composite indexes:
`status + publishedAt` for the daily brief and `region + publishedAt` for the India section). Index builds take a few minutes;
check Firebase Console → Firestore → Indexes until they show **Enabled**.

Deployed functions:

| Function | Type | Purpose |
|---|---|---|
| `collectTechNews` | schedule, every 60 min | ingest all feeds |
| `scheduleDailyBrief` | schedule, `0 6 * * *` Asia/Kolkata | build today's brief + FCM push to topic `daily-brief` |
| `askArticle` | HTTPS (public, CORS) | Q&A grounded in one article |
| `triggerIngestion` | HTTPS (admin) | run ingestion now |
| `triggerDailyBrief` | HTTPS (admin) | build the brief now (`?push=true` also pushes) |
| `getIngestionStatus` | HTTPS (admin) | source health |
| `manageSource` | HTTPS (admin) | enable/disable a source |
| `purgeSeedArticles` | HTTPS (admin) | delete old demo/seeded articles |

Function URLs (2nd gen). Both forms work; the first is stable and recommended:

```
https://us-central1-techdaily-prod.cloudfunctions.net/<functionName>
https://<functionname>-<hash>-uc.a.run.app        # printed by `firebase deploy`
```

## 3. Remove the old seeded/demo articles

The purge deletes articles whose id starts with `demo-`, that have `seeded: true`, that were not written by the
ingestion engine (no `sourceId` / `ingestedAt`), or whose `sourceUrl` is a homepage / section hub
(e.g. `https://github.blog`, `https://blog.google/technology/ai/`). Always preview first:

```bash
export ADMIN_SECRET='<the value you set above>'
BASE=https://us-central1-techdaily-prod.cloudfunctions.net

# preview: counts + up to 25 sample ids, deletes nothing
curl -X POST "$BASE/purgeSeedArticles?dryRun=true" -H "Authorization: Bearer $ADMIN_SECRET"

# delete for real (also regenerates today's brief)
curl -X POST "$BASE/purgeSeedArticles" -H "Authorization: Bearer $ADMIN_SECRET"
```

> The Flutter app has a seeding service (`FirestoreSeedService.seedDemoArticles`). Make sure the app no longer seeds
> demo articles in production, otherwise they will come back. (Firestore rules already block client writes to `articles`.)

## 4. Trigger the first ingestion

```bash
# optional dry run (fetches + parses + summarizes, writes nothing)
curl -X POST "$BASE/triggerIngestion?dryRun=true" -H "Authorization: Bearer $ADMIN_SECRET"

# real run (takes 2–8 minutes; returns per-source counts)
curl -X POST "$BASE/triggerIngestion" -H "Authorization: Bearer $ADMIN_SECRET" --max-time 600

# build today's brief and send the daily-brief push now (optional)
curl -X POST "$BASE/triggerDailyBrief?push=true" -H "Authorization: Bearer $ADMIN_SECRET"

# source health
curl "$BASE/getIngestionStatus" -H "Authorization: Bearer $ADMIN_SECRET"
```

After that, `collectTechNews` keeps the feed fresh every hour and `scheduleDailyBrief` runs at 06:00 IST.

## 5. askArticle contract

```
POST https://us-central1-techdaily-prod.cloudfunctions.net/askArticle
Content-Type: application/json

{ "articleId": "art-3f1c...", "question": "When does this ship?" }
```

Responses:

| Status | Body |
|---|---|
| 200 | `{ "answer": "…", "grounded": "gemini" \| "fallback", "articleId": "art-…" }` |
| 400 | `{ "error": "question is required" }` / question > 500 chars / bad articleId |
| 404 | `{ "error": "Article not found" }` |
| 405 | non-POST |
| 429 | `{ "error": "Rate limit exceeded (20 questions per hour)…" }` (per client IP, `Retry-After: 3600`) |

CORS allows `https://techdaily-prod.web.app`, `https://techdaily-prod.firebaseapp.com`, and `http(s)://localhost:*` / `127.0.0.1:*`.
If you add a custom domain, add it to `ASK_ALLOWED_ORIGINS` in `functions/src/ask/ask-article.ts` and redeploy.

Optional: enable a Firestore TTL policy so rate-limit counters clean themselves up:
Firebase Console → Firestore → TTL → collection group `askRateLimits`, field `expiresAt`.

## 6. Push notifications (FCM)

The backend sends to two topics; the apps must subscribe:

- `breaking` — fresh (< 3 h old) articles flagged breaking; max 3 per ingestion run.
- `daily-brief` — every day after the 06:00 IST brief (title "Today in Tech", body = top headline).

Android/iOS: `FirebaseMessaging.instance.subscribeToTopic('breaking')` / `('daily-brief')`.
Web: the JS SDK cannot subscribe to topics directly; web push for topics needs a small server endpoint
(not included) — Android/iOS work out of the box.

## 7. Local commands

```bash
cd functions
npm run ingest -- --dry-run --concurrency=8                 # all sources, no Firestore
npm run ingest -- --dry-run --source=inc42                  # one source
GEMINI_API_KEY=... npm run ingest -- --dry-run --source=techcrunch   # test Gemini output locally
```

## Troubleshooting

- **403 "Admin endpoints are disabled"** → `ADMIN_SECRET` is not set or the function was deployed before it was set; set it and redeploy.
- **Daily brief fails with FAILED_PRECONDITION / index** → the `status + publishedAt` index is still building.
- **Articles without translations / `aiModel: techdaily-editorial-engine-v1`** → Gemini key missing or rate limited; they are re-enriched automatically later.
- Logs: `firebase functions:log --only collectTechNews`
