# Project state (as of 1.2.0, 2026-10-15)

A hand-off note: what exists, how it is proven, what is decided, and what is left. Update it when you release.

## What exists
- **28 labs, 145 graded tasks, 7 tracks** (DevOps: Linux, Shell, Git, Docker, Kubernetes, GitHub Actions, Networking; Cloud: Elastic Beanstalk Cluster Mode, AWS CLI first steps; AI: none yet). Roadmap topics and their status: `labs/roadmap.json`.
- **Two ways to run**: local (`./start_local_labs.sh`, optionally `AWS=1`) and hosted on Elastic Beanstalk Cluster Mode (`deploy/`, redeployed by every push to `main`; a manual run is possible with `gh workflow run deploy.yml`). The hosted environment costs about $9/day while it is up.
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
- **Phase B (AWS proof in CI)**: a scheduled workflow against a disposable AWS account through an OIDC role (new Terraform in `deploy/infra/`, applied by a human). Until then account labs are proven by hand and the validator skips them.
- **Not verified yet**: the learner role created and used end to end; a full lab played in a browser on the live hosted site; screen-reader use inside the terminal.
- **Next labs**: the rest of the Kubernetes track (Ingress, volumes, rollouts), Terraform (parsed HCL, no binary), Prometheus rules, the FinOps audit on the account-lab pattern (rework of #25, credit @pooja-bhavani), IAM least privilege, an AI-agents lab on a scripted fake model endpoint (design in the `spike/ai-agent-lab` branch notes).
- **Open pull requests**: #25 (FinOps audit, rework requested) and #29 (budget guardrail, changes requested); #28 closes when #29 lands.
- **Backlog for the platform**: a web-preview tab and editor tab, embeds, completion certificates, an org kit for private lab folders (each needs its own plan and security review).
