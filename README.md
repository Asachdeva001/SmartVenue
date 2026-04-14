# SmartVenue (GCP Serverless Starter)

SmartVenue is a real-time event operations platform designed for large sporting venues (50,000-80,000 attendees). This starter project uses an event-driven, serverless architecture aligned with GCP production patterns.

## Included Components

- `apps/backend` - Cloud Run backend API for event ingestion and real-time state reads
- `apps/frontend` - Cloud Run frontend service (starter operations UI)
- `functions/event-processor` - Cloud Functions Gen2 subscriber to project Pub/Sub events into Firestore state
- `functions/alert-engine` - Cloud Functions Gen2 alert evaluator and Pub/Sub alert emitter
- `cloudbuild.yaml` - Cloud Build pipeline example for build + Cloud Run deployment

## GCP Services Used

- Cloud Run
- Pub/Sub
- Cloud Functions Gen2
- Firestore
- BigQuery (ready for downstream integration)
- Looker Studio (for dashboards over BigQuery)
- Cloud Load Balancer + Cloud Armor
- Cloud Build + Cloud Deploy
- Secret Manager
- Cloud Monitoring

## Local Build

```bash
npm install
npm run build
```

## Environment Variables

### Backend (`apps/backend`)

- `PORT` (default: `8080`)
- `GCP_PROJECT_ID`
- `INGEST_TOPIC` (default: `smartvenue.events.raw`)

### Frontend (`apps/frontend`)

- `PORT` (default: `8081`)
- `BACKEND_URL` (default: `http://localhost:8080`)

### Alert Engine (`functions/alert-engine`)

- `ALERTS_TOPIC` (default: `smartvenue.alerts`)
- `GATE_WAIT_THRESHOLD_SEC` (default: `600`)

## Suggested Topic Layout

- `smartvenue.events.raw`
- `smartvenue.events.processed` (optional)
- `smartvenue.alerts`
- `smartvenue.events.raw.dlq` (dead-letter topic)

## Deployment Notes

1. Create Pub/Sub topics and subscriptions for both functions.
2. Deploy backend and frontend Cloud Run services behind Cloud Load Balancer and protect with Cloud Armor.
3. Deploy functions as Gen2 Pub/Sub-triggered handlers.
4. Use Firestore for hot operational state and BigQuery for historical analytics.
5. Build Looker Studio dashboards on BigQuery tables.
6. Configure Cloud Monitoring SLO alerts (latency, backlog, error rates, DLQ depth).

## Infrastructure as Code (Terraform)

- Root: `infra/terraform`
- Environment vars files:
  - `infra/terraform/environments/dev/terraform.tfvars`
  - `infra/terraform/environments/stage/terraform.tfvars`
  - `infra/terraform/environments/prod/terraform.tfvars`

Terraform provisions:
- APIs/services enablement
- Pub/Sub topics, subscriptions, retry and dead-letter policies
- Firestore default database
- BigQuery dataset and base tables
- Secret Manager secrets
- Service accounts and least-privilege IAM role bindings
- Cloud Run backend/frontend services with autoscaling defaults

Run example:

```bash
cd infra/terraform
terraform init
terraform plan -var-file=environments/dev/terraform.tfvars
terraform apply -var-file=environments/dev/terraform.tfvars
```

## BigQuery Table Schemas

Schema files are under `infra/bigquery/schemas`:
- `events_raw.json`
- `gate_metrics_realtime.json`
- `concession_metrics_realtime.json`
- `incidents.json`

These are consumed directly by Terraform table resources.

## Cloud Deploy Pipeline Targets

Cloud Deploy manifests are under `infra/clouddeploy`:
- `pipeline.yaml` - delivery pipeline (`dev -> stage -> prod`)
- `targets.yaml` - target definitions (prod approval required)
- `skaffold.yaml` - render config for Cloud Run manifests
- `manifests/*.yaml` - backend and frontend Cloud Run services

Apply the pipeline and targets:

```bash
gcloud deploy apply --file infra/clouddeploy/targets.yaml --region us-central1 --project YOUR_HOST_PROJECT
gcloud deploy apply --file infra/clouddeploy/pipeline.yaml --region us-central1 --project YOUR_HOST_PROJECT
```
