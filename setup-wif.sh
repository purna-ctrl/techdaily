#!/usr/bin/env bash
# One-time setup: lets GitHub Actions in ONE repository act as the
# github-deployer service account of techdaily-prod, keyless (Workload Identity Federation).
#
# Usage (Google Cloud Shell, signed in as the project owner):
#   bash setup-wif.sh OWNER/REPO
#
# Safe to run again: anything that already exists is skipped.
set -euo pipefail

REPO="${1:-}"
if [[ -z "$REPO" || "$REPO" != */* ]]; then
  echo "Usage: bash setup-wif.sh OWNER/REPO   (e.g. purnavalluri/techdaily)" >&2
  exit 1
fi

PROJECT_ID="techdaily-prod"
PROJECT_NUMBER="1015898924676"
POOL="github"
PROVIDER="github"
SA_NAME="github-deployer"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

# Runs a gcloud create command; treats "already exists" as success.
create() {
  local out
  if out=$("$@" 2>&1); then
    echo "  created"
  elif grep -qiE "already exists|ALREADY_EXISTS" <<<"$out"; then
    echo "  already exists, skipped"
  else
    echo "$out" >&2
    return 1
  fi
}

gcloud config set project "$PROJECT_ID" >/dev/null

echo "==> Enabling APIs"
gcloud services enable \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  sts.googleapis.com \
  cloudresourcemanager.googleapis.com \
  serviceusage.googleapis.com \
  firebase.googleapis.com \
  firebasehosting.googleapis.com \
  firestore.googleapis.com \
  firebaserules.googleapis.com \
  fcm.googleapis.com \
  --project "$PROJECT_ID"

echo "==> Workload identity pool '$POOL'"
create gcloud iam workload-identity-pools create "$POOL" \
  --project "$PROJECT_ID" --location global \
  --display-name "GitHub Actions"

echo "==> OIDC provider '$PROVIDER' (restricted to $REPO)"
create gcloud iam workload-identity-pools providers create-oidc "$PROVIDER" \
  --project "$PROJECT_ID" --location global \
  --workload-identity-pool "$POOL" \
  --display-name "GitHub" \
  --issuer-uri "https://token.actions.githubusercontent.com" \
  --attribute-mapping "google.subject=assertion.sub,attribute.repository=assertion.repository" \
  --attribute-condition "assertion.repository=='${REPO}'"
# Re-runs with a different repo: keep the condition in sync.
gcloud iam workload-identity-pools providers update-oidc "$PROVIDER" \
  --project "$PROJECT_ID" --location global \
  --workload-identity-pool "$POOL" \
  --attribute-condition "assertion.repository=='${REPO}'" >/dev/null

echo "==> Service account $SA_EMAIL"
create gcloud iam service-accounts create "$SA_NAME" \
  --project "$PROJECT_ID" \
  --display-name "GitHub Actions deployer"

echo "==> Project roles for the service account"
for ROLE in roles/firebase.admin roles/serviceusage.serviceUsageConsumer; do
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member "serviceAccount:${SA_EMAIL}" --role "$ROLE" \
    --condition=None >/dev/null
  echo "  $ROLE"
done

echo "==> Allow $REPO to impersonate the service account"
gcloud iam service-accounts add-iam-policy-binding "$SA_EMAIL" \
  --project "$PROJECT_ID" \
  --role roles/iam.workloadIdentityUser \
  --member "principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL}/attribute.repository/${REPO}" \
  >/dev/null

echo
echo "Done. Values used by the workflows:"
echo "  workload_identity_provider: projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL}/providers/${PROVIDER}"
echo "  service_account:            ${SA_EMAIL}"
echo "Next: add the GEMINI_API_KEY secret in GitHub → Settings → Secrets and variables → Actions."
