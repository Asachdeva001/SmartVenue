variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "Primary deployment region"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment name (dev/stage/prod)"
  type        = string
}

variable "location" {
  description = "BigQuery dataset location"
  type        = string
  default     = "US"
}

variable "backend_image" {
  description = "Container image for backend Cloud Run service"
  type        = string
}

variable "frontend_image" {
  description = "Container image for frontend Cloud Run service"
  type        = string
}
