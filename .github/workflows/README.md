# Reusable Workflow Reference

All workflows in this directory are designed to be called by consumer repos via
`workflow_call`. They require no self-hosted runners and authenticate to AWS via
OIDC — no static credentials required.

> **Pinning:** always pin to a release tag (`@v0.1.0`) or a commit SHA when
> calling these workflows from external repos to ensure deterministic behaviour.

---

## `aws-lambda-deploy.yml`

**Purpose:** Packages a Python or Node Lambda function directory into a ZIP
archive and deploys it to an existing AWS Lambda function via OIDC-authenticated
credentials.

**Inputs:**

| Name | Required | Type | Default | Description |
|---|---|---|---|---|
| `function_name` | yes | string | — | Name of the Lambda function to update |
| `aws_region` | yes | string | — | AWS region (e.g. `us-east-1`) |
| `runtime` | yes | string | — | `python` or `node` |
| `source_dir` | yes | string | — | Path to the Lambda source directory |
| `runtime_version` | no | string | `3.12` / `20` | Python or Node version to install |
| `dependency_install_command` | no | string | `""` | Command run inside `source_dir` before zipping (e.g. `pip install -r requirements.txt -t .`) |

**Secrets:**

| Name | Required | Description |
|---|---|---|
| `role_to_assume` | yes | ARN of the IAM role to assume via OIDC |

**Caller example:**

```yaml
on:
  push:
    branches: [main]

jobs:
  deploy:
    uses: B1Codes/devops-platform/.github/workflows/aws-lambda-deploy.yml@v0.1.0
    with:
      function_name: my-app-prod
      aws_region: us-east-1
      runtime: python
      source_dir: src/
      dependency_install_command: pip install -r requirements.txt -t .
    secrets:
      role_to_assume: ${{ secrets.AWS_DEPLOY_ROLE_ARN }}
```

---

## `aws-static-site.yml`

**Purpose:** Builds a static site (React, Vue, plain HTML) with Node.js, syncs
the output to an S3 bucket with `--delete`, and invalidates a CloudFront
distribution.

**Inputs:**

| Name | Required | Type | Default | Description |
|---|---|---|---|---|
| `build_command` | yes | string | — | Shell command to build the site (e.g. `npm run build`) |
| `build_output_dir` | yes | string | — | Directory containing the built site to sync |
| `bucket_name` | yes | string | — | S3 bucket name |
| `cloudfront_distribution_id` | yes | string | — | CloudFront distribution ID |
| `aws_region` | yes | string | — | AWS region |
| `node_version` | no | string | `"20"` | Node.js version |
| `wait_for_invalidation` | no | boolean | `false` | Wait for CloudFront invalidation to reach `Completed` (~2-5 min) |

**Secrets:**

| Name | Required | Description |
|---|---|---|
| `role_to_assume` | yes | ARN of the IAM role to assume via OIDC |

**Caller example:**

```yaml
on:
  push:
    branches: [main]

jobs:
  deploy:
    uses: B1Codes/devops-platform/.github/workflows/aws-static-site.yml@v0.1.0
    with:
      build_command: npm run build
      build_output_dir: dist/
      bucket_name: my-site-prod-assets
      cloudfront_distribution_id: EXXXXXXXXXXXXXXXXX
      aws_region: us-east-1
    secrets:
      role_to_assume: ${{ secrets.AWS_DEPLOY_ROLE_ARN }}
```

---

## `terraform-plan-cost.yml`

**Purpose:** Runs `terraform init/validate/plan` against a given directory and
posts an Infracost cost estimate as a PR comment. Skips silently on fork PRs
(forks cannot access secrets — see the fork safety note in the workflow file).

**Inputs:**

| Name | Required | Type | Default | Description |
|---|---|---|---|---|
| `working_directory` | yes | string | — | Path to the Terraform root module |
| `aws_region` | yes | string | — | AWS region for provider authentication |
| `tf_version` | no | string | `"1.9.5"` | Terraform version to install |
| `infracost_breakdown_path` | no | string | `"./infracost-base.json"` | Output path for the Infracost JSON breakdown |

**Secrets:**

| Name | Required | Description |
|---|---|---|
| `role_to_assume` | yes | ARN of the IAM role to assume via OIDC |
| `infracost_api_key` | yes | Infracost API key (obtain at https://infracost.io) |

**Caller example:**

```yaml
on:
  pull_request:

jobs:
  plan:
    uses: B1Codes/devops-platform/.github/workflows/terraform-plan-cost.yml@v0.1.0
    with:
      working_directory: infra/
      aws_region: us-east-1
    secrets:
      role_to_assume: ${{ secrets.AWS_PLAN_ROLE_ARN }}
      infracost_api_key: ${{ secrets.INFRACOST_API_KEY }}
```

---

## Prerequisites

Before using any of these workflows in a consumer repo you need:

1. An OIDC identity provider for `token.actions.githubusercontent.com` in your
   AWS account.
2. An IAM role trusted to your GitHub org/repo with the permissions needed for
   the workflow.
3. For `terraform-plan-cost.yml`: an Infracost account and API key stored as a
   repository secret named `INFRACOST_API_KEY`.

See [`docs/PREREQUISITES.md`](../../docs/PREREQUISITES.md) for full setup
instructions.
