# devops-platform footguns

Behaviours that surprise contributors and consumers. Each one has bitten before; do not "fix" them without understanding why they are this way.

## `terraform-docs` runs in `inject` mode

`pre-commit` rewrites content between `<!-- BEGIN_TF_DOCS -->` and `<!-- END_TF_DOCS -->` markers in every module's `README.md`. Hand-edits *inside* those markers will be overwritten. Put narrative *outside* the markers.

## `b1c-serverless-api` is intentionally auth-free

From `CHANGELOG.md [Unreleased]`:

> Lambda function wired to an HTTP API Gateway v2 with a `$default` route, IAM execution role, CloudWatch log group with configurable retention, and optional extra IAM policy attachments. **Auth-free by design; consumers layer authorization in a wrapper module.**

Do not add a built-in auth mode here. Wrap it in a consumer-side module (Auth0 JWT authorizer, Cognito user pool, any JWKS-compatible IdP).

## `terraform-plan-cost.yml` is PR-only by design

It does not run on `push: main`. Deliberate security boundary so the Infracost API key never flows through a push event or fork-PR. Do not add a `push:` trigger.

## Lambda fixture ZIPs are allow-listed in `.gitignore`

The relevant block in `.gitignore`:

```gitignore
# Generated Lambda zip artifacts (archive_file data source in b1c-serverless-api)
.archive/
*.zip
!modules/**/fixtures/*.zip
```

New module test fixtures must go under `fixtures/` or the allow-list must be updated explicitly.

## `.terraform.lock.hcl` IS committed

From `.gitignore`:

```gitignore
# NOTE: Do NOT ignore .terraform.lock.hcl
# The provider lock file must be committed to version control so that all
# contributors and CI runs use exactly the same provider versions.
```

Don't "clean up" by ignoring it — the provider lock pins transitive versions across all developers and CI runs.
