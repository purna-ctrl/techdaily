# TechDaily

Technology news — and only technology news — for everyday people in India, in simple words: AI, phones
and gadgets, chips and hardware, startups and India tech, innovations, money and fintech, privacy, scams &
security, telecom & internet, Digital India, EVs & mobility, space tech, apps & gaming, health tech, and
tech jobs & skills.
Every story says **what happened**, **does it affect me?**, **what to do**, and **what this means for you**,
with links to every original report.

Live: https://techdaily-prod.web.app (Firebase **Spark / free** plan — no Cloud Functions, no SSR).

## How it works (v2)

```
GitHub Actions (hourly, news.yml)
  ingest  → fetch ~65 RSS feeds → purely-tech gate (tech-filter.ts) → cluster reports about the same event → one Gemini call per story
            (gemini-flash-lite-latest, JSON, original words) or rule-based fallback → Firestore `stories`
            → "Today in 5" (`storyBriefs/latest`)
  render  → static HTML into the Flutter web build: /story/<slug>/, /c/<category>/, sitemap.xml,
            rss.xml, robots.txt, /data/feed.json (the app's data), SEO block in /index.html
  deploy  → firebase deploy --only hosting
```

| Path | What |
|---|---|
| `lib/` | Flutter app. v2 screens in `lib/screens/v2/`, story model `lib/models/story.dart`, data `lib/repositories/story_repository.dart` (reads `/data/feed.json`, falls back to Firestore). Older v1 screens are kept (compiling) but no longer in navigation; `/article/<id>` links still open. |
| `functions/src/stories/` | v2 pipeline: `feeds.ts`, `clusterer.ts`, `story-writer.ts`, `story-pipeline.ts`, `ranking.ts`, `story-store.ts`, `migrate.ts`, `render/`. |
| `functions/src/jobs.ts` | CLI run by the workflows: `ingest`, `render`, `daily-brief`, `migrate-articles`, `purge-non-tech` (+ legacy `ingest-articles`, `purge-seed`). |
| Purely tech | `functions/src/stories/tech-filter.ts`: a keyword gate drops politics, sports, celebrity, stock-market-only and other non-tech items at ingest (mixed-beat feeds must show a tech signal); Gemini also answers `isTech` and `false` discards the story. Each hourly ingest removes stored non-tech stories (cache + Firestore) and remembers their URLs; `purge-non-tech` scans all of Firestore (dry run unless `--apply`; Maintenance workflow with dry_run unchecked). |
| `web/og/` | Generated 1200×630 category preview images (`python3 tool/og/generate_og.py`). Used only when a story has no photo. |
| `web/art/`, `tool/art/` | Generated category artwork (`python3 tool/art/generate_art.py`), the fallback behind every story photo. |
| Story photos | Publisher images are **hotlinked, never downloaded or rehosted**, always shown with an "Image: Source" credit linking to the original. Ingest reads them from RSS media tags or og:image; `ingest --image-fetches=N` caps og:image lookups and backfill per run (default 60). |
| `.github/workflows/` | `news.yml` (hourly), `brief.yml` (06:00 IST push), `deploy.yml` (on push), `maintenance.yml` (manual). |

## Develop

```bash
flutter pub get && flutter analyze && flutter test
flutter build web --release

cd functions && npm ci && npm test && npx tsc --noEmit
npx tsx src/jobs.ts ingest --dry-run --stories-out=/tmp/stories.json      # no Firestore, no key needed
npx tsx src/jobs.ts render --from-json=/tmp/stories.json --out=../build/web
```

Offline demo app with sample stories: `flutter run -d chrome --dart-define=TECHDAILY_DATA_SOURCE=local`.

Setup, secrets and workflows: see [SETUP-GITHUB.md](SETUP-GITHUB.md).
