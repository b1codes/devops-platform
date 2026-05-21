# Contributing

Thank you for your interest in contributing to devops-platform. This document covers everything you need to know before opening a pull request.

---

## Branch model

This repository uses **trunk-based development**:

- `main` is always in a releasable state.
- Create a short-lived feature branch off `main` for every change (`feat/`, `fix/`, `docs/`, `chore/` prefixes are encouraged).
- Open a pull request against `main`. At least one review approval is required before merge.
- Delete the feature branch after merge.

Direct commits to `main` are not permitted.

---

## Commit conventions

All commits must follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/):

```
<type>(<scope>): <short description>

[optional body]

[optional footer(s)]
```

Allowed types:

| Type     | When to use                                         |
|----------|-----------------------------------------------------|
| `feat`   | A new module, workflow, or user-facing capability.  |
| `fix`    | A bug fix.                                          |
| `docs`   | Documentation only changes.                         |
| `chore`  | Maintenance: dependency bumps, tooling, config.     |
| `ci`     | Changes to CI/CD pipelines or GitHub Actions.       |
| `refactor` | Code change that neither fixes a bug nor adds a feature. |
| `test`   | Adding or correcting tests.                         |

Examples:

```
feat(modules): add b1c-secure-bucket module with KMS option
fix(workflows): correct CloudFront invalidation path in aws-static-site
docs(prerequisites): add DynamoDB table creation command
chore: bump tflint to v0.50.0
```

---

## Non-negotiable rules

These rules are derived from SPEC §5 and are enforced in code review.

### 1. Never hardcode

All values — account IDs, ARNs, bucket names, region strings, secrets — must be passed as Terraform variables or workflow inputs/secrets. Hard-coded literals are a blocking review comment.

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

### 2. Pin GitHub Actions to commit SHAs

Every `uses:` reference must point to a full commit SHA, with the human-readable tag as a trailing comment. This prevents supply-chain attacks from tag mutation.

```yaml
# Wrong
- uses: actions/checkout@v4

# Right
- uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
```

When updating an action version, update both the SHA and the comment.

---

## Module documentation requirement

Every new or modified Terraform module under `modules/` must include:

1. **`README.md`** — inputs table, outputs table, and a minimal usage example. The preferred tool is [`terraform-docs`](https://terraform-docs.io/), which can generate this automatically.
2. **`examples/basic/main.tf`** — a runnable, self-contained example that instantiates the module with the minimum required variables. No placeholder values — use locals or variables so it can actually be applied against a real account.

Pull requests that add or modify a module without updating the README and basic example will not be merged.

---

## Local development

Before pushing or opening a pull request, run the following checks locally. CI enforces the same checks; failing locally is faster than failing in CI.

```bash
# Format all Terraform files (rewrites in place)
terraform fmt -recursive

# Validate the module you changed (run from within the module directory)
cd modules/<module-name>
terraform init -backend=false
terraform validate

# Lint all Terraform files
tflint --recursive

# Run all pre-commit hooks (requires pre-commit installed)
pre-commit run --all-files
```

Install prerequisites:

```bash
# macOS (Homebrew)
brew install terraform tflint pre-commit
```

See `.tool-versions` for the exact version of Terraform expected in this repository.

---

## Versioning policy (SemVer)

This repository follows [Semantic Versioning](https://semver.org/) for module and workflow releases:

| Change type                                          | Version bump |
|------------------------------------------------------|--------------|
| Breaking change to a module's input variables (rename, remove, type change) or a reusable workflow's required inputs | **MAJOR** (`v1.0.0 → v2.0.0`) |
| New module, new optional input, new non-breaking output | **MINOR** (`v0.1.0 → v0.2.0`) |
| Bug fix, documentation update, dependency bump with no interface change | **PATCH** (`v0.1.0 → v0.1.1`) |

During the `v0.x` series, MINOR bumps may contain breaking changes with adequate changelog notice.

Tags are cut from `main` by a maintainer after the relevant pull request merges. Do not tag pre-release commits on feature branches.

---

## Questions

Open a [GitHub Discussion](https://github.com/B1Codes/devops-platform/discussions) for questions, design proposals, or feedback before investing time in a large pull request.
