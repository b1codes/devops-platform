# SPEC.md: B1Codes DevOps Platform (The Engine)

## 1. Mission Statement
To provide a standardized, secure, and "agent-friendly" deployment engine for B1Codes LLC projects. This repository follows the "Golden Path" methodology, abstracting complex AWS infrastructure into reusable GitHub Actions and Terraform modules.

## 2. Technical Stack
- **IaC:** Terraform (Modular)
- **CI/CD:** GitHub Actions (Reusable Workflows)
- **Security:** OpenID Connect (OIDC) for AWS Auth (No static keys)
- **Cost Tracking:** Infracost (Pull Request integration)
- **Cloud:** AWS (Lambda, App Runner, S3, CloudFront, Aurora Serverless)

## 3. Architecture: The Reusable Workflow
All B1Codes projects must call workflows defined in this repository.
- **Location:** `.github/workflows/`
- **Standard Workflows:**
    - `aws-lambda-deploy.yml`: Packages Python/Node and deploys to AWS Lambda.
    - `aws-static-site.yml`: Deploys React/Vue to S3 + CloudFront.
    - `terraform-plan-cost.yml`: Runs `terraform plan` and `infracost` for budget safety.

## 4. Terraform Modules
Standardized modules located in `/modules`:
- `b1c-serverless-api`: IAM Roles, Lambda, API Gateway.
- `b1c-secure-bucket`: S3 with OIDC access, encryption, and public access blocks.
- `b1c-aurora-cluster`: Aurora Serverless v2 configuration for multi-tenant isolation.

## 5. Agent Instructions (SOP)
When an AI agent is working in this repo:
1. **Never Hardcode:** All values must be variables or inputs.
2. **Security First:** Always pin GitHub Actions to commit SHAs.
3. **Documentation:** Every new module must include a `README.md` and an example `main.tf`.
