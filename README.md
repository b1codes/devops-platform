# devops-platform

Open-source AWS + GCP deployment engine: reusable GitHub Actions workflows and Terraform modules.

---

## Why this exists

Most teams reinvent the same deployment scaffolding for every project — OIDC wiring, S3 state buckets, Lambda packaging steps. This repository codifies a "Golden Path": a single, opinionated set of Terraform modules and reusable GitHub Actions workflows that any project can call instead of building from scratch. It fills the gap between "I have a cloud account" and "I have a working, cost-tracked, secure CI/CD pipeline," on AWS or GCP, without locking consumers into a proprietary platform.

---

## Architecture

```mermaid
flowchart LR
    subgraph consumer["Consumer Repository"]
        caller["caller workflow\n(.github/workflows/)"]
    end

    subgraph engine["devops-platform (this repo)"]
        direction TB
        rw["Reusable Workflows\n(aws-lambda-deploy.yml, aws-static-site.yml,\ngcp-cloudrun-deploy.yml, gcp-static-site.yml,\nterraform-plan-cost.yml)"]
        tfaws["modules/aws/\n(b1c-secure-bucket\nb1c-serverless-api\nb1c-aurora-cluster)"]
        tfgcp["modules/gcp/\n(b1c-secure-bucket\nb1c-serverless-api\nb1c-relational-db)"]
    end

    subgraph aws["AWS"]
        oidc["OIDC Provider\n(token.actions.githubusercontent.com)"]
        role["IAM Role\n(GitHubActionsRole)"]
        services["Lambda / S3+CloudFront\nAurora Serverless"]
        state["S3 State Bucket\n+ DynamoDB Lock"]
    end

    subgraph gcp["GCP"]
        wif["Workload Identity Federation\n(GitHub OIDC → GCP)"]
        services_gcp["Cloud Run / GCS+Cloud CDN\nCloud SQL"]
    end

    caller -->|"workflow_call"| rw
    rw -->|"assume role via OIDC"| oidc
    oidc --> role
    role --> services
    rw -->|"authenticate via WIF"| wif
    wif --> services_gcp
    tfaws -->|"terraform init/plan/apply"| state
    tfaws --> services
    tfgcp -->|"terraform init/plan/apply"| services_gcp
```

---

## What's inside

- **`modules/`** — Reusable Terraform building blocks, split by provider:
  - `modules/aws/` — `b1c-secure-bucket` (S3), `b1c-serverless-api` (Lambda + API Gateway v2), `b1c-aurora-cluster` (Aurora Serverless v2).
  - `modules/gcp/` — `b1c-secure-bucket` (GCS), `b1c-serverless-api` (Cloud Run), `b1c-relational-db` (Cloud SQL).

- **`.github/workflows/`** — Reusable GitHub Actions workflows (called via `workflow_call`):
  - `aws-lambda-deploy.yml` / `gcp-cloudrun-deploy.yml` — packages source and deploys to Lambda / Cloud Run.
  - `aws-static-site.yml` / `gcp-static-site.yml` — builds a frontend, syncs to S3+CloudFront / GCS+Cloud CDN.
  - `terraform-plan-cost.yml` — runs `terraform plan` and posts an Infracost diff comment on pull requests (provider-agnostic).

- **`examples/`** — Runnable end-to-end demos showing how to wire the modules and caller workflows together.

---

## Quickstart for consumers

Full walkthrough is in [`docs/CONSUMER-QUICKSTART.md`](docs/CONSUMER-QUICKSTART.md) (being authored in parallel — see [Phase 3 of the roadmap](docs/PLAN.md)). The short version:

1. **Satisfy prerequisites** — see [`docs/PREREQUISITES.md`](docs/PREREQUISITES.md). You need an AWS account, an OIDC identity provider, a trusted IAM role, and a Terraform state backend.
2. **Call a reusable workflow** from your repository's `.github/workflows/` directory using `workflow_call` syntax, pointing at `B1Codes/devops-platform/.github/workflows/<workflow>.yml@main`.
3. **Reference a Terraform module** in your `main.tf` using the GitHub module source: `github.com/B1Codes/devops-platform//modules/<module-name>?ref=<tag>`.
4. **Open a pull request** — the `terraform-plan-cost.yml` workflow will comment a plan and cost diff automatically.

---

## Prerequisites

The short list:

- AWS account with billing enabled.
- OIDC identity provider for `token.actions.githubusercontent.com` configured in the target AWS account.
- IAM role trusted to your GitHub org/repo via the OIDC provider.
- S3 bucket and DynamoDB table for Terraform remote state.

See [`docs/PREREQUISITES.md`](docs/PREREQUISITES.md) for full setup instructions including copy-paste AWS CLI commands.

> **Note:** B1Codes' internal implementation of all of the above lives in the private `llc-infra-core` repository (B1Codes' internal Brain layer), which is not publicly available. Any functionally-equivalent setup works.

---

## License

MIT — see [`LICENSE`](LICENSE).
