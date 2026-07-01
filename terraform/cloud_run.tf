# Minimal Cloud Run shell pointing at a placeholder image so `terraform apply`
# succeeds before any real app image exists. Cloud Build overwrites the
# revision with the real image on first successful CI run (see cloudbuild.yaml).
resource "google_cloud_run_v2_service" "app" {
  name     = var.service_name
  location = var.region
  project  = var.project_id

  template {
    service_account = google_service_account.cloud_run_runtime.email

    scaling {
      min_instance_count = 0
    }

    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello"

      env {
        name = "APP_SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.app_secret.secret_id
            version = "latest"
          }
        }
      }
    }
  }

  # Cloud Build deploys new revisions directly via `gcloud run deploy` after
  # the first CI run. Without this, a later `terraform apply` would stomp the
  # CI-deployed image back to the placeholder above.
  lifecycle {
    ignore_changes = [template[0].containers[0].image]
  }

  depends_on = [google_project_service.apis]
}

# Public, unauthenticated access — fastest path for the demo, NOT
# production-safe. Known gap; see plan.md "Path to production" for the
# planned fix (IAM-invoker + load balancer + IAP, or Cloud Run built-in auth).
resource "google_cloud_run_v2_service_iam_member" "public_invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.app.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

output "cloud_run_url" {
  value = google_cloud_run_v2_service.app.uri
}
