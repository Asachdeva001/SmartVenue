locals {
  prefix = "smartvenue-${var.environment}"
  labels = {
    app         = "smartvenue"
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "google_project_service" "enabled" {
  for_each = toset([
    "run.googleapis.com",
    "pubsub.googleapis.com",
    "cloudfunctions.googleapis.com",
    "firestore.googleapis.com",
    "bigquery.googleapis.com",
    "cloudbuild.googleapis.com",
    "clouddeploy.googleapis.com",
    "compute.googleapis.com",
    "secretmanager.googleapis.com",
    "monitoring.googleapis.com",
    "artifactregistry.googleapis.com"
  ])

  project                    = var.project_id
  service                    = each.value
  disable_on_destroy         = false
  disable_dependent_services = false
}

resource "google_pubsub_topic" "events_raw" {
  name   = "${local.prefix}-events-raw"
  labels = local.labels
}

resource "google_pubsub_topic" "alerts" {
  name   = "${local.prefix}-alerts"
  labels = local.labels
}

resource "google_pubsub_topic" "events_raw_dlq" {
  name   = "${local.prefix}-events-raw-dlq"
  labels = local.labels
}

resource "google_pubsub_subscription" "event_processor_sub" {
  name  = "${local.prefix}-event-processor-sub"
  topic = google_pubsub_topic.events_raw.id

  ack_deadline_seconds       = 20
  message_retention_duration = "604800s"

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.events_raw_dlq.id
    max_delivery_attempts = 10
  }

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "300s"
  }
}

resource "google_pubsub_subscription" "alert_engine_sub" {
  name  = "${local.prefix}-alert-engine-sub"
  topic = google_pubsub_topic.events_raw.id

  ack_deadline_seconds       = 20
  message_retention_duration = "604800s"

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.events_raw_dlq.id
    max_delivery_attempts = 10
  }

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "300s"
  }
}

resource "google_firestore_database" "default" {
  project     = var.project_id
  name        = "(default)"
  location_id = var.region
  type        = "FIRESTORE_NATIVE"
}

resource "google_bigquery_dataset" "smartvenue" {
  dataset_id  = "smartvenue_${var.environment}"
  friendly_name = "SmartVenue ${upper(var.environment)} dataset"
  description = "Operational and historical SmartVenue analytics dataset"
  location    = var.location
  labels      = local.labels
}

resource "google_bigquery_table" "events_raw" {
  dataset_id = google_bigquery_dataset.smartvenue.dataset_id
  table_id   = "events_raw"
  labels     = local.labels
  schema     = file("${path.module}/../bigquery/schemas/events_raw.json")
}

resource "google_bigquery_table" "gate_metrics_realtime" {
  dataset_id = google_bigquery_dataset.smartvenue.dataset_id
  table_id   = "gate_metrics_realtime"
  labels     = local.labels
  schema     = file("${path.module}/../bigquery/schemas/gate_metrics_realtime.json")
}

resource "google_bigquery_table" "concession_metrics_realtime" {
  dataset_id = google_bigquery_dataset.smartvenue.dataset_id
  table_id   = "concession_metrics_realtime"
  labels     = local.labels
  schema     = file("${path.module}/../bigquery/schemas/concession_metrics_realtime.json")
}

resource "google_bigquery_table" "incidents" {
  dataset_id = google_bigquery_dataset.smartvenue.dataset_id
  table_id   = "incidents"
  labels     = local.labels
  schema     = file("${path.module}/../bigquery/schemas/incidents.json")
}

resource "google_secret_manager_secret" "jwt_public_key" {
  secret_id = "${local.prefix}-jwt-public-key"

  replication {
    auto {}
  }

  labels = local.labels
}

resource "google_secret_manager_secret" "app_config" {
  secret_id = "${local.prefix}-app-config"

  replication {
    auto {}
  }

  labels = local.labels
}

resource "google_service_account" "backend_sa" {
  account_id   = "${local.prefix}-backend-sa"
  display_name = "SmartVenue backend service account (${var.environment})"
}

resource "google_service_account" "frontend_sa" {
  account_id   = "${local.prefix}-frontend-sa"
  display_name = "SmartVenue frontend service account (${var.environment})"
}

resource "google_service_account" "processor_sa" {
  account_id   = "${local.prefix}-processor-sa"
  display_name = "SmartVenue event processor service account (${var.environment})"
}

resource "google_service_account" "alert_sa" {
  account_id   = "${local.prefix}-alert-sa"
  display_name = "SmartVenue alert engine service account (${var.environment})"
}

resource "google_project_iam_member" "backend_pubsub_publisher" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.backend_sa.email}"
}

resource "google_project_iam_member" "backend_firestore_user" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.backend_sa.email}"
}

resource "google_project_iam_member" "backend_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.backend_sa.email}"
}

resource "google_project_iam_member" "processor_firestore_user" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.processor_sa.email}"
}

resource "google_project_iam_member" "processor_bigquery_editor" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.processor_sa.email}"
}

resource "google_project_iam_member" "alert_firestore_user" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.alert_sa.email}"
}

resource "google_project_iam_member" "alert_pubsub_publisher" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.alert_sa.email}"
}

resource "google_cloud_run_v2_service" "backend" {
  name     = "${local.prefix}-backend"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = google_service_account.backend_sa.email

    scaling {
      min_instance_count = var.environment == "prod" ? 2 : 0
      max_instance_count = var.environment == "prod" ? 100 : 25
    }

    containers {
      image = var.backend_image

      env {
        name  = "INGEST_TOPIC"
        value = google_pubsub_topic.events_raw.name
      }

      env {
        name  = "GCP_PROJECT_ID"
        value = var.project_id
      }

      ports {
        container_port = 8080
      }
    }
  }
}

resource "google_cloud_run_v2_service" "frontend" {
  name     = "${local.prefix}-frontend"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = google_service_account.frontend_sa.email

    scaling {
      min_instance_count = var.environment == "prod" ? 1 : 0
      max_instance_count = var.environment == "prod" ? 60 : 20
    }

    containers {
      image = var.frontend_image

      env {
        name  = "BACKEND_URL"
        value = google_cloud_run_v2_service.backend.uri
      }

      ports {
        container_port = 8080
      }
    }
  }
}
