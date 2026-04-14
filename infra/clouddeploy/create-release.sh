#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${1:?Usage: create-release.sh <project-id> <region> <image-tag>}"
REGION="${2:?Usage: create-release.sh <project-id> <region> <image-tag>}"
IMAGE_TAG="${3:?Usage: create-release.sh <project-id> <region> <image-tag>}"

gcloud deploy releases create "smartvenue-${IMAGE_TAG}" \
  --project "${PROJECT_ID}" \
  --region "${REGION}" \
  --delivery-pipeline smartvenue-pipeline \
  --skaffold-file infra/clouddeploy/skaffold.yaml \
  --source . \
  --images "backend=us-central1-docker.pkg.dev/${PROJECT_ID}/smartvenue/backend:${IMAGE_TAG},frontend=us-central1-docker.pkg.dev/${PROJECT_ID}/smartvenue/frontend:${IMAGE_TAG}"
