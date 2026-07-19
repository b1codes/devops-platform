# Consumer Quickstart: Deploy a Lambda in Under an Hour

This guide walks you through deploying the `example-python-api` Lambda using
the devops-platform engine. By the end you will have a live HTTP endpoint
authenticated via OIDC with no static AWS credentials in your repository.

Estimated reading time: 10 minutes. Estimated hands-on time: 30-45 minutes
(mostly waiting for `terraform apply` and the first CI run).

---

## 1. Prerequisites checklist

Before starting, verify every item in [docs/PREREQUISITES.md](./PREREQUISITES.md):

- [ ] AWS CLI is installed and `aws sts get-caller-identity` returns your account.
- [ ] The OIDC identity provider for `token.actions.githubusercontent.com` exists
      in your AWS account.
- [ ] A GitHub Actions IAM role exists and its trust policy references your
      GitHub org or repo.
- [ ] A Terraform remote state S3 bucket and DynamoDB lock table exist.
- [ ] Terraform >= 1.6 is installed locally (`terraform version`).

---

## 2. Fork or copy the example

You have two options:

### Option A — Fork the repo (recommended for evaluation)

```bash
# Fork via the GitHub UI, then clone your fork:
git clone https://github.com/<your-org>/devops-platform
cd devops-platform/examples/lambda-python
```

### Option B — Copy the example into your own repo

```bash
cp -r examples/lambda-python /path/to/your-repo/infra/lambda-python
```

If you copy the files, update the `source` path in `main.tf` to point at
the published module (or the relative path if you also copy the module):

```hcl
module "example_python_api" {
  # Replace with the relative path from your repo root to the module,
  # or with a registry reference once published:
  source = "github.com/B1Codes/devops-platform//modules/aws/b1c-serverless-api?ref=v0.1.0"
  ...
}
```

---

## 3. Configure your AWS OIDC role and GitHub secrets

### 3a. Determine the role ARN

If you followed [docs/PREREQUISITES.md](./PREREQUISITES.md), you created a
role named `GitHubActionsRole`. Retrieve its ARN:

```bash
aws iam get-role --role-name GitHubActionsRole --query 'Role.Arn' --output text
# arn:aws:iam::123456789012:role/GitHubActionsRole
```

### 3b. Confirm the trust policy references your repo

The trust policy `Condition` block must allow the specific repo that will run
the deployment workflow. A repo-scoped condition (recommended for production):

```json
"StringEquals": {
  "token.actions.githubusercontent.com:sub":
    "repo:<your-org>/devops-platform:ref:refs/heads/main"
}
```

A broader org-scoped condition (acceptable for multi-repo setups):

```json
"StringLike": {
  "token.actions.githubusercontent.com:sub": "repo:<your-org>/*"
}
```

Update the trust policy if needed:

```bash
aws iam update-assume-role-policy \
  --role-name GitHubActionsRole \
  --policy-document file://trust-policy.json
```

### 3c. Confirm the role has Lambda permissions

The `aws-lambda-deploy.yml` workflow calls `aws lambda update-function-code`
and `aws lambda wait function-updated`. The minimum required permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "lambda:UpdateFunctionCode",
        "lambda:GetFunction",
        "lambda:GetFunctionConfiguration"
      ],
      "Resource": "arn:aws:lambda:<region>:<account-id>:function:example-python-api"
    }
  ]
}
```

### 3d. Add the secret to GitHub

In your GitHub repository:

1. Go to **Settings > Secrets and variables > Actions**.
2. Click **New repository secret**.
3. Name: `AWS_DEPLOY_ROLE_ARN`
4. Value: the role ARN from step 3a.
5. Click **Add secret**.

---

## 4. Apply the Terraform

### 4a. Configure remote state

Create a `backend.tf` in the `examples/lambda-python/` directory (do not
commit secrets — the bucket name is not sensitive):

```hcl
terraform {
  backend "s3" {
    bucket         = "<your-tf-state-bucket>"
    key            = "examples/lambda-python/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "<your-tf-lock-table>"
    encrypt        = true
  }
}
```

### 4b. Initialize

```bash
cd examples/lambda-python
terraform init
```

Expected output ends with: `Terraform has been successfully initialized!`

### 4c. Plan

```bash
terraform plan
```

Review the plan. You should see resources being created for:

- `aws_iam_role.lambda_exec` — the Lambda execution role
- `aws_lambda_function.this` — the Lambda function
- `aws_apigatewayv2_api.this` — the HTTP API
- `aws_cloudwatch_log_group.lambda` — the log group

### 4d. Apply

```bash
terraform apply
```

Type `yes` when prompted. Apply takes roughly 30-60 seconds.

At the end, note the output:

```text
api_endpoint = "https://abc123def.execute-api.us-east-1.amazonaws.com"
```

---

## 5. Push to trigger the deploy workflow

The `.github/workflows/deploy.yml` in the example fires on pushes to `main`
that touch `examples/lambda-python/src/**`. Trigger it:

```bash
# Make a trivial change to the handler
echo "# trigger deploy $(date)" >> examples/lambda-python/src/index.py
git add examples/lambda-python/src/index.py
git commit -m "chore: trigger initial lambda deploy"
git push origin main
```

Navigate to **Actions** in your GitHub repository to watch the workflow run.
It should complete in under two minutes.

---

## 6. Verify by hitting the api_endpoint

```bash
API_URL=$(cd examples/lambda-python && terraform output -raw api_endpoint)
curl "${API_URL}/hello"
```

Expected response:

```json
{
  "message": "Hello from devops-platform example-python-api",
  "path": "/hello",
  "method": "GET",
  "timestamp": "2025-01-15T12:00:00Z"
}
```

A `200` response with this shape confirms end-to-end success: Terraform
created the infrastructure, the CI workflow uploaded your code via OIDC, and
API Gateway is proxying requests to Lambda.

---

## 7. Troubleshooting

### Error: "Not authorized to perform sts:AssumeRoleWithWebIdentity"

**Cause:** The OIDC trust policy does not match the repo or branch making the
request.

**Fix:** Compare the `sub` claim in the trust policy against the actual claim.
The GitHub Actions OIDC token for a push to `main` looks like:
`repo:<org>/<repo>:ref:refs/heads/main`. Use a `StringLike` condition with a
wildcard if you want to cover all branches:
`"repo:<org>/<repo>:*"`.

---

### Error: "The security token included in the request is invalid" or region errors

**Cause:** The `aws_region` variable in Terraform or the `aws_region` input in
the workflow does not match the region where the Lambda was created.

**Fix:** Ensure `var.aws_region` in `variables.tf` and the `aws_region` input
in the caller workflow both use the same value (e.g., `us-east-1`).

---

### Error: "User is not authorized to perform: lambda:UpdateFunctionCode"

**Cause:** The IAM role assumed by GitHub Actions is missing the required
Lambda permissions.

**Fix:** Attach a policy containing `lambda:UpdateFunctionCode`,
`lambda:GetFunction`, and `lambda:GetFunctionConfiguration` scoped to the
function ARN. See step 3c above for a minimal policy document.

---

### Error: "Error zipping source directory: No such file or directory"

**Cause:** The `source_dir` input in the caller workflow does not point to
the correct path relative to the repository root.

**Fix:** Confirm that the path exists in the checked-out workspace. In the
example, `source_dir: examples/lambda-python/src` is relative to the repo
root. Run `ls examples/lambda-python/src` locally to confirm.

---

### Error: "state data in S3 does not have the expected content"

**Cause:** Two concurrent `terraform apply` runs targeted the same state key,
or the DynamoDB lock table was not specified and the state file became
corrupted.

**Fix:** Ensure each example or project uses a unique `key` in the backend
config. Enable state locking with a DynamoDB table
(`dynamodb_table = "<your-tf-lock-table>"`). If the state is already
corrupted, use `terraform force-unlock <lock-id>` to release a stale lock,
then revert the state to the last good version using S3 versioning.
