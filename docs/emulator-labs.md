# Emulator labs: practise AWS with no AWS account

Some labs say **`requires: emulator`**. They run the **real AWS CLI** in the lab terminal against the **AWS Emulator**, AWS's own free local stand-in for its APIs. You need no account and no keys, nothing costs money, and nothing is left behind: the emulator keeps everything in memory and forgets it when it stops.

```
git clone https://github.com/TrainWithShubham/tws-labs.git && cd tws-labs
EMULATOR=1 ./start_local_labs.sh
```

The first run downloads and builds the emulator image, which is large (about 1.6 GB), so it takes a few minutes. After that it starts in seconds. `./start_local_labs.sh stop` stops everything. Give Docker at least 3 GB of memory (the emulator is capped at 2 GB; the labs container needs about 0.75 GB).

Emulator labs run **on your machine only**. The hosted site shows them as a read-only walkthrough, the same as labs that use your own AWS account (see [aws-labs.md](aws-labs.md)). `EMULATOR=1` can be combined with `AWS=1`.

## The labs

| Lab | What you practise |
|---|---|
| [S3 storage in practice](../labs/aws/s3-storage-in-practice) | buckets, prefixes, versioning, a lifecycle rule, a bucket policy |
| [DynamoDB tables and queries](../labs/aws/dynamodb-tables-and-queries) | primary keys, batch writes, queries, conditional updates, TTL |
| [Queues and topics with SQS and SNS](../labs/aws/sqs-sns-fan-out) | a dead-letter queue, send and delete, a topic, and the queue policy that lets it deliver |
| [Your first CloudFormation stack](../labs/aws/cloudformation-first-stack) | a template, a stack, outputs, an update, deleting a stack |

## What it is, and what it is not

An emulator answers AWS API calls the way AWS does, closely enough to practise on. It is **not AWS**. What we have checked:

- **Works well:** S3, DynamoDB, SQS, SNS, CloudFormation (create, outputs, change sets, update, delete), plus many other services answered in a first sweep (IAM, STS, EC2 and VPC, Lambda, CloudWatch, Logs, SSM, Secrets Manager, KMS, ECR, ECS, EKS, Elastic Beanstalk, Budgets, Route 53). Inputs are validated like AWS validates them.
- **Does not enforce IAM permissions for users and roles.** A user with no policies can still list every bucket. Labs about IAM *permissions* stay on a real account (`requires: aws`).
- **Does honour an explicit `Deny` in a bucket policy**, so a policy that denies your own requests locks you out, as on AWS. The bucket owner can always delete the policy.
- **One account (`000000000000`) and one region (`us-east-1`).** There is no cross-account or cross-region behaviour.
- **Operations it has not implemented** answer `NotImplemented`. A lab never asks for one.
- **No Console.** You have the CLI and the lab's checks.
- Resources become ready in a moment, as on AWS (a new DynamoDB table or Lambda function takes a few seconds).

A check written against the emulator can differ from real AWS in small ways, so each lab says plainly that it is an emulator and links the real AWS documentation.

## How it works

`docker-compose.emulator.yml` adds an `emulator` container that **shares the lab container's network**. It answers at `https://127.0.0.1:9297` inside that container only: it is not published to your machine or your network. Its certificate is valid for `localhost`, which is why it shares the network instead of being reached by service name.

The emulator runs with request signing off (nothing outside the lab container can reach it) and telemetry off. The lab server hands each emulator lab's shell and checks exactly this environment, and nothing else from the server (`src/lab-env.js`, `src/emulator.js`):

| Variable | Value |
|---|---|
| `AWS_ENDPOINT_URL` | `https://127.0.0.1:9297` |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | `emulator` (dummy; the CLI refuses to run without some) |
| `AWS_REGION`, `AWS_DEFAULT_REGION` | `us-east-1` |
| `AWS_CA_BUNDLE` | a world-readable copy of the emulator's public certificate |

The lab page waits for the emulator (the status pill reads `emulator`) before it opens the terminal. If the stack was started without `EMULATOR=1`, the page says how to start it.

The AWS CLI image raises the shell's address-space cap to 3 GiB (`docker-compose.aws.yml`): the CLI's transfer library (`aws s3 cp`) aborts under the default 1 GiB cap.

## The pinned package

AWS publishes the emulator package only as "latest", and no ready-made image. `Dockerfile.emulator` pins the package by **SHA-256**, so a changed package stops the build instead of running unreviewed code. When AWS publishes a new LTS the build fails with a checksum mismatch: download the new package, review it, and update the two checksums (and the "last pinned" note).

## Troubleshooting

- **The lab says the emulator is not running:** stop the labs and start them with `EMULATOR=1 ./start_local_labs.sh`.
- **The pill stays on `emulator`:** the container is still starting, or was killed for memory (`docker compose logs emulator`). Raise Docker's memory and reload.
- **Port 8080 is taken:** `LABS_PORT=8090 EMULATOR=1 ./start_local_labs.sh`.
- **Start again from empty:** `docker compose restart emulator` forgets everything. Each lab's `setup.sh` also removes what it uses, so re-running a lab starts clean.

## Writing an emulator lab

See "Emulator labs" in [authoring.md](authoring.md). Short version: set `requires: emulator`, call `emulator_ready` first in every check, give resources fixed names, make `setup.sh` delete what it uses, and prove the lab with the emulator CI job (`TWS_PROVE_EMULATOR=1`). Unlike account labs, emulator labs **are** proven fail-before and pass-after in CI.
