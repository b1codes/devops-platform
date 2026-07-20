# examples/gcp-cloudrun-python

An end-to-end example showing `modules/gcp/b1c-serverless-api` provisioning a Cloud Run service, plus a caller workflow (`.github/workflows/deploy.yml`) that redeploys it via `gcp-cloudrun-deploy.yml` on every push to `main`. Mirrors [`examples/lambda-python`](../lambda-python/) for the GCP provider.

## What's here

- `main.tf` / `variables.tf` / `versions.tf` — Terraform root instantiating `modules/gcp/b1c-serverless-api`.
- `src/main.py` — a minimal Flask app (`/` and `/health` routes).
- `Procfile` — tells Cloud Run's buildpacks how to start the app.
- `.github/workflows/deploy.yml` — caller workflow using `gcp-cloudrun-deploy.yml`.

## Try it

1. `terraform init && terraform apply -var project_id=<your-gcp-project>` — provisions the Cloud Run service (initially running Google's public hello-world image).
2. Set up Workload Identity Federation in your GCP project and add `GCP_WIF_PROVIDER` / `GCP_DEPLOY_SERVICE_ACCOUNT` as repository secrets — see `docs/PREREQUISITES.md`.
3. Push a change under `src/` to `main` — the caller workflow redeploys the service from source via Cloud Run buildpacks.

## License

MIT
