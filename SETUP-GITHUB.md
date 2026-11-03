# Running TechDaily on the free Spark plan with GitHub Actions

Firebase project: `techdaily-prod` (number `1015898924676`).

On Spark, Cloud Functions cannot be deployed. Instead:

| Job | Workflow | When | Command(s) |
|---|---|---|---|
| **News**: ingest stories → render static pages → deploy Hosting | `.github/workflows/news.yml` | hourly at :05 (`5 * * * *` UTC) + manual (*dry run* box) | `jobs.ts ingest`, `jobs.ts render`, `firebase deploy --only hosting` |
| "Today in 5" morning edition + push | `.github/workflows/brief.yml` | 06:00 IST (`30 0 * * *` UTC) + manual | `jobs.ts daily-brief` |
| Build Flutter web + render + deploy Hosting **and** Firestore rules/indexes | `.github/workflows/deploy.yml` | push to `main` touching `lib/`, `web/`, `assets/`, `pubspec.*`, `firestore.*`, `firebase.json`, `functions/src/stories/render/**` + manual | `flutter build web`, `jobs.ts render`, `firebase deploy --only hosting,firestore` |
| Maintenance: `migrate-articles` (v1 `articles` → v2 `stories`) or `purge-seed` | `.github/workflows/maintenance.yml` | manual only, `dry_run` defaults to **true** | `jobs.ts migrate-articles` / `jobs.ts purge-seed` |

Auth is keyless (Workload Identity Federation): no service-account JSON key is stored anywhere.
The only GitHub secret is **`GEMINI_API_KEY`**. Optional repository *variable* `GEMINI_MODEL` overrides the
default model `gemini-flash-lite-latest`. `ADMIN_SECRET` is not used by these jobs.

GitHub notes: scheduled runs can start a few minutes late, and GitHub disables schedules in a repo
with no activity for 60 days (re-enable from the Actions tab). The `askArticle` Q&A endpoint is a
Cloud Function and is not available on Spark.

---

## 1. Create the repository and push

```bash
cd techdaily                     # the folder with firebase.json
# create an EMPTY repo on github.com first (private is fine), then:
git remote add origin https://github.com/__GH_REPO__.git
git push -u origin main
```

## 2. Workload Identity Federation (one time, Google Cloud Shell)

Open https://console.cloud.google.com/?project=techdaily-prod → **Activate Cloud Shell**, upload
`setup-wif.sh` (⋮ → Upload) and run:

```bash
bash setup-wif.sh __GH_REPO__
```

The script is idempotent. The same steps, command by command:

```bash
PROJECT_ID=techdaily-prod
PROJECT_NUMBER=1015898924676
REPO=__GH_REPO__                 # e.g. yourname/techdaily
SA=github-deployer@techdaily-prod.iam.gserviceaccount.com

gcloud config set project $PROJECT_ID

# APIs
gcloud services enable iam.googleapis.com iamcredentials.googleapis.com sts.googleapis.com \
  cloudresourcemanager.googleapis.com serviceusage.googleapis.com firebase.googleapis.com \
  firebasehosting.googleapis.com firestore.googleapis.com firebaserules.googleapis.com fcm.googleapis.com

# Pool + OIDC provider, restricted to this one repository
gcloud iam workload-identity-pools create github \
  --location=global --display-name="GitHub Actions"

gcloud iam workload-identity-pools providers create-oidc github \
  --location=global --workload-identity-pool=github --display-name="GitHub" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
  --attribute-condition="assertion.repository=='__GH_REPO__'"

# Service account the workflows act as
gcloud iam service-accounts create github-deployer --display-name="GitHub Actions deployer"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA" --role="roles/firebase.admin" --condition=None
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA" --role="roles/serviceusage.serviceUsageConsumer" --condition=None

# Let workflows from the repo impersonate it
gcloud iam service-accounts add-iam-policy-binding $SA \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/1015898924676/locations/global/workloadIdentityPools/github/attribute.repository/__GH_REPO__"
```

`roles/firebase.admin` covers Firestore reads/writes, FCM sends, Hosting and rules/index deploys.
New IAM bindings can take a few minutes to take effect; if the first run fails with
`PERMISSION_DENIED`, wait 5 minutes and re-run.

## 3. GitHub secret

Repo → **Settings → Secrets and variables → Actions → New repository secret**

| Name | Value |
|---|---|
| `GEMINI_API_KEY` | key from https://aistudio.google.com/app/apikey (optional: without it articles get rule-based summaries) |

## 4. First runs (Actions tab)

1. **Deploy web + Firestore** → *Run workflow* (publishes the app, the v2 rules — `stories`, `storyBriefs`,
   `signups`, `users/*/savedStories` — and the `stories(category, publishedAt)` index).
2. **Maintenance** → task `migrate-articles`, *dry_run* ticked → read the counts → run again unticked.
   Converts the ~215 v1 `articles` into clustered `stories` with fallback cards (`articles` is only read).
3. **News (ingest + render + deploy)** → *Run workflow* (tick *Dry run* first to see feeds/clusters without
   writes or deploy). After that it runs every hour by itself.
4. **Today in 5 (06:00 IST)** → *Run workflow* (untick *push* to test without a notification).

## v2 stories pipeline

* **Feeds** (`functions/src/stories/feeds.ts`, 41 feeds, all checked with curl + the parser on 2026-11-01):
  India — Gadgets 360, MediaNama, ET Tech, ET BFSI, ET Telecom, The Hindu (tech, gadgets, science), Mint,
  The Indian Express, Inc42, YourStory, Entrackr; official — RBI press releases (filtered to
  fraud/payments/digital items), CISA, Google Security Blog, OpenAI, Google, Microsoft, Apple, NVIDIA, Meta,
  NASA, GitHub, AWS; security — The Hacker News, BleepingComputer, Krebs, Malwarebytes, ESET; privacy — EFF;
  global — The Verge, TechCrunch (+fintech), Ars Technica, Wired, Engadget, GSMArena, Tom's Hardware,
  MIT Technology Review, ScienceDaily.
  **Not used** (no working RSS from GitHub-like IPs on 2026-11-01): Moneycontrol (403), PIB (403),
  CERT-In (no RSS), NPCI (empty), SEBI (no dates), Digit/91mobiles (404), BGR India (timeout).
* **Clustering**: reports within 36 h whose headlines share rare words (IDF-weighted overlap + bigram
  shingles) become one story with all sources. Deals, reviews, "best X under ₹Y" lists, puzzles and
  newsletters are skipped.
* **Writer**: one Gemini call per story (`GEMINI_MAX_CALLS_PER_RUN=40`, `GEMINI_MIN_INTERVAL_MS=4500`,
  stops on HTTP 429). Output is JSON, validated, and rejected if it copies 10+ consecutive words from a
  report. Otherwise a rule-based card is written (low confidence, "Developing" badge) and re-enriched by a
  later run (newest first, within 72 h, max 3 tries). Feed text for that is kept server-only in `storySources`.
* **Firestore**: `stories/{id}` (public read), `storyBriefs/latest` + `storyBriefs/<IST date>` (public read),
  `storySources/{id}` (no client access), `signups/{id}` (create-only, email validated, `createdAt == request.time`).
* **Static site**: `render` writes `/story/<slug>/` (NewsArticle JSON-LD, OG/Twitter tags, canonical,
  WhatsApp/Telegram/X share, "Open in app", newsletter form), `/c/<category>/`, `/sitemap.xml`, `/rss.xml`,
  `/robots.txt`, `/data/feed.json` (what the app reads), and a "Today in 5" + latest block in `/index.html`.
  Hosting serves these files before the `** → /index.html` rewrite. OG images are per category
  (`web/og/*.png`, generated once by `tool/og/generate_og.py`); story photos are publisher images hotlinked (never copied) with a visible credit link; category art in `web/art/` is the fallback. `ingest --image-fetches=N` caps og:image lookups per run.

### Free-tier budget (why it is built this way)

* **Firestore reads (50k/day)**: visitors read `/data/feed.json` from Hosting, not Firestore. The jobs keep a
  story snapshot in the Actions cache (`functions/.cache/stories.json`) and only read stories changed since
  the last run; a cold start reads at most 3,000 docs once.
* **Hosting transfer (360 MB/day on Spark)**: story pages are ~18 KB; the Flutter app (`main.dart.js`
  ≈ 1 MB gzipped) is the expensive part, so shared links open the light static page first.
  Set **Hosting → Release storage settings** to keep e.g. the last 20 releases (hourly deploys add up).
* **GitHub Actions minutes**: an hourly run takes ~2–4 min (the Flutter build is cached and only rebuilt when
  the app changes; Gemini pacing is most of the time). That is ~1,500–2,900 min/month — above the 2,000
  free minutes of a **private** repo. Either change the cron to every 2 hours (`5 */2 * * *`, ~750–1,450 min),
  or make the repo public (Actions minutes are free for public repos). A public repo would expose
  `lib/firebase_options.dart` (Firebase web config — meant to be public, but restrict that API key to your
  domains in Google Cloud → Credentials first). No other keys are in the repo.

## Running a job from your own machine

```bash
cd functions
npm ci
gcloud auth application-default login     # or GOOGLE_APPLICATION_CREDENTIALS=<key.json>
npx tsx src/jobs.ts ingest --dry-run --stories-out=/tmp/stories.json      # no credentials needed
npx tsx src/jobs.ts render --from-json=/tmp/stories.json --out=../build/web # after flutter build web
GEMINI_API_KEY=... npx tsx src/jobs.ts ingest --cache=.cache/stories.json   # live (writes Firestore)
npx tsx src/jobs.ts daily-brief --no-push
npx tsx src/jobs.ts migrate-articles --dry-run
```

Options: `ingest [--dry-run] [--source=<id,id>] [--concurrency=N] [--cache=file] [--json-out=file] [--stories-out=file] [--max-age-hours=48]`,
`render [--out=../build/web] [--cache=file | --from-json=file] [--site-url=URL]`, `daily-brief [--no-push] [--cache=file]`,
`migrate-articles [--dry-run] [--limit=N]`, legacy `ingest-articles`, `purge-seed [--dry-run]`.
`FIREBASE_PROJECT_ID` overrides the project (default `techdaily-prod`).

## If you ever move to Blaze

`functions/src/index.ts` is unchanged; `functions/DEPLOY.md` still applies. Disable the `news.yml`
and `brief.yml` schedules first so the jobs do not run twice. Note `functions/src/index.ts` still runs the
v1 `articles` pipeline; the v2 stories pipeline only runs from `jobs.ts`.
