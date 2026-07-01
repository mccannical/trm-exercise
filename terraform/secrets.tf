# Placeholder secret container only — no version with real data is created here.
# Real secret values get populated out-of-band (gcloud/console) once the app's
# actual secrets are known; Terraform manages the container, not the payload.

resource "google_secret_manager_secret" "app_secret" {
  project   = var.project_id
  secret_id = "app-secret"

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}
