# Project state (as of 1.5.0, 2026-11-12)

A hand-off note: what exists, how it is proven, what is decided, and what is left. Update it when you release.

## What exists
- **54 labs, 271 graded tasks, 12 tracks** (DevOps: Linux, Shell, Git, Docker, Kubernetes, GitHub Actions, Networking; Cloud: Elastic Beanstalk Cluster Mode, AWS (CLI first steps on your account, and four emulator labs: S3, DynamoDB, SQS and SNS, CloudFormation), Terraform, Helm, GitOps; AI: Python for DevOps, AI agents). Roadmap topics and their status: `labs/roadmap.json`.
- **Two ways to run**: local (`./start_local_labs.sh`, optionally `AWS=1`) and hosted on Elastic Beanstalk Cluster Mode (`deploy/`, redeployed by every push to `main`; a manual run is possible with `gh workflow run deploy.yml`). The hosted environment costs about $9/day while it is up (measured: about $153 gross for 1-20 Oct 2026). **It is currently torn down and `deploy.yml` is disabled** (2026-10-20); to bring the site back run `gh workflow enable deploy.yml`, then `gh workflow run deploy.yml`.
- **Learner features**: tiered hints, Restart lab, Skip with per-task setup, task progress in the browser, plain-words session-end messages, a "typed but not run" nudge, AA contrast, focus ring, skip link.
- **Operator features**: opt-in usage counters and `/admin/stats` (hardest tasks), per-audience invite codes (`deploy/README.md` has the rotation runbook), image-size budget in CI.

## How correctness is proven
See "How labs are proven" in `AGENTS.md`. In short: validator (fail-before/pass-after, `cases/`, skip-ahead), all-labs play-through over the real WebSocket path, real-Chrome end-to-end tests (including axe and the hosted profile), fake-`aws` tests for account labs.
Gotchas learned the hard way:
- Only **one integration test file may drive ptys** (`lab-flow.test.js`): concurrent files share the per-session user ids and a session close kills every process of that user.
- A recursive `mkdir` under `/proc` never returns on Linux; never use it in a test.
- A trailing `cmd && fail "..."` makes a check exit non-zero when the condition is false; use `! cmd || fail` or `if`.
- bash locals are dynamically scoped: helpers like `retry` use underscore-prefixed locals.
- The validator's shell does not apply the server's `ulimit` bootstrap; checks comparing limits see `unlimited` there.

## Decisions
- **Cloud labs use the learner's own AWS account** (not a simulator): local only, short-lived credentials by default, a least-privilege role and budget alarm (`deploy/learner-role.yaml`), a graded cleanup in every lab. The hosted site never takes AWS keys.
- **Kubernetes lives on the DevOps line** (manifest practice, no cluster); a managed-Kubernetes topic (EKS, Helm, GitOps) can come later on Cloud.
- **Lightweight is a requirement**: stubs and parsers instead of big binaries in the base image; the AWS CLI is an opt-in overlay image.
- Releases, tags and hosted deploys happen only when the maintainer asks.

## Open work
- **Plan items not done**: a review of every failure message (the biggest remaining learner-facing item), link checking for lab resource URLs, a performance budget, a soak test, "stuck" signals in `/admin/stats`, Firefox and Safari checks, reconnecting after a dropped network without a server restart.
- **Phase B (AWS proof in CI) is now only for labs that need a real account** (IAM permissions and denials, anything the emulator does not model). Emulator labs are proven in the `emulator` CI job. For real-account labs it is still a scheduled workflow against a disposable AWS account through an OIDC role (new Terraform in `deploy/infra/`, applied by a human). Until then account labs are proven by hand and the validator skips them.
- **Not verified yet**: the learner role created and used end to end; a full lab played in a browser on the live hosted site; screen-reader use inside the terminal.
- **Next labs**: the rest of the Kubernetes track (Ingress, volumes, rollouts), Prometheus rules, Helm and GitOps (parsed YAML, no big binaries), the FinOps audit on the stub-aws pattern (rework of #25, credit @pooja-bhavani), more AI-agent labs on the scripted stand-in model (`labs/ai/your-first-agent-loop/support/stand_in.py`: tool safety, memory and context limits, multi-tool agents), and a "bring your own key" lab against a real provider (local only, like the AWS labs).
- **Open pull requests**: #25 (FinOps audit: fix `roadmap.json`, skip-ahead setup, README) and #29 (budget guardrail: deploy-role permissions first), both waiting on their authors; #28 closes when #29 lands.
- **Python and the stand-in model**: `python3` (standard library only) is in the base image; AI labs talk to a per-session scripted stand-in on its own port (about 18 MB), started from `setup.sh`. Checks run the learner's code on data it has not seen (random counts per run) so a hard-coded answer fails.
- **Not fixed, hosted/EB only** (from the 2026-10-21 whole-repo review): the OIDC trust policy always includes the name-only subject (`deploy/infra/iam.tf`), the ALB closes idle WebSockets after 60 s (no pings), no per-session limit on `/lab/check`, and `cases/*/ok-*.sh` stay readable in the image.
- **Grading Terraform**: labs check parsed HCL with `hcl_strip`/`hcl_block`/`hcl_attr` in `labs/lib.sh` (comments dropped, values read inside the right block), not greps.
- **Backlog for the platform**: a web-preview tab and editor tab, embeds, completion certificates, an org kit for private lab folders (each needs its own plan and security review).

## Catalog growth (1.4.0)
1.4.0 added eleven labs after 1.3.0: Kubernetes storage (#82), labels and selectors, probes and rolling updates, Ingress, Jobs and CronJobs, namespaces (#88), new Helm and GitOps tracks, Git rebase and cherry-pick, shell functions and arguments, and Python JSON config and CLI. Linux in Action was rebuilt as an operations capstone (#90, from #87). The plan for what comes next is in `docs/lab-plan.md`. #25 and #29 were closed on 2026-10-31 after ten days without a reply (the ideas stay welcome; #28 stays open).

**#87 was split.** The contributor's PR also carried a `challenges/linux/*` system, a pluggable `src/runtime.js` and changes to `src/routes/session.js`, the Dockerfile and CSS. Only the lab shipped (#90). The engine and challenges work was not merged: it changes session minting and isolation, so it needs its own PR and a security review against the engine invariants in `AGENTS.md`.

## AWS Emulator labs (1.5.0)
- **What:** `requires: emulator` labs run the real AWS CLI against AWS's own local emulator, started beside the labs by `EMULATOR=1 ./start_local_labs.sh` (`docker-compose.emulator.yml`, `Dockerfile.emulator`, `src/emulator.js`, `docs/emulator-labs.md`). Local only; hosted shows them read-only.
- **Design:** the emulator shares the lab container's network (its certificate is valid for `localhost` only), runs with request signing off, and learners get dummy keys, its endpoint and a public copy of its certificate. The package is pinned by SHA-256: AWS only serves "latest", so a new package stops the build until reviewed (update the two checksums in `Dockerfile.emulator`).
- **Proof:** the `emulator` CI job runs the validator (`TWS_PROVE_EMULATOR=1`) for every emulator lab and plays each in real Chrome (`test/e2e/emulator.e2e.js`, which fails rather than skips when `E2E_REQUIRE_EMULATOR` is set).
- **Verified behaviour:** it does not enforce IAM for users and roles; it does honour an explicit `Deny` in a bucket policy; SNS delivers to an SQS queue only once the queue's policy allows it; CloudFormation create, outputs, change sets, update and delete work and remove their resources; DynamoDB tables and stacks take about a second to settle (a table deletion takes about four).
- **Gotchas learned:** AWS CLI waiters poll every 20 to 30 seconds, so solutions and hints poll the status instead; `aws s3 cp` aborts under the default 1 GiB address-space cap (the AWS overlay allows 3 GiB); checks for AWS and emulator labs get 30 seconds (`checkTimeoutMs` in `src/lab-env.js`); a `ran_re` pattern must not also match a longer flag (`--condition-expression` versus `--key-condition-expression`); near-miss cases must not leave a second stack or resource that breaks the next replay, so `setup.sh` cleans everything the lab can create.
- **Not done:** Lambda labs (the emulator runs function code inside its own process; sandboxing is unchecked), Beanstalk and EKS labs on the emulator (not verified), a live resources panel beside the terminal (needs its own plan and a security review). The README GIF was not re-recorded: the normal lab page did not change (only emulator labs gain a banner and a readiness pill).
