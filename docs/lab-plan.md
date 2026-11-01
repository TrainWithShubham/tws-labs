# Lab and platform plan

Where the catalog should grow next, and what would make the platform richer. Written 2026-10-31 after comparing our catalog with
what a typical full DevOps curriculum covers. Update it as items ship; move finished ones into `CHANGELOG.md`.

## What we already do better
- Every offline task is **graded on real machine state** and proven by a script: it fails before its solution, passes after, rejects near misses and accepts valid alternatives.
- Self-hostable in one command, no account, runs on Windows through the container.
- Community-contributed labs with credit, a linter that gives authoring advice, and an AI-authoring brief.

## Where the catalog is thin
| Area | Today | Gap |
|---|---|---|
| Kubernetes | 5 labs (pods, services, configs, fix-the-manifest, storage) | labels and selectors, probes and rollouts, ingress, jobs and CronJobs, StatefulSets, RBAC, resource limits and quotas, `kubectl` reading skills |
| Helm | none | chart anatomy, values and overrides, templating functions, releases, subcharts |
| GitOps | none (topic is "next") | Application manifests, sync policy, Helm and Kustomize sources, sync waves and hooks, rollback |
| Git | 6 labs | rebase and cherry-pick, reading history (`log`, `diff`, `blame`, `bisect`), tags and releases, hooks |
| Shell | 1 lab | functions and arguments, loops and conditionals, parameter expansion, `trap` and error handling, small projects |
| Networking | 3 labs | subnets and CIDR practice, TCP and UDP, DNS records, HTTP with `curl`, TLS, NAT |
| Docker | 3 labs | running containers (ports, env, volumes), image inspection, networking, Compose profiles, image scanning |
| AWS | 2 labs | IAM policies, EC2 lifecycle, VPC, S3 beyond the basics, Lambda, CloudWatch (account labs, on the learner's own account) |
| Python | 1 lab | JSON, YAML and `argparse`, HTTP clients, testing scripts |
| Go | none | a "Go for DevOps" line is the biggest missing language |
| AI | 1 lab | prompts and structured output, RAG on a stand-in index, tool use and guardrails, evaluating agent runs |

## Phase 1 (in this branch): nine labs
Kubernetes: labels and selectors, probes and rollouts, ingress, jobs and CronJobs. Helm: your first chart (new track). GitOps: your first
Application (new track). Git: rebase and cherry-pick. Shell: functions and arguments. Python: JSON config and a CLI.

## Phase 2: next labs (all fit the offline, no-new-binary rule)
1. Kubernetes: StatefulSets and headless Services; RBAC (Role, RoleBinding); requests, limits and quotas; NetworkPolicy.
2. Git: reading history (`log`, `blame`, `bisect` on a seeded repo); tags and semantic versions.
3. Shell: loops and conditionals; parameter expansion; `trap`, `set -euo pipefail`; a log-rotation project.
4. Networking: CIDR and subnet practice; DNS records by hand (zone files); HTTP status and headers with `curl`.
5. Docker: Compose environment, ports and volumes; healthchecks; a `.dockerignore` and image size lab.
6. Helm: values layering, `_helpers.tpl`, conditionals and ranges. GitOps: sync waves and hooks; Kustomize overlays.
7. Python: YAML and HTTP clients; tests with `unittest`.
8. AI: structured output and validation on a scripted stand-in model; a small retrieval lab with a keyword index; guardrails for an agent's tools.

## Phase 3: needs a decision before building
- **Go for DevOps**: needs the Go toolchain in the image (about 250 MB). Options: an opt-in overlay image like the AWS one, which keeps the base light.
- **AWS depth** (IAM, EC2, VPC, Lambda): more account labs; each needs a real-account proof and a cleanup check.
- **Projects**: multi-step capstones that combine earlier labs (for example "ship a small service": Dockerfile, manifest, workflow, release).

## Platform ideas (each needs its own plan and a security review; not started)
- **Completion certificates** per topic or track, issued locally as a printable page with a verifiable code.
- **Project labs** (capstones) as a lab kind with a longer time budget and a rubric of graded checkpoints.
- **Roadmap views**: a "ladder" and a "track" view of the same data, with progress shown from the browser's saved task state.
- **Reading mode**: optional audio narration of lesson text (generated at build time, shipped as static files, off by default).
- **Practice exams** for popular certifications, as multiple-choice lessons graded in the browser.
- **Daily challenge**: one small task a day from the catalog, no account needed.
- **Failure-message review** (already on the list in `project-state.md`) before adding more content: wording drives retention.

## Rules for adding any of this
One lab per concept, proven both ways, no new binary in the base image without a size-budget reason, no network, no other product named.
