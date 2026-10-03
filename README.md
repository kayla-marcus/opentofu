# OpenTofu + LocalStack + GitHub Actions

CST 365 DevOps assignment for Meridian Labs. A small OpenTofu project that provisions three AWS resources in [LocalStack](https://www.localstack.cloud/) (a local AWS simulation, so no real AWS account is used) and deploys them through a GitHub Actions pipeline.

## What it creates

| Resource | Purpose |
|---|---|
| `aws_s3_bucket` | Object storage |
| `aws_dynamodb_table` | Key-value database (on-demand billing, string key `id`) |
| `aws_sqs_queue` | Message queue |

Resource names follow `<project_name>-<environment>-<suffix>`, for example `meridian-dev-storage`.

## Project files

| File | Purpose |
|---|---|
| `main.tf` | `terraform` block, local state backend, AWS provider pointed at LocalStack, and the three resources |
| `variables.tf` | Input variables: `aws_region`, `project_name`, `environment`, `localstack_endpoint` |
| `outputs.tf` | Outputs: `bucket_name`, `bucket_arn`, `dynamodb_table_name`, `sqs_queue_url` |
| `.terraform.lock.hcl` | Pins the AWS provider version so local and CI runs match |
| `.github/workflows/opentofu.yml` | CI/CD pipeline (see below) |
| `.gitignore` | Keeps `.terraform/` and state files out of Git |

State is stored with an explicit `backend "local"` declaration (`terraform.tfstate`).

## CI/CD workflow

| Event | What runs |
|---|---|
| Pull request targeting `main` | `tofu fmt -check`, `tofu init`, `tofu validate`, `tofu plan` |
| Push to `main` (including a merged PR) | `tofu init`, `tofu apply -auto-approve` |

Both jobs install OpenTofu with `opentofu/setup-opentofu@v2` and start LocalStack as a service container before OpenTofu runs. No AWS credentials or repository secrets are used. The provider config uses dummy credentials, which LocalStack accepts.

Because every workflow run starts a fresh LocalStack container and a fresh state file, the resources are created from scratch each time and disappear when the job ends. This is expected for this assignment.

## Why LocalStack is pinned to 4.4.0

The workflow uses `localstack/localstack:4.4.0` instead of the default `latest` tag.

Starting March 23, 2026, LocalStack merged its free Community image and its paid Pro image into one image that requires a `LOCALSTACK_AUTH_TOKEN` to start. Using `latest` without a token makes the service container fail to start, which is what happened in this project's first CI run. LocalStack's own guidance for users who want to keep using the Community image is to pin a fixed older version, and it states that past Community releases remain available on Docker Hub. Version 4.4.0 is one of those releases. It starts without a token and supports S3, DynamoDB, and SQS, the only services used here.

Trade-off: a pinned image does not receive LocalStack updates. That is acceptable for a learning project. The alternative is to create a free LocalStack account, store the token as a GitHub secret named `LOCALSTACK_AUTH_TOKEN`, and pass it to the service container through `env:`.

Documentation:
- [LocalStack: The Road Ahead (single-image announcement and pinning guidance)](https://blog.localstack.cloud/the-road-ahead-for-localstack/)
- [LocalStack: Moving to a Single Image, Your Next Steps](https://blog.localstack.cloud/localstack-single-image-next-steps/)
- [LocalStack on Docker Hub (current image and auth token requirement)](https://hub.docker.com/r/localstack/localstack)
- [Example of another project pinning to 4.4.0 after the change (game-ci/unity-builder #822)](https://github.com/game-ci/unity-builder/issues/822)

## Running locally

Requires Git, OpenTofu, and Docker Desktop.

```powershell
docker run -d --name localstack -p 4566:4566 localstack/localstack:4.4.0
tofu init
tofu plan
tofu apply
```

Clean up in this order:

```powershell
tofu destroy
docker rm -f localstack
```

Removing the container before running `tofu destroy` leaves state that no longer matches LocalStack. If that happens, delete `terraform.tfstate` and `terraform.tfstate.backup`.
