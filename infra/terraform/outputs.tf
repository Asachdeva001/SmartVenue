output "events_topic_name" {
  value       = google_pubsub_topic.events_raw.name
  description = "Pub/Sub topic receiving raw SmartVenue events"
}

output "alerts_topic_name" {
  value       = google_pubsub_topic.alerts.name
  description = "Pub/Sub topic containing generated alerts"
}

output "backend_service_url" {
  value       = google_cloud_run_v2_service.backend.uri
  description = "Backend Cloud Run URL"
}

output "frontend_service_url" {
  value       = google_cloud_run_v2_service.frontend.uri
  description = "Frontend Cloud Run URL"
}

output "bigquery_dataset" {
  value       = google_bigquery_dataset.smartvenue.dataset_id
  description = "BigQuery dataset ID for SmartVenue analytics"
}
