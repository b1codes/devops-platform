# examples/gcp-static-site

An end-to-end example showing `modules/gcp/b1c-secure-bucket` composed with a GCS backend bucket, Cloud CDN, and an external HTTPS Load Balancer, deployed via `gcp-static-site.yml`. Mirrors [`examples/static-site`](../static-site/) for the GCP provider — GCS + Cloud CDN + Load Balancer is the architectural equivalent of S3 + CloudFront + OAC.

## What's here

- `main.tf` — Terraform root: `gcp/b1c-secure-bucket` + backend bucket + URL map + managed SSL cert + HTTPS proxy + global forwarding rule.
- `site/index.html` — the static content to deploy.
- `.github/workflows/deploy.yml` — caller workflow using `gcp-static-site.yml`.

## Try it

1. `terraform init && terraform apply -var project_id=<your-gcp-project> -var domain_name=<your-domain>` — provisions the bucket, CDN, and load balancer.
2. Point your domain's DNS A record at the `load_balancer_ip` output. Managed SSL certificate provisioning can take up to an hour after DNS propagates.
3. Fill in the real `bucket_name` Terraform output into `.github/workflows/deploy.yml`'s `bucket_name` input (Terraform appends a random suffix, so this is not knowable in advance).
4. Set up Workload Identity Federation and add `GCP_WIF_PROVIDER` / `GCP_DEPLOY_SERVICE_ACCOUNT` as repository secrets — see `docs/PREREQUISITES.md`.
5. Push a change under `site/` to `main` — the caller workflow syncs it to GCS and invalidates the CDN cache.

## License

MIT
