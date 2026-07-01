# Two separate service accounts: one for Cloud Build (deploy-time), one for the
# Cloud Run service itself (runtime). Never reuse the build SA as the runtime SA.

resource "google_service_account" "cloud_build" {
  account_id   = "cloud-build-deployer"
  display_name = "Cloud Build deployer"

  depends_on = [google_project_service.apis]
}

resource "google_service_account" "cloud_run_runtime" {
  account_id   = "cloud-run-runtime"
  display_name = "Cloud Run runtime"

  depends_on = [google_project_service.apis]
}

locals {
  cloud_build_roles = toset([
    "roles/run.admin",
    "roles/artifactregistry.writer",
    "roles/iam.serviceAccountUser",
    "roles/secretmanager.secretAccessor",
  ])
}

resource "google_project_iam_member" "cloud_build_roles" {
  for_each = local.cloud_build_roles

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.cloud_build.email}"
}

# Runtime SA only needs to read secrets at startup (least privilege).
resource "google_project_iam_member" "cloud_run_runtime_secret_access" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.cloud_run_runtime.email}"
}
