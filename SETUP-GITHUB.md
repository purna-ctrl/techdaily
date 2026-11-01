# Running TechDaily on the free Spark plan with GitHub Actions

Firebase project: `techdaily-prod` (number `1015898924676`).

On Spark, Cloud Functions cannot be deployed. Instead:

| Job | Workflow | When | Command |
|---|---|---|---|
| Ingest all feeds (+ breaking pushes) | `.github/workflows/news.yml` | every 2 h (`0 */2 * * *` UTC) + manual | `npx tsx src/jobs.ts ingest` |
| "Today in Tech" brief + push | `.github/workflows/brief.yml` | 06:00 IST (`30 0 * * *` UTC) + manual | `npx tsx src/jobs.ts daily-brief` |
| Delete seeded/demo articles | `.github/workflows/maintenance.yml` | manual only, `dry_run` defaults to **true** | `npx tsx src/jobs.ts purge-seed [--dry-run]` |
| Build Flutter web, deploy Hosting + Firestore rules/indexes | `.github/workflows/deploy.yml` | push to `main` touching `lib/`, `web/`, `assets/`, `pubspec.*`, `firestore.*`, `firebase.json` + manual | `firebase deploy --only hosting,firestore` |

Auth is keyless (Workload Identity Federation): no service-account JSON key is stored anywhere.
The only GitHub secret is **`GEMINI_API_KEY`**. `ADMIN_SECRET` is not used by these jobs.

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

1. **Deploy web + Firestore** → *Run workflow* (publishes the site, rules and indexes; indexes take a few minutes to build).
2. **Ingest news** → *Run workflow* (tick *Dry run* first if you want to see it without writes).
3. **Daily brief** → *Run workflow*.
4. Optional: **Maintenance - purge seed articles** with *dry_run* ticked, read the counts in the run summary, then run again unticked.

## Running a job from your own machine

```bash
cd functions
npm ci
gcloud auth application-default login     # or GOOGLE_APPLICATION_CREDENTIALS=<key.json>
GEMINI_API_KEY=... npx tsx src/jobs.ts ingest --dry-run --source=aws-blog
npx tsx src/jobs.ts daily-brief --no-push
npx tsx src/jobs.ts purge-seed --dry-run
```

Options: `ingest [--dry-run] [--source=<id>] [--concurrency=N] [--json-out=file]`,
`daily-brief [--no-push]`, `purge-seed [--dry-run]`. `FIREBASE_PROJECT_ID` overrides the project (default `techdaily-prod`).

## If you ever move to Blaze

`functions/src/index.ts` is unchanged; `functions/DEPLOY.md` still applies. Disable the `news.yml`
and `brief.yml` schedules first so the jobs do not run twice.
