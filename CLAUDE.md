# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository context

**`devops-platform`** is the public, MIT-licensed engine in B1Codes' public/private AWS infrastructure pair. It exposes two kinds of primitives that consumers reference by Git URL:

- **Generic Terraform modules** under `modules/` (`b1c-secure-bucket`, `b1c-serverless-api`, `b1c-aurora-cluster`) consumed via `source = "github.com/B1Codes/devops-platform//modules/<name>?ref=<tag>"`.
- **Reusable `workflow_call` GitHub Actions** under `.github/workflows/` (`aws-lambda-deploy.yml`, `aws-static-site.yml`, `terraform-plan-cost.yml`) consumed via `uses: B1Codes/devops-platform/.github/workflows/<name>.yml@<sha>`.

A private B1Codes consumer (`llc-infra-core`, B1Codes' internal Brain layer; not publicly available — see the pointer in `README.md`) builds on top of these primitives. This repo deliberately knows nothing about that consumer — keeping it generic for *all* external consumers is the value proposition.

**Status: pre-release.** `v0.1.0` has not been tagged yet. The full `[Unreleased]` section of `CHANGELOG.md` is the current truth; consult `RELEASE-CHECKLIST.md` before tagging.

Authoritative docs already in the repo (read them; don't restate them in CLAUDE.md or in code comments):

- `README.md` — mission, quickstart, prerequisites summary
- `docs/ARCHITECTURE.md` — two-layer design + Mermaid diagrams
- `docs/CONSUMER-QUICKSTART.md` — end-to-end first-deploy walkthrough
- `docs/PREREQUISITES.md` — external dependencies (OIDC IdP, IAM role, state bucket)
- `CONTRIBUTING.md` — branch model, Conventional Commits, SemVer, local dev setup
- `RELEASE-CHECKLIST.md` — manual verification before cutting a tag

## Common commands

Tool versions are pinned in `.tool-versions`: **Terraform 1.9.5, Python 3.12.5, Node 20.17.0**.

```bash
pre-commit install                                # one-time
pre-commit run --all-files                        # all hooks against everything

terraform fmt -recursive                          # rewrites .tf in place
tflint --recursive                                # lints all .tf files

# Validate a single module:
cd modules/b1c-serverless-api
terraform init -backend=false
terraform validate

# Regenerate a module README (terraform-docs runs in inject mode — see footguns):
terraform-docs markdown table --config .terraform-docs.yml modules/b1c-secure-bucket
```

CI (`.github/workflows/ci.yml`) runs `terraform fmt -check`, a `terraform validate` matrix per module, a `tflint` matrix per module, `actionlint`, and markdown-lint. There is no automated test suite — correctness is enforced entirely by lint, validate, and the pre-commit hooks below.

## Non-negotiable conventions

The first two are enforced by pre-commit hooks (commits will fail). All four are blocking in code review. Fix the root cause; do not bypass hooks.

1. **No `backend {}` block under `modules/`** — enforced by the `no-backend-in-modules` pygrep hook. Modules are stateless primitives; state ownership lives only with consumers.

2. **GitHub Actions `uses:` references in `.github/workflows/` must be pinned to a full 40-character commit SHA** — enforced by the `workflows-pinned-to-sha` pygrep hook. The human-readable tag goes in a trailing comment, e.g. `uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7`. When bumping, update both the SHA *and* the comment — drift defeats the protection. Caller workflows under `examples/*/.github/workflows/` are intentionally exempt because they document tag-based consumption.

3. **No hardcoded values** — account IDs, ARNs, bucket names, region strings, secrets. Everything flows in as a Terraform variable, workflow input, or OIDC-derived credential (`CONTRIBUTING.md` §1).

4. **OIDC only.** No workflow accepts `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`. AWS auth always flows through short-lived OIDC tokens via `aws-actions/configure-aws-credentials`.

Module-documentation contract (`CONTRIBUTING.md`): every module under `modules/` ships with a `README.md` *and* an `examples/basic/main.tf`. PRs that add or modify a module without both will not merge.

## Things to watch out for

- **terraform-docs runs in `inject` mode.** It replaces content between `<!-- BEGIN_TF_DOCS -->` and `<!-- END_TF_DOCS -->` markers in each module's README on every pre-commit run. Hand-edits *inside* those markers will be overwritten. Put narrative *outside* the markers.

- **`b1c-serverless-api` is intentionally auth-free** ("consumers layer authorization in a wrapper module" per its README and the CHANGELOG). The module stays generic so consumers can layer the auth provider of their choice (Auth0, Cognito, any JWKS-compatible IdP). Do not add a built-in auth mode here unless the design explicitly opens up.

- **`terraform-plan-cost.yml` is PR-only by design** — it does not run on `push: main`. This is a deliberate security boundary so the Infracost API key never flows through a push event or fork-PR. Do not add a `push:` trigger.

- **Lambda fixture ZIPs are allow-listed in `.gitignore`.** General rule: `.archive/` and `*.zip` are ignored. Exception: `!modules/**/fixtures/*.zip`. New module test fixtures must go under `fixtures/` or the allow-list must be updated explicitly.

- **`.terraform.lock.hcl` IS committed** — the `.gitignore` has an explicit comment about this. Don't "clean up" by ignoring it; the provider lock file pins transitive versions across all developers and CI runs.

- **The markdownlint action SHA is still flagged for verification before release.** `.github/workflows/ci.yml` contains `DavidAnson/markdownlint-cli2-action@05f32210e84442804257b2a6f20b273450ec8265 # v17 — verify SHA before v0.1.0 release`. The `RELEASE-CHECKLIST.md` security section is where this gets checked off.

- **Cross-repo portability discipline.** Keep this repo free of B1Codes-specific identifiers: no account IDs, no `b1codes-*` resource names hardcoded into module bodies, no references to `llc-infra-core` beyond the existing "see the private repo for an example" pointer in the README. `RELEASE-CHECKLIST.md` has the exact `grep` commands the release process uses to verify this.
