# devops-platform conventions

Four non-negotiables. The first two are enforced by pre-commit hooks; all four are blocking in code review. Fix the root cause — do not bypass hooks.

## 1. No `backend {}` block under `modules/`

Modules are stateless primitives. State ownership lives only with consumers. Enforced by the `no-backend-in-modules` pygrep hook in `.pre-commit-config.yaml`:

```yaml
- id: no-backend-in-modules
  entry: '^\s*backend\s'
  files: '^modules/.*\.tf$'
  args: [--negate]  # fail when the pattern IS found
```

**Failing pattern** (the hook blocks the commit):

```hcl
# modules/<anything>/main.tf
terraform {
  backend "s3" { bucket = "foo" }
}
```

**Passing pattern**: nothing — modules contain no `backend {}` at all. The consumer's root configuration is the only place state ownership lives.

## 2. GitHub Actions `uses:` pinned to a full 40-character commit SHA

In `.github/workflows/`, every `uses:` reference must be a 40-char SHA with the human-readable tag in a trailing comment:

```yaml
uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7
```

Enforced by `workflows-pinned-to-sha` (entry: `'^\s*-?\s*uses:\s*\S+@(?![a-f0-9]{40}($|\s|#))'`). Caller workflows under `examples/*/.github/workflows/` are intentionally exempt.

**SHA-bump procedure** — update both, drift defeats the protection:

```bash
# Look up the SHA for a new tag.
gh api repos/<owner>/<repo>/git/refs/tags/<tag> --jq '.object.sha'

# Edit the workflow: replace BOTH the @<sha> AND the trailing comment in one diff.
# Verify the new SHA still passes the hook:
pre-commit run workflows-pinned-to-sha --all-files
```

## 3. No hardcoded values

Account IDs, ARNs, bucket names, region strings, secrets. Everything flows in as a Terraform variable, workflow input, or OIDC-derived credential. See `CONTRIBUTING.md` §1.

```hcl
# Wrong
resource "aws_s3_bucket" "this" {
  bucket = "my-company-prod-data"
}

# Right
resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name
}
```

## 4. OIDC only

No workflow accepts `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`. AWS auth always flows through short-lived OIDC tokens via `aws-actions/configure-aws-credentials`. Minimum correct shape for a caller workflow:

```yaml
jobs:
  deploy:
    permissions:
      id-token: write          # required for OIDC token minting
      contents: read
    steps:
      - uses: aws-actions/configure-aws-credentials@<pinned-sha>  # see rule 2
        with:
          role-to-assume: ${{ secrets.AWS_DEPLOY_ROLE_ARN }}
          aws-region: us-east-1
```

Without `id-token: write`, role assumption fails with an opaque error.

## Module documentation contract

Every module under `modules/` ships with `README.md` *and* `examples/basic/main.tf`. PRs that add or modify a module without both will not merge.
