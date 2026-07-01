variable "project_id" {
  description = "GCP project ID"
  type        = string
  default     = "helical-lantern-501117-g8"
}

variable "region" {
  description = "GCP region used for all resources"
  type        = string
  default     = "us-central1"
}

variable "service_name" {
  description = "Name used for the Cloud Run service and as the base image name"
  type        = string
  default     = "trm-exercise"
}

variable "artifact_repo_id" {
  description = "Artifact Registry Docker repository ID"
  type        = string
  default     = "trm-exercise"
}

variable "github_owner" {
  description = "GitHub org/user that owns the source repo"
  type        = string
  default     = "mccannical"
}

variable "github_repo" {
  description = "GitHub repo name (source of the app + cloudbuild.yaml)"
  type        = string
  default     = "trm-exercise"
}
