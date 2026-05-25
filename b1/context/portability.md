# Portability discipline

`devops-platform` is the public, MIT-licensed engine. Its value proposition is that **any external consumer can adopt it without inheriting B1Codes' private infrastructure**. Eroding portability is a one-way door.

## Keep out of the engine

- Account IDs.
- `b1codes-*` resource names hardcoded into module bodies.
- References to the private `llc-infra-core` consumer beyond the existing "see the private repo for an example" pointer in `README.md`.
- Any value that only makes sense inside B1Codes' AWS Organization.

Everything that varies per consumer flows in as a Terraform variable, workflow input, or OIDC-derived credential (see [[conventions]] rule 3).

## Verification at release time

`RELEASE-CHECKLIST.md` contains the exact `grep` commands the release process uses. Two key invocations:

```bash
# 1. No hardcoded AWS account IDs (12-digit literals) in any tracked file.
grep -rE '[0-9]{12}' --include='*.tf' --include='*.yml' --include='*.yaml' --include='*.md'

# 2. No B1Codes-specific references in modules/ or .github/workflows/.
#    Inline doc pointers to llc-infra-core are acceptable; hardcoded
#    org-specific resource names or ARNs are not.
grep -rn 'B1Codes\|llc-infra-core\|b1codes' modules/ .github/workflows/
```

Both must be reviewed before tagging — see `RELEASE-CHECKLIST.md` "Security and portability checks".

## Why this matters for opinionated wrappers

A private consumer (e.g. `llc-infra-core`) is welcome to layer opinions — naming conventions, default tags, auth wiring — in *its own* wrapper modules that *call* the engine modules. That direction (private wraps public) preserves portability. The reverse direction (public knows about private) breaks it.
