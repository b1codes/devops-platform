# Security Policy

## Supported versions

| Version | Supported          |
|---------|--------------------|
| v0.x    | Best-effort basis  |

This project is in active early development. Security fixes for the `v0.x` series are addressed on a best-effort basis. Once a `v1.0.0` is tagged, a formal support window will be defined.

---

## Reporting a vulnerability

**Please do not open a public GitHub issue to report a security vulnerability.**

Use GitHub's private disclosure channel instead:

[Report a vulnerability via GitHub Security Advisories](https://github.com/B1Codes/devops-platform/security/advisories/new)

This creates a private advisory visible only to maintainers, keeping details confidential until a fix is available and coordinated disclosure can occur.

### What to include

To help triage efficiently, please provide:

- A description of the vulnerability and the potential impact.
- The affected component (module name, workflow file, or example path).
- Steps to reproduce or a proof-of-concept (can be attached privately to the advisory).
- The version or commit SHA where you observed the issue.

### Response timeline

- **Triage:** within 5 business days of submission.
- **Status update:** within 10 business days confirming whether the report is accepted and, if so, an estimated fix timeline.
- Maintainers will coordinate a disclosure date with the reporter before publishing the advisory publicly.

---

## Scope

### In scope

Vulnerabilities in code that lives in this repository:

- Terraform modules under `modules/` — e.g., overly permissive IAM policies, insecure defaults, resource misconfigurations.
- Reusable GitHub Actions workflows under `.github/workflows/` — e.g., secret exposure paths, unpinned action references, missing permission scopes.
- Example code under `examples/` — e.g., hardcoded credentials, insecure configurations used as a copy-paste starting point.

### Out of scope

- Vulnerabilities in **upstream GitHub Actions** (e.g., `actions/checkout`, `aws-actions/configure-aws-credentials`). Report those to the respective action's repository.
- Vulnerabilities in **AWS services** themselves. Report those to [AWS Security](https://aws.amazon.com/security/vulnerability-reporting/).
- Vulnerabilities in **Terraform providers**. Report those to [HashiCorp](https://www.hashicorp.com/security).
- Issues that require physical access to infrastructure or social engineering of maintainers.

---

## Preferred languages

Reports may be submitted in English.
