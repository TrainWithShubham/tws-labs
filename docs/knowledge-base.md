# AWS Elastic Beanstalk — Deep Knowledge Base (2026 Re-Release)

> Research date: 2026-09-29. Sources: AWS Documentation MCP (`docs.aws.amazon.com/elasticbeanstalk`).
> **This is a fast-moving feature** — re-verify against live docs before publishing anything
> (see `CLAUDE.md` research workflow). Docs on the new mode were first indexed **2026-09-17**,
> i.e. 12 days before this research — you are genuinely early.

---

## 1. THE HEADLINE: Elastic Beanstalk just got its biggest architectural change since launch (2011)

On **September 17, 2026**, AWS shipped **Cluster Mode** for Elastic Beanstalk — officially
announced via the AWS News Blog post *"AWS Elastic Beanstalk introduces Cluster Mode"*
(`aws.amazon.com/blogs/aws/aws-elastic-beanstalk-introduces-cluster-mode/`).

**One-line pitch:** Elastic Beanstalk — the "push your code, we run it" PaaS AWS launched in
2011 for EC2 — now also runs your app on a **fully managed Amazon EKS cluster (via EKS Auto
Mode)**, with zero Kubernetes knowledge required. Same `create-application` / `create-environment`
API, same console, same CLI you already know — but the compute underneath can now be
**pooled, multi-tenant, container-native, and Kubernetes-powered** instead of one Auto Scaling
Group per app.

### Naming, to get straight (docs use both terms interchangeably depending on page)
- **Marketing / release-notes name:** "Cluster Mode"
- **Developer Guide / console name:** "Beanstalk Cluster" (as an environment **Tier**:
  `--tier Name=Cluster,Type=EKS`)
- The classic experience is now retroactively named **"Beanstalk Standard"** / "Standard Mode"
  to distinguish it.
- Content angle: **you can say "Elastic Beanstalk has two modes now: Standard and Cluster."**

### Why AWS did this (the pitch, per the announcement)
- Lower **per-application compute cost** as app count or scale grows — because Cluster Mode
  runs **multiple applications on pooled/shared infrastructure** instead of a dedicated
  fleet per app (huge for agencies, platform teams, and multi-tenant SaaS running dozens of
  small services).
- Event-driven autoscaling (KEDA-style triggers under the hood, exposed via Beanstalk's usual
  option-settings UX).
- OpenTelemetry-native observability out of the box.
- AWS Secrets Manager integration.
- HTTPS by default via AWS Certificate Manager, with **zero certificate configuration**.
- Ships with a **new official Elastic Beanstalk GitHub Action** for CI/CD, and **"agent skills"**
  — AWS published an agent-toolkit skill (`github.com/aws/agent-toolkit-for-aws` →
  `skills/core-skills/aws-containers/SKILL.md`) so that AI coding agents (Claude Code, Q, etc.)
  can deploy to Beanstalk Cluster directly. **This is notable and underreported** — AWS is
  explicitly designing this feature to be driven by AI agents, not just humans clicking a
  console. Great content angle: "AWS built this so your AI agent can deploy it for you."
- Compliance: available in **all commercial AWS Regions** where EB is offered; **HIPAA
  eligible**, in scope for **PCI DSS, SOC, FedRAMP, IRAP**. No additional Beanstalk charge —
  you pay only for underlying EKS + EKS Auto Mode + other AWS resources consumed.

---

## 2. Beanstalk Standard vs. Beanstalk Cluster — the real architectural diff

Both modes share: the same **Application**, **Application Version**, **Environment**, and
**configuration option** concepts/API surface. That's the magic trick — it doesn't feel like a
new product, it feels like a new environment *tier*.

| Aspect | Beanstalk Standard (classic) | Beanstalk Cluster (new) |
|---|---|---|
| Compute | Dedicated EC2 instances in a per-environment Auto Scaling Group | Containers scheduled onto a **shared** Amazon EKS cluster; nodes supplied by **EKS Auto Mode** |
| Scaling | ASG scaling via `aws:autoscaling:*` namespaces | Application **replica** count via `min-replica`/`max-replica` in `aws:elasticbeanstalk:eks:environment:autoscaling`; triggers: CPU, memory, cron schedule, or a custom metrics HTTP endpoint you expose |
| Deployment artifact | Source bundle run on a platform AMI ("solution stack") | A **container image** in Amazon ECR — either provided directly or built by EB from source via AWS CodeBuild |
| Platform concept | Managed solution stack (OS + web server + language runtime baked into an AMI) | No AMI/solution stack at all — runtime is just "whatever your container image says" |
| Deployment policy | All-at-once / rolling / immutable via `aws:elasticbeanstalk:command` | Rolling update (default) or all-at-once (`Recreate`) via `aws:elasticbeanstalk:eks:environment:deployment` `strategy` option |
| Config namespaces | Classic `aws:autoscaling:*`, `aws:elasticbeanstalk:environment`, etc. | Entirely new `aws:elasticbeanstalk:eks:*` namespace tree — classic compute namespaces **do not apply at all** |
| Health reporting | Per-instance health from host manager + load balancer | **No per-instance health.** Environment-level only, derived from ALB metrics (request rate / 4xx-5xx rate / latency) when `load-balancer-type=ALB`; not evaluated at all with `load-balancer-type=None` |
| IAM model | EC2 instance profile | Three roles you must provide: **cluster role**, **node role**, **observability role** (+ optional **application role** via EKS Pod Identity, + optional **image build role** for CodeBuild) |

### Key mental model for content
> "Beanstalk Standard is a butler who runs your app on a VM he manages for you.
> Beanstalk Cluster is a butler who runs your app in a Kubernetes cluster he manages for you —
> and you never have to learn `kubectl`."

---

## 3. How Cluster Mode actually works under the hood

### 3.1 Compute model
- EB creates and fully operates the **Amazon EKS cluster** itself (control plane, node
  provisioning via **EKS Auto Mode** — meaning EKS itself adds/removes worker nodes to fit
  scheduled pods; you never pick instance types or node counts).
- **Environments sharing the same VPC subnet set land on the same EKS cluster.** First
  environment on a given subnet set triggers cluster creation; subsequent environments on
  the same subnets are scheduled onto the *existing* cluster. This is the "pooled/shared
  infrastructure" cost story from the announcement — you can run 10 microservices on one EKS
  cluster instead of 10 separate EC2 fleets.
- You do **not** choose the Kubernetes version or manage the cluster directly — it's fully
  service-managed. If you (or Terraform, or anyone) drifts the cluster's config away from
  what EB expects, EB **stops scheduling new environments onto it** — it won't self-heal
  infra you've hand-modified.

### 3.2 Multi-tenancy model (two isolation boundaries, chosen at creation time, immutable after)
| Boundary | How to get it | What's shared |
|---|---|---|
| **Shared cluster** (soft multi-tenancy, default) | Environments created with the *same* subnet set | Cluster + nodes shared; network traffic between environments **blocked by default**; each env is logically partitioned |
| **Separate clusters** (hard multi-tenancy) | Environments created with *different* subnet sets | Nothing — fully separate control planes, nodes, no network path |

- **Network isolation is default-deny** between environments on a shared cluster — no config
  needed to get this, and there's no way to disable it globally. To *allow* cross-environment
  traffic, three new options exist:
  - `ingress-groups` — mutual (bidirectional) trust group; join multiple envs to the same
    named group and they can all call each other.
  - `ingress-allowlist-environments` — one-directional allow: name specific caller envs.
  - `ingress-allowlist-groups` — one-directional allow: permit an entire named group to call
    this env, without joining that group yourself.
  - These **combine**. Great content demo: build a 3-service app (frontend, api, worker) on
    one shared cluster, show them isolated by default, then wire them up with `ingress-groups`.
- `node-pool` option lets you reserve **dedicated nodes** for an environment even on a shared
  cluster — a middle ground between full sharing and full isolation.
- AWS explicitly frames the compliance angle: use **separate subnet sets / separate clusters**
  when workloads must not share infra — different end-customers, untrusted code, or a
  compliance regime requiring infra separation. Logical isolation on a shared cluster is
  **not** presented as equivalent to hard isolation — good nuance for a "should I trust this
  for multi-tenant SaaS" post.

### 3.3 IAM — four roles, name-matters
Roles are matched **by name**, not ARN, when using the console (auto-created if missing). Doing
it via CLI/API, you must create them yourself with these exact names/trust/policies:

| Role | Name | Trusts | Managed policies |
|---|---|---|---|
| Cluster role | `aws-elasticbeanstalk-eks-cluster-role` | `eks.amazonaws.com` | `AmazonEKSClusterPolicy`, `AmazonEKSNetworkingPolicy`, `AmazonEKSComputePolicy`, `AmazonEKSBlockStoragePolicy`, `AmazonEKSLoadBalancingPolicy`, `AWSElasticBeanstalkEKSTagging` |
| Node role | `aws-elasticbeanstalk-eks-node-role` | `ec2.amazonaws.com` | `AmazonEKSWorkerNodeMinimalPolicy`, `AmazonEC2ContainerRegistryPullOnly`, `AmazonSSMManagedInstanceCore` |
| Observability role | `aws-elasticbeanstalk-eks-observability-role` | `pods.eks.amazonaws.com` (EKS Pod Identity) | `CloudWatchAgentServerPolicy`, `AWSElasticBeanstalkEKSObservability` |
| Image build role (optional, source-build only) | `aws-elasticbeanstalk-eks-image-build-role` | `codebuild.amazonaws.com` | `AWSElasticBeanstalkEKSImageBuild` |
| Application role (optional) | your choice | `pods.eks.amazonaws.com` | whatever your app needs (least privilege) — attached via EKS Pod Identity, this is how your **running application** calls other AWS services |

- **Rule that will bite people:** every environment on the same cluster (i.e. same subnet set)
  **must supply the identical three roles**. EB rejects an environment that supplies different
  roles rather than silently placing it on a separate cluster — this is a sharp edge worth
  a "gotcha" post/short.

### 3.4 Deploying an application — three input shapes
Application Versions in Cluster Mode take an `ImageConfiguration` with **exactly one** of:
1. `Source` — a pre-built image URI (ECR, or any registry allowing unauthenticated pull). No
   build step; recorded `UNPROCESSED`, deploy-ready immediately.
2. `Build` — a `SourceBundle` (S3 zip) + build instructions; EB runs **AWS CodeBuild** to turn
   it into an image (Docker or buildpack build types) and pushes to ECR **in your account**.
   Requires `--process` to actually trigger the build.
- Rejects requests with both/neither, or that mix `ImageConfiguration` with the classic
  `BuildConfiguration` param (that one's for Standard-mode CodeBuild app versions — don't confuse
  the two in content).
- CodeBuild-based source builds require an AWS Region where **CodeBuild is available** — a
  regional caveat worth a callout.
- Deploying, tagging, version quotas: same mechanics as Standard mode.

### 3.5 Networking, HTTPS, and load balancing
- `subnets` option (namespace `aws:elasticbeanstalk:eks:environment`) — chooses where nodes run
  **and** which cluster you land on. **Set only at creation; cannot be changed later** — a
  big planning decision, good "plan your subnets before you start" content warning.
- `load-balancer-type`: `ALB` (default, creates + operates an ALB) or `None` (cluster-internal
  only, still reachable by other same-cluster environments via in-cluster DNS/address, but not
  from outside).
- **HTTPS is on by default with zero cert config** — EB auto-provisions an **ACM certificate**
  scoped to the environment's own CNAME domain, attaches + auto-renews it, deletes it on
  environment termination. Only HTTPS (443) is open by default — **plain HTTP times out**
  unless you explicitly add an HTTP listener + `ssl-redirect`. This "free HTTPS out of the box"
  detail is a strong, simple, visually demonstrable content hook (curl http:// hangs vs curl
  https:// just works, zero setup).
- Bring your own domain: supply `certificate-arn`; your cert rides alongside EB's own cert on
  the same listener.
- ALB fully configurable via `aws:elasticbeanstalk:eks:alb` namespace (subnets, scheme
  internet-facing/internal, security groups, custom listener ports as JSON).

### 3.6 Scaling model — KEDA-flavored, EB-simplified
- You size the **application** (replica count), not a fleet of instances — EKS Auto Mode
  handles node capacity to fit.
- `min-replica` / `max-replica` bound the range (`min-replica` floor is 1 — always at least one
  replica running, no true scale-to-zero).
- Default trigger (if none configured) = **CPU utilization**.
- Trigger types available via `aws:elasticbeanstalk:eks:environment:autoscaling:trigger`:
  - CPU (`cpu-metric-type` + `cpu-value`, `Utilization` % or `AverageValue` absolute)
  - Memory (same shape)
  - **Cron schedule** (`scaler-type=cron`, JSON `scaler-metadata` with timezone/start/end/
    desiredReplicas) — e.g. "run 5 replicas 8am-6pm weekdays UTC, drop to min-replica outside
    the window." Great demo for a "scale for business hours" post.
  - **Custom metric from your own HTTP endpoint** (`scaler-type=metrics-api`) — point EB at
    a URL + JSON path to a number (e.g. SQS queue depth, job count) and it scales replicas on
    that. This is basically **KEDA's metrics-api scaler exposed as an EB option** — confirms
    EKS/KEDA is genuinely under the hood, not just marketing.
  - `polling-interval` / `cooldown-period` tune responsiveness vs. thrashing.
- Deployment strategy: rolling (default) or `Recreate` (all-at-once, brief downtime, useful
  for apps that can't run two versions concurrently).

### 3.7 Observability — OpenTelemetry-native
- Default backends: metrics + logs → **CloudWatch**; traces → **none** unless configured.
- Optional backends: logs → S3; metrics → **Amazon Managed Service for Prometheus**; traces →
  **AWS X-Ray**; or **any OTel-compatible third-party backend** (Datadog, Honeycomb, Grafana
  Cloud, etc.) — genuinely open, not AWS-locked.
- **Auto-instrumentation with zero app code changes**: set `language` option to your runtime
  (Java, Node.js, Python, .NET supported) and EB injects an OTel auto-instrumentation agent
  into your container. For Java specifically, it also **bridges Log4j2/Logback/JUL** so
  existing app logs flow to the logs backend without touching app code — a strong "it just
  works" demo.
- 4 fixed CloudWatch log groups, **shared across every Cluster-mode environment in the
  account/region**, differentiated by log-stream naming (`eb-<env-name>.<pod-name>` for app
  logs, `<env-name>/<pod-name>` for app metrics — note the differing prefix convention):
  - `/aws/elasticbeanstalk/application/logs`
  - `/aws/elasticbeanstalk/application/metrics`
  - `/aws/elasticbeanstalk/infrastructure/logs`
  - `/aws/elasticbeanstalk/infrastructure/metrics`
  - **No retention policy set by default** — cost gotcha worth flagging (set retention yourself).
- Container probes (readiness/liveness/startup) configurable via
  `aws:elasticbeanstalk:eks:environment` probe namespaces — standard k8s concepts, EB-simplified
  config surface.
- **No per-instance health** (unlike Standard) — health is environment-level only, derived from
  ALB metrics (request rate, 4xx/5xx ratio, latency) when using an ALB; not evaluated at all
  with `load-balancer-type=None`. An idle environment reports Grey/NoData — not a failure signal.
- Separately, a **deployment log** (pod container logs + k8s events for that specific
  operation) is captured per environment operation — the first place to look when a deploy
  fails.

### 3.8 Limitations to always disclose (credibility / "the catch" content)
- **No persistent local storage** — ephemeral only, lost on replica restart. Apps writing
  uploads/caches/session files to local disk need external storage (S3, EFS, RDS, etc.) —
  classic "12-factor app" requirement now enforced by the platform.
- Requests are load-balanced across **stateless, identical, interchangeable replicas only**.
- First environment creation takes **15–20 minutes** (EKS cluster bootstrap) — the CLI waiter
  even documents that it'll report "Max attempts exceeded" on the first run and needs re-running;
  worth setting expectations vs. Standard mode's faster spin-up.
- Source-to-image builds require CodeBuild-supported regions.
- Pricing: **no extra Beanstalk charge**, but you now pay for EKS cluster + EKS Auto Mode
  compute + ALB + CloudWatch etc. — good "cost model changed, here's what to actually
  budget for" post.

### 3.9 Real pricing figures (sourced from AWS pricing pages, 2026-09-29 — reverify periodically)
- **EKS cluster control plane:** $0.10/hour (standard support) — $0.60/hour if on extended
  support for an old Kubernetes version. This is charged per cluster regardless of workload
  size, from creation until deletion.
- **EKS Auto Mode compute:** billed as **regular EC2 on-demand instance cost + an Auto Mode
  surcharge that varies by instance type** (AWS's own example: a `c6a.2xlarge` carries a
  `$0.03672`/hour surcharge on top of its normal EC2 price). There's no flat per-vCPU rate
  published — smaller instances carry proportionally smaller surcharges. For a minimal pod
  request (e.g. 0.25 vCPU / 512Mi), Auto Mode still launches a small node (roughly a 2 vCPU
  class instance, to cover its own system pod overhead) — budget on the order of **$0.02–0.04/hr
  total instance + surcharge** for the smallest realistic node.
- **Application Load Balancer:** $0.0225/hour base + $0.008/hour per LCU (Load Balancer
  Capacity Unit); a near-idle demo ALB uses well under 1 LCU, so treat ALB cost as roughly
  **$0.03/hr** for a lightly-trafficked demo.
- **Rough all-in estimate for the cheapest realistic "Hello Cluster Mode" configuration**
  (1 replica, minimal resource requests, default ALB, default VPC):
  **~$0.16–0.20/hour**, i.e. well under $1 for a 1-hour hands-on test including setup/teardown
  overhead. EKS control-plane fee dominates the estimate.
- **ACM certificate, CloudWatch at this scale:** effectively $0, aside from any CloudWatch log
  storage left ownerless past the test (set retention or delete log groups after teardown).
- **Measured (Cost Explorer, 1-20 Oct 2026, us-west-2):** about $153 gross for one always-on Cluster Mode environment, roughly $9.9/day, so a deployed demo costs far more than the hour-long estimate above. Terminating the environment is not enough: check for a leftover `beanstalk-cluster-*` stack (EKS control plane, about $2.40/day) and delete it too.
- This is an **estimate to validate, not a bill** — see the hands-on runbook in the
  `beanstalk-grows` demo for how the real Cost Explorer number was measured. Reverify these
  headline figures against `aws.amazon.com/eks/pricing` and
  `aws.amazon.com/elasticloadbalancing/pricing` before quoting them in new content, since AWS
  pricing pages change independently of the docs site.

---

## 4. Provisioning tooling / ecosystem hooks (great for "how to actually ship this" content)
- **AWS Console** — fully guided environment creation (auto-creates the 3 IAM roles by name).
- **AWS CLI / API** — `--tier Name=Cluster,Type=EKS` selects Cluster Mode on `create-environment`.
- **New official Elastic Beanstalk GitHub Action** — deploy straight from a repo as part of
  CI/CD (`deploying-github-actions.html` in the dev guide covers this — also applies to
  Standard mode).
- **Terraform** — the AWS provider supports defining Beanstalk environments as IaC, including
  the new EKS-based options (verify exact provider/resource version at time of writing — this
  is very new, may lag).
- **AWS "agent skills"** — AWS published a skill for AI coding agents:
  `github.com/aws/agent-toolkit-for-aws` → `skills/core-skills/aws-containers/SKILL.md`.
  **Strong, differentiated content angle**: demo an AI agent (Claude Code, Amazon Q, etc.)
  provisioning and deploying a Cluster Mode environment end-to-end using that skill — very few
  people will have shown this.

---

## 5. Content ideas backlog (update as pieces get published)

### High-priority / first-mover angles
1. **"AWS just brought Elastic Beanstalk back from the dead — with Kubernetes superpowers."**
   Announcement recap + why it matters, aimed at people who wrote EB off years ago.
2. **Live build: deploy a 3-service app to one shared EKS cluster via Beanstalk Cluster Mode,
   zero kubectl.** End-to-end CLI walkthrough (roles → app → environment → scaling → teardown).
3. **"The gotchas nobody will tell you about Beanstalk Cluster Mode"** — ephemeral storage,
   role-name matching, immutable subnets, HTTP timing out by default, first-boot 15–20 min wait.
4. **"Is this AWS answering simpler app platforms?"** — comparative framing, developer experience vs. control
   trade-offs, cost model breakdown (pooled infra = cheaper at scale).
5. **"I let an AI agent deploy to AWS Elastic Beanstalk Cluster Mode"** — using the official
   AWS agent-toolkit skill with Claude Code; strong differentiated YouTube/reel material.
6. **Carousel: "Beanstalk Standard vs Beanstalk Cluster in 8 slides"** — use the comparison
   table in §2 directly.
7. **Scaling deep-dive reel: "Your AWS app can now scale on literally anything"** — CPU, memory,
   cron schedule, or a custom /metrics endpoint (KEDA-style) — show all four live.
8. **"Zero-config HTTPS on AWS in one command"** — show curl timing out on http://, working
   instantly on https://, no cert requested/uploaded.
9. **Multi-tenancy explainer: soft vs hard isolation, and why choosing subnets is a one-way door.**
10. **Build-in-public app**: a small real SaaS/demo (e.g. a webhook relay, a Slack bot, a status
    page) shipped on Cluster Mode as a running GitHub demo repo, iterated over several posts.

### Ongoing maintenance
- Track weekly platform + relnotes updates (`relnotes.html`) — Windows/AL2023/AL2 platform
  patches ship almost every week; Cluster Mode itself is the standout event so far (2026-09-17).
- Re-run `mcp__aws-docs__recommend` against `beanstalk-cluster.html` periodically for **new**
  doc pages — this is how this research was found in the first place.
- Watch for the AWS News Blog post itself
  (`aws.amazon.com/blogs/aws/aws-elastic-beanstalk-introduces-cluster-mode/`) and any follow-up
  blog posts/webinars — good source of official diagrams/quotes to react to or cite.

---

## 6. Reference links (verify freshness before citing)
- Feature overview: `docs.aws.amazon.com/elasticbeanstalk/latest/dg/beanstalk-cluster.html`
- Architecture/diffs: `.../dg/beanstalk-cluster-concepts.html`
- Getting started tutorial: `.../dg/beanstalk-cluster-getting-started.html`
- Multi-tenancy: `.../dg/beanstalk-cluster-multi-tenancy.html`
- Networking: `.../dg/configuring-cluster-networking.html`
- Scaling: `.../dg/configuring-cluster-scaling.html`
- Monitoring: `.../dg/monitoring-cluster-environments.html`
- Permissions: `.../dg/beanstalk-cluster-permissions.html`
- Building images: `.../dg/beanstalk-cluster-app-versions.html`
- Official release note: `docs.aws.amazon.com/elasticbeanstalk/latest/relnotes/release-2026-09-17-cluster-mode.html`
- All release notes (weekly cadence): `docs.aws.amazon.com/elasticbeanstalk/latest/relnotes/relnotes.html`
- AWS News Blog announcement: `aws.amazon.com/blogs/aws/aws-elastic-beanstalk-introduces-cluster-mode/`
- Agent skill for AI-driven deploys: `github.com/aws/agent-toolkit-for-aws` →
  `skills/core-skills/aws-containers/SKILL.md`
