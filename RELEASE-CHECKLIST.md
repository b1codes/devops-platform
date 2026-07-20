# Release Checklist — v0.1.0

Work through every item before cutting the release tag. Check off each item
as it is confirmed. Do not tag until all boxes are checked.

---

## CI and code quality

- [ ] All CI checks are passing on `main` (terraform fmt, validate, tflint,
      actionlint — see `.github/workflows/ci.yml`).
- [ ] `terraform fmt -check -recursive` exits 0 with no output:
      ```bash
      terraform fmt -check -recursive
      ```
- [ ] `pre-commit run --all-files` exits 0 with no failures.

---

## Module documentation

- [ ] All module READMEs are up to date. Re-run terraform-docs to verify:
      ```bash
      terraform-docs markdown table --config .terraform-docs.yml modules/aws/b1c-secure-bucket
      terraform-docs markdown table --config .terraform-docs.yml modules/aws/b1c-serverless-api
      terraform-docs markdown table --config .terraform-docs.yml modules/aws/b1c-aurora-cluster
      terraform-docs markdown table --config .terraform-docs.yml modules/gcp/b1c-secure-bucket
      terraform-docs markdown table --config .terraform-docs.yml modules/gcp/b1c-serverless-api
      terraform-docs markdown table --config .terraform-docs.yml modules/gcp/b1c-relational-db
      ```
      No diff should appear in git after running these commands.

---

## Security and portability checks

- [ ] No `backend {}` block exists in any module:
      ```bash
      grep -rnE '^\s*backend\s' modules/
      ```
      The above command must return no output.

- [ ] All `uses:` references in `.github/workflows/` are pinned to 40-char
      commit SHAs (the pre-commit `workflows-pinned-to-sha` hook enforces
      this, but verify manually):
      ```bash
      grep -rn 'uses:' .github/workflows/ | grep -vE '@[a-f0-9]{40}'
      ```
      The above command must return no output.

- [ ] Spot-check at least 3 pinned SHAs against the corresponding tag to
      confirm the SHA matches. For each workflow action reference, verify
      with the GitHub API:
      ```bash
      gh api repos/<owner>/<repo>/git/refs/tags/<tag> \
        --jq '.object.sha'
      ```
      Compare the returned SHA against the value in the workflow file.

- [ ] No hardcoded AWS account IDs in any tracked file:
      ```bash
      grep -rE '[0-9]{12}' --include='*.tf' --include='*.yml' --include='*.yaml' --include='*.md'
      ```
      Review any hits and confirm they are not account IDs (e.g., phone
      numbers in documentation are acceptable; AWS account IDs are not).

- [ ] No hardcoded GCP project/org numbers in any tracked file:
      ```bash
      grep -rE '"[0-9]{9,12}"' --include='*.tf' --include='*.yml' --include='*.yaml' --include='*.md'
      ```
      Review any hits — GCP project numbers and organization IDs are
      typically 9-12 digit numeric strings.

- [ ] No B1Codes-specific references in `modules/` or `.github/workflows/`
      other than attribution comments:
      ```bash
      grep -rn 'B1Codes\|llc-infra-core\|b1codes' modules/ .github/workflows/
      ```
      Review hits. Module source comments like "see the private
      llc-infra-core repo for an example" in inline documentation are
      acceptable. Hardcoded org-specific resource names or ARNs are not.

---

## Release notes

- [ ] `CHANGELOG.md` has a complete entry for `v0.1.0` (move content from
      `[Unreleased]` to `[0.1.0]` and fill in the release date).
- [ ] The `[0.1.0]` compare link at the bottom of `CHANGELOG.md` is updated
      with the correct tag URLs.

---

## Tagging

Once all boxes are checked:

```bash
# Ensure you are on main and it is up to date
git checkout main
git pull origin main

# Create an annotated tag
git tag -a v0.1.0 -m "v0.1.0 — initial public release

Modules (AWS): b1c-secure-bucket, b1c-serverless-api, b1c-aurora-cluster
Modules (GCP): b1c-secure-bucket, b1c-serverless-api, b1c-relational-db
Workflows (AWS): aws-lambda-deploy, aws-static-site, terraform-plan-cost
Workflows (GCP): gcp-cloudrun-deploy, gcp-static-site
Examples: lambda-python, static-site, gcp-cloudrun-python, gcp-static-site
Docs: CONSUMER-QUICKSTART, ARCHITECTURE, PREREQUISITES"

# Push the tag
git push origin v0.1.0
```

After pushing, create a GitHub Release from the tag and paste the v0.1.0
section from `CHANGELOG.md` as the release body.
