# GCP 2nd-gen Cloud Build GitHub integration: connection -> repository -> trigger.
#
# CAVEAT (manual step required): a Cloud Build v2 GitHub connection needs a one-time
# interactive GitHub App installation/OAuth grant that Terraform cannot complete
# headlessly. The usual flow is:
#   1. `gcloud builds connections create github <name> --region=<region>` (opens a
#      browser OAuth flow), or complete it via the GCP Console under
#      Cloud Build > Repositories > Create host connection.
#   2. That flow populates the GitHub App installation token; a Secret Manager
#      secret holding an OAuth/PAT token (defined below) is still required as the
#      `authorizer_credential` for the connection resource itself.
# Until that manual step is done and the real token secret version is set, `terraform
# apply` on this file will fail or leave the connection in a PENDING_USER_OAUTH state.
# This is a known chicken-and-egg with 2nd-gen Cloud Build + Terraform and is expected
# for a first-time setup — not a bug in this config.

resource "google_secret_manager_secret" "github_token" {
  secret_id = "github-token"

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

# PLACEHOLDER value. Must be replaced with a real GitHub PAT / GitHub App
# installation token before the connection below can authenticate, e.g.:
#   gcloud secrets versions add github-token --data-file=- <<< "$REAL_TOKEN"
# Terraform intentionally does not manage the real secret value (never commit it).
resource "google_secret_manager_secret_version" "github_token_placeholder" {
  secret      = google_secret_manager_secret.github_token.id
  secret_data = "REPLACE_ME_BEFORE_APPLY"

  lifecycle {
    ignore_changes = [secret_data]
  }
}

resource "google_secret_manager_secret_iam_member" "github_token_accessor" {
  secret_id = google_secret_manager_secret.github_token.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"
}

data "google_project" "current" {
  project_id = var.project_id
}

resource "google_cloudbuildv2_connection" "github" {
  provider = google-beta
  location = var.region
  name     = "${var.github_repo}-connection"

  github_config {
    app_installation_id = null # populated by the manual OAuth step above
    authorizer_credential {
      oauth_token_secret_version = google_secret_manager_secret_version.github_token_placeholder.id
    }
  }

  depends_on = [
    google_project_service.apis,
    google_secret_manager_secret_iam_member.github_token_accessor,
  ]
}

resource "google_cloudbuildv2_repository" "repo" {
  provider          = google-beta
  location          = var.region
  name              = var.github_repo
  parent_connection = google_cloudbuildv2_connection.github.name
  remote_uri        = "https://github.com/${var.github_owner}/${var.github_repo}.git"
}

resource "google_cloudbuild_trigger" "main" {
  location        = var.region
  name            = "${var.service_name}-main-push"
  service_account = google_service_account.cloud_build.id

  repository_event_config {
    repository = google_cloudbuildv2_repository.repo.id
    push {
      branch = "^main$"
    }
  }

  filename = "cloudbuild.yaml"

  substitutions = {
    _SERVICE_NAME = var.service_name
    _REGION       = var.region
  }

  # Required by GCP when a custom service_account is set on the trigger:
  # default (legacy) logging is incompatible with a non-default build SA.
  options {
    logging = "CLOUD_LOGGING_ONLY"
  }

  depends_on = [google_project_service.apis]
}
