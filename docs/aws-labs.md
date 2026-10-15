# AWS labs: practice on your own AWS account

Most labs run entirely inside the container and need nothing. A few Cloud labs (they say **needs an AWS account**) use the
**real AWS CLI against your own account**, because that is the skill. You bring the account; TWS Labs never gets your keys.

- **Cost:** each lab uses free-tier or pennies (tiny S3 buckets, 1 GiB volumes) and ends with a graded cleanup. Do the cleanup and a lab costs well under $0.10.
- **Where they run:** only on your machine (`AWS=1 ./start_local_labs.sh`). The hosted site shows these labs as a read-only walkthrough and never asks for AWS keys.
- **What is installed:** the AWS CLI v2 lives in a separate image used only with `AWS=1` (about 190 MB on top of the normal image, trimmed to the services the labs use). The normal image is unchanged.

## One-time setup (about 5 minutes)

1. **Use a non-root identity.** Make or use an IAM user (or SSO role) that is *not* the account root. The labs refuse root credentials.
2. **Create the learner role.** In the CloudFormation console choose *Create stack -> Upload a template file* and pick `deploy/learner-role.yaml`. It asks for:
   - `LearnerPrincipalArn`: your own IAM user or role ARN (it may assume the role, nobody else),
   - `BudgetEmail`: where the **$5 monthly budget alarm** (at 80%) is sent,
   - `MonthlyBudgetUsd`: leave at 5.

   The role `tws-labs-learner` can only touch S3 buckets named `tws-labs-*`, create **tiny (2 GiB or less) tagged EBS volumes** and change only volumes carrying the `tws-labs` tag, manage IAM roles and policies under the `/tws-labs/` path (attaching only lab policies), and read (describe) the rest. No bucket policies or ACLs, no instances, no network changes.
3. **Copy the role ARN** from the stack's *Outputs* tab.

## Each time you practice

```bash
# on your machine; needs the AWS CLI and your normal credentials
eval "$(scripts/aws-lab-creds.sh arn:aws:iam::<your-account-id>:role/tws-labs-learner)"   # one-hour credentials
export AWS_REGION=us-east-1                                                                # the region the lab names
AWS=1 ./start_local_labs.sh
```

Open the lab (they are marked on the track page). The credentials expire after an hour; run the first line again for another hour
(`--duration 7200` for longer, up to 12 hours). The container receives your `AWS_*` variables **only for these labs**, and nothing else from your environment.

Prefer long-lived access keys? They work too (export `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`), but short-lived credentials are safer: a key that is
copied or leaked stops working on its own.

## Cleaning up

Every lab tags what it creates `tws-labs=<lab-id>` and ends with a cleanup task. If you abandon a lab midway, delete the stack's leftovers by hand (list them with
`aws resourcegroupstaggingapi get-resources --tag-filters Key=tws-labs`), then delete the CloudFormation stack to remove the role and the budget alarm when you are finished with the AWS labs.

## Is it safe?

- The container only ever sees the credentials you put in your shell; they stay on your machine. They are passed to the lab shell and its checks only (`src/lab-env.js`, tested).
- The learner role limits what a mistake can do. Even so, run the labs in a **personal or sandbox account**, never one that holds anything that matters.
- Do not paste credentials into the lab terminal output, screenshots or issues.
- On the hosted site the labs are read-only. If a page ever asks you for AWS keys there, it is not us.

## Troubleshooting

| Problem | Fix |
|---|---|
| `AWS=1 needs your AWS credentials` | Run the `eval` line in the same terminal, then start again. |
| `ExpiredToken` in the lab | The hour is up. Run the `eval` line again, then `./start_local_labs.sh stop` and start with `AWS=1` again. |
| `AccessDenied` on something a lab asks | Make sure you assumed `tws-labs-learner` (`aws sts get-caller-identity` shows `assumed-role/tws-labs-learner`). |
| `Found invalid choice` for an AWS service | The overlay keeps only the services the labs use; a lab that needs another adds it to `AWS_SERVICES` in `Dockerfile.aws`. |
| Wrong region | Set `AWS_REGION` before `AWS=1 ./start_local_labs.sh`. |
