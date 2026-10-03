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
| Pull request targeting `main` | `tofu fmt -check`, `tofu init`, `tofu validate`, `tofu plan`, then the plan output is posted as a PR comment |
| Push to `main` (including a merged PR) | `tofu init`, `tofu apply -auto-approve` |

Both jobs install OpenTofu with `opentofu/setup-opentofu@v2` and start LocalStack as a service container before OpenTofu runs. No AWS credentials or repository secrets are used. The provider config uses dummy credentials, which LocalStack accepts.

Because every workflow run starts a fresh LocalStack container and a fresh state file, the resources are created from scratch each time and disappear when the job ends. This is expected for this assignment.

## Approvals and governance

### What this project does

The `apply` job runs `tofu apply -auto-approve` as soon as a change lands on `main`. The plan on the pull request is the only review step, and nothing in the pipeline pauses for a human. State uses `backend "local"`, so it lives on the runner and is discarded after each job.

That is acceptable here because nothing real is at stake. LocalStack is a simulation, there are no cloud credentials, nothing costs money, and the resources vanish when the job ends. The worst outcome of a bad apply is a failed run.

### What a team would add

For real infrastructure, the pull request and the apply would each get a gate:

| Control | What it does |
|---|---|
| **Branch protection or a ruleset on `main`** | Blocks direct pushes and requires a pull request. Requires the `plan` status check to pass before merging. |
| **Required reviewers** | Requires at least one approving review, ideally from the people who own the infrastructure (a `CODEOWNERS` file can route reviews). Stale approvals can be dismissed when new commits are pushed. |
| **GitHub environment with required reviewers** | Adding `environment: production` to the `apply` job pauses it until a designated reviewer approves the deployment. The environment can also be limited to deploys from `main`. |
| **Reviewed plan equals applied plan** | Run `tofu plan -out=tfplan`, keep that file, and apply exactly that plan. Otherwise the apply re-plans at merge time and may differ from what was reviewed. |
| **Plan posted to the pull request** | Putting the plan output in a PR comment gives reviewers the full diff without opening the Actions log. **This project does this:** the `plan` job posts its output with the GitHub CLI using the built-in `GITHUB_TOKEN`, with `pull-requests: write` granted to that job only. |
| **Remote state with locking** | A shared backend with locking (for example S3 with a lock table) lets the team share one source of truth and prevents two applies from running at once. A workflow `concurrency` group adds a second layer. |
| **Least-privilege credentials** | Real cloud access would use short-lived credentials (such as OIDC) scoped to what the pipeline needs, not long-lived admin keys. |

Platform details vary. For example, branch protection on private repositories depends on the GitHub plan, and by default a pull request author cannot approve their own PR, so a solo project needs a second reviewer or relies on the passing plan check alone.

### Trade-offs of `-auto-approve`

**Benefits:** it is fast and fully automated, it removes manual steps, and it makes every merge deploy, which is the core of a GitOps flow. It is also the only option for a pipeline with nobody watching.

**Risks:**
- **No human check at apply time.** A destructive change, such as replacing a database, is applied without a pause. Reviewers have to catch it in the plan before merging.
- **The plan can go stale.** Time passes between the PR plan and the merge, and other merges or manual changes can alter what the apply actually does. Auto-approve applies whatever the new plan says.
- **Review quality becomes the only control.** If branch protection is missing or reviewers skim the plan, a mistake or a malicious change reaches production directly.
- **Larger blast radius for compromise.** Anyone who can merge to `main`, or who compromises a workflow dependency, can change infrastructure using the pipeline's credentials.
- **Weaker audit trail.** Git history shows who merged, but no separate record shows who approved the apply.

**Governance view:** auto-approve moves the approval from the apply step to the merge step. That is a sound design only if the merge is genuinely controlled: protected branch, required checks, required reviews, and credentials limited to the minimum. The more valuable or irreversible the infrastructure, the more it makes sense to add the environment gate or an apply-from-saved-plan step, accepting some speed loss in exchange for a deliberate human decision.

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
