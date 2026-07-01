# CI/CD Pipeline Plan — trm-exercise

## Objective

Containerize and deploy a service on GCP with a working CI/CD pipeline, provisioned via Terraform, as an MVP-quality demonstration of operational judgment, speed, and responsible AI leverage — not a fully productionized system.

## Requirements (from exercise)

- Build a Docker image
- Push to a container registry
- Deploy on AWS or GCP
- Use Terraform to provision the infrastructure
- Deploy a live change as part of success criteria
- Secrets stored in a secrets manager

## Decisions made

- **Cloud provider:** GCP, project `helical-lantern-501117-g8`
- **Source repo:** `https://github.com/mccannical/trm-exercise`
- **CI/CD:** Cloud Build, triggered on push to `main`
- **Registry:** Google Artifact Registry
- **Compute:** Cloud Run (container)
- **Secrets:** Google Secret Manager
- **Initial app:** `docker/awesome-compose` FastAPI example (placeholder, to be replaced later)

## Architecture overview

```
GitHub (mccannical/trm-exercise, main branch)
    │  push
    ▼
Cloud Build Trigger (GCP)
    │  builds Docker image
    ▼
Artifact Registry (Docker repo)
    │  Cloud Build deploys new revision
    ▼
Cloud Run service (public HTTPS endpoint)
    │  reads
    ▼
Secret Manager (app secrets, injected as env vars)
```

Terraform provisions everything except the actual application code push (Artifact Registry repo, Cloud Run service shell, Cloud Build trigger, service accounts/IAM, Secret Manager secrets, and the GitHub connection).

## Build order (each step independently verifiable)

1. **GCP project bootstrap**
   - Enable required APIs: Cloud Build, Artifact Registry, Cloud Run, Secret Manager, IAM.
   - Pick one region (e.g. `us-central1`) and use it everywhere for latency/cost consistency.

2. **Terraform: foundational infra**
   - Artifact Registry Docker repo (e.g. `trm-exercise`).
   - Cloud Build service account with least-privilege roles: `roles/run.admin`, `roles/artifactregistry.writer`, `roles/iam.serviceAccountUser`, `roles/secretmanager.secretAccessor` (only if needed at build time).
   - Separate runtime service account for the Cloud Run service itself (don't reuse the build SA).
   - Secret Manager secret placeholder(s) — created empty/dummy now, populated once app secrets are known.

3. **Terraform: GitHub connection + Cloud Build trigger**
   - GCP 2nd-gen Cloud Build GitHub connection (Developer Connect / Cloud Build repository resource) pointing at `mccannical/trm-exercise`.
   - Trigger: on push to `main`, run `cloudbuild.yaml` from repo root.

4. **Terraform: Cloud Run service shell**
   - Minimal service pointing at a placeholder image (e.g. `us-docker.pkg.dev/cloudrun/container/hello`) so `terraform apply` succeeds before any app image exists — Cloud Build overwrites the revision on first successful build. Avoids a chicken-and-egg problem between Terraform and CI.
   - `min_instances = 0` (scale to zero), unauthenticated invocations allowed for the demo — flagged as a tradeoff.

5. **Repo: `cloudbuild.yaml`**
   - Step 1: `docker build` the FastAPI app, tag with both `:latest` and `:$SHORT_SHA` (immutable tag for rollback/audit, `latest` for convenience).
   - Step 2: `docker push` both tags to Artifact Registry.
   - Step 3: `gcloud run deploy` the new image to the existing Cloud Run service.
   - No secrets baked into the image — Cloud Run pulls them from Secret Manager at runtime via `--set-secrets`.

6. **Repo: application code**
   - Copy in the `docker/awesome-compose` FastAPI example as-is for now (replaced later).
   - Add a standalone `Dockerfile` if needed — Cloud Build can't build directly from a compose file.

7. **First deploy**
   - `terraform apply` → provisions everything except a real app image.
   - Push to `main` → Cloud Build fires → image built → pushed → Cloud Run updated.
   - Verify: hit the Cloud Run URL, confirm FastAPI responds.

## Key tradeoffs

- **Cloud Build vs GitHub Actions:** Cloud Build keeps everything GCP-native and Terraform-manageable in one provider; GitHub Actions would need Workload Identity Federation for keyless GCP auth — more setup, more portable. Cloud Build is the faster path for a weekend MVP.
- **Placeholder image bootstrap:** avoids a circular dependency (Terraform needs an image to deploy; the image doesn't exist until CI runs), at the cost of one slightly awkward first-apply.
- **Public unauthenticated Cloud Run:** fastest to demo, not production-safe. Known gap with a stated path to fix (IAM-invoker + load balancer + IAP, or Cloud Run's built-in auth).
- **`latest` + SHA tagging:** gives cheap rollback capability without a full release process.
- **Secrets:** Secret Manager + `--set-secrets` at deploy time; never baked into the image or committed as plaintext in Terraform state where avoidable (`sensitive = true`, values passed via env vars, not hardcoded).

## Path to production (not built now, but scoped)

- Move Cloud Run to authenticated-only access behind a load balancer / IAP.
- Split Terraform state per environment (dev/staging/prod) with remote state backend (GCS bucket + locking).
- Add automated tests as a Cloud Build step before deploy, with a manual approval gate for prod.
- Add monitoring/alerting (Cloud Monitoring, uptime checks, error reporting) and structured logging.
- Rotate and audit Secret Manager access; consider per-environment secrets.
- Blue/green or canary rollout via Cloud Run traffic splitting instead of full-traffic redeploy.
