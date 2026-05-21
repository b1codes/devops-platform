# Prerequisites

Before you can use the devops-platform engine, four external resources must exist in your AWS account. This document walks through each one with copy-paste AWS CLI commands.

> **B1Codes' internal setup** of everything below lives in the private `llc-infra-core` repository (B1Codes' internal Brain layer), which is not publicly available. Any functionally-equivalent setup works — for example, the [`aws-actions/configure-aws-credentials` documentation](https://github.com/aws-actions/configure-aws-credentials#assumerolewithwebidentity) covers the OIDC wiring in detail.

---

## 1. AWS account

You need a working AWS account with billing enabled. All commands below assume the AWS CLI is installed and configured with credentials that have `AdministratorAccess` (or a tightly scoped equivalent) for the initial setup steps.

Verify your CLI is working:

```bash
aws sts get-caller-identity
```

---

## 2. OIDC identity provider for GitHub Actions

GitHub Actions authenticates to AWS by presenting a short-lived OIDC token. AWS must be configured to trust tokens issued by `token.actions.githubusercontent.com`.

Create the identity provider (run once per AWS account):

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list \
    6938fd4d98bab03faadb97b34396831e3780aea1 \
    1c58a3a8518e8759bf075b76b750d4f2df264fcd
```

> **Note on thumbprints:** AWS now validates the GitHub OIDC provider against its built-in library of trust, so thumbprints are no longer strictly required for this provider. They are included above for backward compatibility with older AWS SDK versions and tooling that still validates them explicitly.

Confirm the provider was created:

```bash
aws iam list-open-id-connect-providers
```

---

## 3. IAM role trusted to your GitHub org/repo

Create an IAM role that GitHub Actions can assume via the OIDC provider. The trust policy uses a `StringLike` condition to scope trust to repositories in your GitHub organization.

Save the following as `trust-policy.json`, replacing `<your-github-org>` and `<your-aws-account-id>`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<your-aws-account-id>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:<your-github-org>/*"
        }
      }
    }
  ]
}
```

Create the role:

```bash
aws iam create-role \
  --role-name GitHubActionsRole \
  --assume-role-policy-document file://trust-policy.json \
  --description "Role assumed by GitHub Actions via OIDC for devops-platform workflows"
```

### Permissions policy

The permissions this role needs depend on which workflows you use:

| Workflow               | Required permissions                                        |
|------------------------|-------------------------------------------------------------|
| `aws-lambda-deploy.yml` | `lambda:UpdateFunctionCode`, `lambda:GetFunction`          |
| `aws-static-site.yml`  | `s3:PutObject`, `s3:DeleteObject`, `cloudfront:CreateInvalidation` |
| `terraform-plan-cost.yml` | Read-only access to the resources being planned; write access to the Terraform state bucket |

Refer to the per-workflow README (coming in Phase 2) for exact minimal policy documents. For initial testing, you can attach `ReadOnlyAccess` for plan-only runs.

Attach a policy to the role:

```bash
aws iam attach-role-policy \
  --role-name GitHubActionsRole \
  --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess
```

Note the role ARN — you will pass it as an input to the reusable workflows:

```bash
aws iam get-role --role-name GitHubActionsRole --query 'Role.Arn' --output text
# arn:aws:iam::<your-aws-account-id>:role/GitHubActionsRole
```

---

## 4. Terraform remote state backend

Terraform state must be stored remotely so that CI runs and local runs share the same state file. This requires an S3 bucket and a DynamoDB table for state locking.

### Create the S3 bucket

Replace `<your-tf-state-bucket>` with a globally unique bucket name and `<your-aws-region>` with your preferred region (e.g., `us-east-1`):

```bash
aws s3api create-bucket \
  --bucket <your-tf-state-bucket> \
  --region <your-aws-region> \
  --create-bucket-configuration LocationConstraint=<your-aws-region>
```

> **Note:** For `us-east-1`, omit the `--create-bucket-configuration` flag entirely — it is not valid in that region.

Enable versioning (strongly recommended — allows state rollback):

```bash
aws s3api put-bucket-versioning \
  --bucket <your-tf-state-bucket> \
  --versioning-configuration Status=Enabled
```

Enable server-side encryption:

```bash
aws s3api put-bucket-encryption \
  --bucket <your-tf-state-bucket> \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'
```

Block all public access:

```bash
aws s3api put-public-access-block \
  --bucket <your-tf-state-bucket> \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

### Create the DynamoDB lock table

```bash
aws dynamodb create-table \
  --table-name <your-tf-lock-table> \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region <your-aws-region>
```

### Reference the backend in Terraform

In your Terraform root module, add a backend configuration:

```hcl
terraform {
  backend "s3" {
    bucket         = "<your-tf-state-bucket>"
    key            = "path/to/your/project/terraform.tfstate"
    region         = "<your-aws-region>"
    dynamodb_table = "<your-tf-lock-table>"
    encrypt        = true
  }
}
```

---

## Checklist

Before running `terraform init` or triggering a workflow, confirm each item:

- [ ] AWS CLI is configured and `aws sts get-caller-identity` returns your expected account ID.
- [ ] The OIDC identity provider for `token.actions.githubusercontent.com` exists in your account (`aws iam list-open-id-connect-providers`).
- [ ] The `GitHubActionsRole` (or equivalent) exists and its trust policy references your GitHub org.
- [ ] The role ARN is available to pass as a workflow input (store it as a GitHub Actions variable or secret).
- [ ] The Terraform state S3 bucket exists, has versioning enabled, and is not publicly accessible.
- [ ] The DynamoDB lock table exists with a `LockID` hash key.
- [ ] Your `terraform { backend "s3" {} }` block references the correct bucket, key, region, and table.
- [ ] `terraform init` succeeds without errors.
