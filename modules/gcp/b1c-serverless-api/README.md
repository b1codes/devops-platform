# b1c-serverless-api (GCP)

A Cloud Run v2 service with a dedicated runtime service account and configurable autoscaling. Mirrors [`modules/aws/b1c-serverless-api`](../../aws/b1c-serverless-api/) for the GCP provider — with one structural difference: Cloud Run deploys a **container image**, not a zip/source directory.

## Features

- **Auth-free by default** — `allow_unauthenticated = false` (the default) creates no public IAM invoker binding. Set it to `true` for a public endpoint, or layer your own IAM/JWT authorization in a wrapper module (mirrors the AWS module's auth-free-by-design stance).
- **Dedicated runtime identity** — a `google_service_account` is created per service, parallel to the AWS module's Lambda execution role. Grant it extra project roles via `extra_role_ids`.
- **Configurable autoscaling** — `min_instance_count` (0 allows scale-to-zero) and `max_instance_count`.
- **No API Gateway resource needed** — Cloud Run's built-in HTTPS endpoint + IAM invoker binding replace the AWS module's separate API Gateway v2 + Lambda integration.
- **No CloudWatch-log-group equivalent** — Cloud Run wires container stdout/stderr to Cloud Logging automatically. This is a platform difference, not a missing feature.

## Usage

```hcl
module "api" {
  source = "github.com/B1Codes/devops-platform//modules/gcp/b1c-serverless-api?ref=v0.1.0"

  project_id      = "my-gcp-project"
  service_name    = "example-api"
  region          = "us-central1"
  container_image = "us-central1-docker.pkg.dev/my-gcp-project/my-repo/example-api:latest"

  min_instance_count = 0
  max_instance_count = 10
  memory             = "512Mi"
  cpu                = "1"

  labels = { environment = "prod", project = "my-app", managed_by = "terraform" }
}

output "service_url" {
  value = module.api.service_url
}
```

This module is **auth-free** — consumers layer authorization in a wrapper (Auth0, Cognito/Identity Platform, any JWKS-compatible IdP), same convention as the AWS module.

See [`examples/basic/main.tf`](./examples/basic/main.tf) for a runnable minimal example.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.6 |
| google | ~> 6.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_id | GCP project ID in which to create the Cloud Run service. | `string` | n/a | yes |
| service_name | Name of the Cloud Run service. | `string` | n/a | yes |
| region | GCP region to deploy into. | `string` | n/a | yes |
| labels | Map of labels to merge into every labelable resource. | `map(string)` | `{}` | no |
| container_image | Full container image reference to deploy. | `string` | n/a | yes |
| container_port | TCP port the container listens on. | `number` | `8080` | no |
| memory | Memory limit per container instance. | `string` | `"512Mi"` | no |
| cpu | CPU limit per container instance. | `string` | `"1"` | no |
| timeout_seconds | Maximum request duration in seconds. | `number` | `30` | no |
| min_instance_count | Minimum warm container instances. | `number` | `0` | no |
| max_instance_count | Maximum container instances. | `number` | `10` | no |
| allow_unauthenticated | Grant roles/run.invoker to allUsers. | `bool` | `false` | no |
| environment_variables | Environment variables injected at runtime. | `map(string)` | `{}` | no |
| extra_role_ids | Additional project IAM roles for the runtime service account. | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| service_name | Name of the Cloud Run service. |
| service_url | HTTPS URL of the deployed Cloud Run service. |
| runtime_service_account_email | Email of the Cloud Run runtime service account. |

<!-- END_TF_DOCS -->

## License

MIT
