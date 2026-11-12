# Release notes

What changed in each version of TWS Labs, newest first. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and versions follow [Semantic Versioning](https://semver.org/): a new lab or feature is a minor version, a fix is a patch, and anything
that needs action from you (a new image, a changed setting, a Terraform apply) is called out under **Upgrade notes**.

To see what you are running, check `version` in `package.json`. Self-hosters: `git pull && ./start_local_labs.sh` rebuilds the image when it changed.

## [Unreleased]

## [1.5.0] - 2026-11-12

### Highlights
- **AWS labs with no AWS account.** Start the labs with `EMULATOR=1 ./start_local_labs.sh` and four new AWS labs (S3, DynamoDB, SQS and SNS, CloudFormation) run the real `aws` CLI against AWS's own local emulator: no account, no keys, no cost, nothing to clean up.
- **Proven in CI, unlike labs on your own account.** A new CI job runs every emulator lab against the real emulator (each check fails before its solution and passes after, near misses fail, valid alternatives pass, every task works when skipped to) and plays each one through the UI in real Chrome.
- **Honest about what an emulator is.** Each lab says what the emulator models and what only real AWS enforces (IAM permissions for users and roles), and the page tells you plainly when the emulator is not running.
- **Two fixes for every AWS lab:** `aws s3 cp` no longer aborts in the lab terminal, and checks that wait for AWS get 30 seconds instead of 5.

### Added
- **AWS labs with no AWS account (new: the AWS Emulator).** `EMULATOR=1 ./start_local_labs.sh` starts the labs with AWS's own local emulator beside them, and labs marked `requires: emulator` run the real AWS CLI against it: no account, no keys, no cost, nothing to clean up. Emulator labs, unlike account labs, are proven fail-before and pass-after by the validator. Local only; the hosted site shows them as a read-only walkthrough. See `docs/emulator-labs.md`.
- **AWS: S3 storage in practice** (the first emulator lab): a bucket, uploads under a prefix, versioning and overwriting, a lifecycle rule and a bucket policy, graded on the emulator's state.
- **AWS: DynamoDB tables and queries**: a partition and sort key with on-demand billing, a batch write, a query by key, a conditional update that is safe to repeat, and TTL.
- **AWS: queues and topics with SQS and SNS**: a queue with a dead-letter queue and redrive policy, send, receive and delete, a topic and a subscription, and the queue policy without which a publish succeeds while nothing arrives.
- **AWS: your first CloudFormation stack**: add a queue to a template, create the stack, read an output, update it through the template (and see why changing it by hand is drift), and delete it.

### Changed
- **The track page tags AWS labs** that run on the AWS Emulator ("AWS Emulator", no account needed) or on your own account, and an emulator lab's terminal tab reads "Terminal · AWS Emulator". Plain labs are unchanged.
- **The README is reorganised**: current highlights first with earlier releases folded away, a "Start here" table that covers the whole catalog, one comparison of the two ways to practise AWS, and the missing community credits.
- **Checks in labs that use AWS or the emulator get 30 seconds** instead of 5 (`src/lab-env.js`): the CLI starts slowly and resources take a moment to settle.

### Fixed
- **`aws s3 cp` (and `sync`) aborted inside the lab terminal** with "Fatal error ... awscrt": the CLI's transfer library needs more than the 1 GiB address-space cap the lab shell applies. The AWS overlay now allows 3 GiB (memory is still bounded by the container).

### Upgrade notes
- Nothing is needed to keep running as before. To try emulator labs, run `EMULATOR=1 ./start_local_labs.sh`: the first run builds a large image (about 1.6 GB: the emulator package is about 900 MB installed), and the AWS CLI image gains four service models (DynamoDB, SQS, SNS, CloudFormation).
- If you use `AWS=1`, the overlay now raises the lab shell's address-space cap to 3 GiB.

## [1.4.0] - 2026-11-10

### Highlights
- **Eleven labs and two new tracks.** Kubernetes grows by five labs (labels and selectors, probes and rolling updates, Ingress, Jobs and CronJobs, namespaces) on top of persistent storage, and the catalog gains **Helm** and **GitOps** tracks, Git rebase and cherry-pick, shell functions and arguments, and a Python JSON config and CLI lab.
- **Linux in Action is now an operations capstone**: a six-task incident scenario at the end of the Linux Fundamentals track.
- **Honest budget wording** for the hosted deployment: the default is $50, and the alerts only email.

### Fixed
- **The budget guardrail's description no longer says the default is $5.** The default has been $50 since #33; the variable description, `deploy/README.md` and a comment in `budget.tf` now say so, give the measured cost of an always-on Cluster Mode environment (about $9.9/day), and state that the alerts only send email. No behaviour changes and no Terraform apply is needed. An automatic shutdown at the limit is still open in #28. Reported by [@Dhinesh-0309](https://github.com/Dhinesh-0309), #28.

### Added
- **Linux Fundamentals: *Linux in Action* is now an operations capstone** (it moves to the end of the track): repair a payment service's staging environment by pulling HTTP 500s out of a log with `awk`, generating its environment file with `sed`, locking down the token, stopping the worker and its stale lock, writing a `check-service` script with functions, arguments and exit codes, and starting the service. Graded on real state, with near-miss and valid-alternative cases and skip-ahead setups for every task. Contributed by Prakhar Srivastava, [@Heyyprakhar1](https://github.com/Heyyprakhar1), #87.
- **Kubernetes: namespaces** (logical partitioning, scoping workloads with `metadata.namespace`, Namespace-scoped Services and service discovery, reusing resource names across environments, and repairing cluster-scoped vs namespaced resources): organize cluster workloads and isolate service discovery without a running cluster. Contributed by Sanket Dangat, [@srdangat](https://github.com/srdangat), #88.
- **Kubernetes: persistent storage** (PersistentVolumes, PersistentVolumeClaims, volume attachment, container mount paths, and why a claim stays `Pending`): configure durable storage for stateful workloads without a running cluster. Contributed by Sanket Dangat, [@srdangat](https://github.com/srdangat), #82.
- **Kubernetes** (now more labs on the track): *Labels, selectors and ReplicaSets* (find the selector that does not match, adopt a stray Pod), *Probes and rolling updates* (readiness, liveness and startup probes, `maxUnavailable` and `maxSurge`, requests and limits), *Routing traffic with Ingress* (host and path rules, path types, TLS, a backend that points at nothing) and *Jobs and CronJobs* (completions and parallelism, a Job's restart policy, cron schedules, history limits).
- **Helm** (a new track): *Your first Helm chart*: `Chart.yaml`, `values.yaml`, a templated Deployment and a per-environment values file, graded by reading the chart files (the image has no `helm` binary, and the lab says so).
- **GitOps** (a new track): *Your first GitOps Application*: an Argo CD `Application` with source, destination and an automated sync policy (prune and self-heal), then a drifted manifest to repair. Graded offline on the manifest.
- **Git and GitHub: rebase and cherry-pick**: replay a feature branch onto an updated `main`, copy one fix to a release branch, and squash work-in-progress commits, all graded on real git state.
- **Linux Fundamentals: shell functions and arguments**: a function, positional parameters, `${VAR:-default}`, a usage message and exit codes, graded by running your script on inputs it has not seen.
- **Python for DevOps: JSON config and a CLI**: load and validate a JSON config, parse arguments with `argparse`, merge per-environment overrides and write the result, graded by running your script against configs it has not seen.
- `docs/lab-plan.md`: where the catalog is thin, the next labs, and platform ideas that need a decision.

### Changed
- Dependency updates: `js-yaml` 5.5.0, `puppeteer-core` 25.16.0 and the `hashicorp/tls` Terraform provider 4.4.2.

### Upgrade notes
- Self-hosters: `git pull && ./start_local_labs.sh` rebuilds the image once. Only lab content changed; the engine and the image are otherwise as in 1.3.0.
- Running Terraform in `deploy/infra`? Run `terraform init -upgrade` once to pick up `hashicorp/tls` 4.4.2 (a lock-file bump). Nothing needs applying and no resource changes.

## [1.3.0] - 2026-10-21

### Highlights
- **Eleven new labs.** A Terraform track of five, the first Python lab and the first AI lab, plus stashing, reusable workflows, incident triage and merge conflicts. Nine of them were written by the community: see the credits below.
- **The AI line starts, with no GPU and no key.** *Your first agent loop* teaches what a language model, a tool call and an agent loop are by building one against a scripted stand-in model that runs on your machine, and says plainly what a stand-in can and cannot teach.
- **Python is now in the image** (standard library only, about 55 MB, budget 540 MB), so labs can teach scripting.
- **A hardening pass from a whole-repo review.** One odd request could stop the server, a stalled browser tab could exhaust its memory, another page on `localhost` could open a shell, a crafted lab link could run script, and the AWS learner role could be used to gain account admin. All fixed; see Fixed and the Upgrade notes.
- **Commands you complete with Tab or recall with the arrow keys now count** in tasks that check what you ran.

### Added
- **AI agents: your first agent loop** (a new AI-agents track, and the first AI lab): learn what a language model, a tool call and an agent loop are by building one in Python against a scripted stand-in model that runs on your machine, so it needs no GPU, network or key. The lab says plainly what a stand-in can and cannot teach.
- **Terraform learning track**: a new hands-on track of five labs (*Your First Terraform Project*, *Providers and Resources*, *Variables, Outputs and References*, *State and Remote Backends*, and the integrated *Terraform in Action* practice lab), teaching declarative HCL syntax, provider configuration, resource definitions, input variables, outputs, resource references, state inspection, and native S3 remote locking. Contributed by Prakhar Srivastava, [@Heyyprakhar1](https://github.com/Heyyprakhar1), #71.
- **Git and GitHub: stashing uncommitted work** (`git stash`, `git stash list`, `git stash pop`): save in-progress changes, ship a hotfix on `main`, then restore them. Contributed by Sanket Dangat, [@srdangat](https://github.com/srdangat), #69.
- **GitHub Actions: multi-environment CI/CD with reusable workflows** (`workflow_call` inputs and secrets, calling a workflow with `uses:` and `with:`, staging to production with `needs:`). Contributed by Sanket Dangat, [@srdangat](https://github.com/srdangat), #70.
- **Linux Fundamentals: production incident triage**: find and stop a runaway process, truncate a runaway log without breaking its open file, lock down a world-writable credentials file, then start the service. Contributed by Preetham Pereira, [@cloudwithpreetham](https://github.com/cloudwithpreetham), #67.
- **Git and GitHub: resolving merge conflicts** (read conflict markers, resolve `app.conf`, stage it, complete the merge): the conflict a teammate's branch leaves behind, fixed by hand. Contributed by Rakesh Patra, [@Rakesh-Patra](https://github.com/Rakesh-Patra), #68.
- **Python for DevOps: automating with Python** (the first lab of a new Python track; the topic goes live on the AI line): read a log and count by level, summarise it as JSON, take a command-line argument, and archive big files with `gzip`. Every script is graded by running it against a log it has not seen.

### Fixed
- **A command you completed with Tab or recalled with the arrow keys now counts.** Tasks that check which command you ran missed commands built that way (`cat docs/rea` + Tab was logged as `cat docs/rea`). The shell now reports each command exactly as it ran it.
- **AWS labs: Check no longer fails silently on a slow connection.** Account-lab checks get 30 seconds instead of 5, and a check that does run out of time now says so instead of showing an empty message.
- **AWS labs: the cleanup check needs a real cleanup.** It passed when the bucket had never existed (for example after skipping ahead). It now also requires that you deleted it, and says so if AWS cannot confirm either way (a permissions problem is no longer read as "gone").
- **`scripts/aws-lab-sweep.sh` no longer reports a clean account when an AWS call failed.** A failed listing now stops it with the reason.
- **`scripts/aws-lab-creds.sh --duration` matches the learner role.** The role issues sessions of up to 4 hours; the script and docs allowed 12 and then failed with a misleading message.
- **`AWS=1 ./start_local_labs.sh` works with the legacy `docker-compose`** (the image pre-build skipped the compose fallback).
- **The AWS learner role could be used to gain account admin.** `deploy/learner-role.yaml` let it create roles and policies under `/tws-labs/` with any content, then assume them. No lab needs this, so those permissions are gone (it keeps read-only IAM). Update the CloudFormation stack to apply it; see Upgrade notes.
- **A crafted lab link could run script on the completion screen.** The finish page built resource links without escaping them. They are escaped now, and a link containing a quote, angle bracket or space is refused when the lab is loaded.
- **Links with underscores or stars in the URL rendered wrongly.** `[docs](https://example.com/_static_/a.html)` had its URL turned into emphasis markup; the URL is now kept as written.
- **One odd request could stop the whole server.** A request target such as `//` made the handler throw and the process exit, ending every learner's session. Any target now gets an answer.
- **A stalled browser tab could exhaust the server's memory.** Output from a command like `yes` piled up without limit while the tab was not reading (about 50 MB a second in a test). The server now stops reading the terminal until the browser catches up, as a real terminal does.
- **Another page on `localhost` could open a shell.** The local app accepted a request from any loopback port; it now requires its own origin, port included. A native `npm start` in the local profile also now listens on `127.0.0.1` only (set `HOST` to change it); Docker is unchanged.

### Changed
- **Python 3 is now in the lab image** (Debian's `python3`, about 55 MB, standard library only: no `pip`), so labs can teach scripting for operations. The image budget in `image-size-budget.json` rises from 520 MB to 540 MB for it (the CI image is 520 MB with it; about 20 MB of headroom is kept on purpose). `PYTHONDONTWRITEBYTECODE` is set so learners' folders do not fill with `__pycache__`.

### Upgrade notes
- Self-hosters: `git pull && ./start_local_labs.sh` rebuilds the image once (about 55 MB larger). Nothing in `deploy/` changes.
- Using the AWS labs? Update your `tws-labs-learner` CloudFormation stack with the new `deploy/learner-role.yaml` (*Update stack -> Replace current template*): the role loses its IAM write permissions. Existing stacks keep the old, broader role until you do.
- Running the local profile natively (`LAB_PROFILE=local npm start`)? It now binds `127.0.0.1`; set `HOST=0.0.0.0` if you really want other machines to reach it (a shell is on offer, so rarely).

## [1.2.0] - 2026-10-15

### Highlights
- **Skip never dead-ends, and every miss tells you what to do next.** Skipping ahead sets up the files the next task needs; a command you typed but did not run is called out; hints come in tiers; a button restarts the lab with fresh files; and when a session ends you are told why.
- **Kubernetes is a track of four labs**, and **AWS gets its first lab on your own account**: real `aws` commands against a free-tier footprint you clean up yourself, with a least-privilege role and a budget alarm.
- **Four labs from the community** (awk and sed, process management, Kubernetes Services, `.gitignore`), plus artifacts and caching: see the credits below.
- **Every check is now proven both ways.** About 370 near-miss and valid-alternative cases across the 27 offline labs, a play-through of every lab over the real server path, and browser tests in real Chrome. That found, and fixed, eight checks that were too lax or too strict.
- **Accessible and calmer**: AA contrast, visible keyboard focus, a skip link, no keyboard trap in the terminal.
- **For teams that self-host**: opt-in usage counters and a token-protected `/admin/stats` (with the hardest tasks), per-audience invite codes with a rotation runbook.

### Added
- **Labs**
  - **Kubernetes** (now a live topic on the DevOps line, with a cross-link to Cloud): *Pod and Deployment anatomy* (Contributed by Preetham Pereira, [@cloudwithpreetham](https://github.com/cloudwithpreetham), #35), *Exposing Pods with Services* (Sanket Dangat, [@srdangat](https://github.com/srdangat), #42), *ConfigMaps and Secrets* and *Fix the broken manifest*.
  - **AWS CLI first steps**: the first lab on your own AWS account (identity, an S3 bucket, tags, versioning, `--query`, cleanup). Needs the AWS overlay (`AWS=1 ./start_local_labs.sh`, see `docs/aws-labs.md`).
  - **Git and GitHub: ignoring files with `.gitignore`** (Sanket Dangat, #27) and **GitHub Actions: artifacts and caching** (Preetham Pereira, #26).
  - **Linux Fundamentals: text processing with `awk` and `sed`** (Sanket Dangat, #32) and **process management** (`ps`, `top`, background jobs, `kill` and `kill -9`; Muhammad Ishaq, [@techwithiishaq](https://github.com/techwithiishaq), #45).
- **A better lab page**
  - **Skip never dead-ends.** If you skip or jump to a task that needs files from an earlier one, the lab sets up what it needs (and moves your shell to the right folder), and tells you.
  - **Hints in tiers**: a "Need a hint?" button reveals up to three, gentle to specific, after a failed Check.
  - **Restart lab**: a fresh session with fresh starting files and a clean command history, after a second click to confirm. Your "done before" marks stay.
  - **Task progress** is remembered in your browser: a track page shows "3 of 5 tasks" for a lab you started, and the step dots show which tasks you passed on an earlier visit. Nothing leaves your browser.
- **Self-hosting and teams**
  - **Usage counters** (opt-in, `USAGE_STATS=1`): sessions per lab, distinct visitors per day, task pass/fail and sessions per invite code, with no IP address or invite code stored. Read them at `/admin/stats` with an `ADMIN_TOKEN`, or from the `usage` log lines. The page also lists the **hardest tasks**.
  - **AWS overlay** for labs that use your own AWS account: `AWS=1 ./start_local_labs.sh` builds an image with the AWS CLI v2 (trimmed to the services the labs use, about +170 MB, only with `AWS=1`) and passes your `AWS_*` variables to those labs only. Includes `deploy/learner-role.yaml` (a least-privilege role and a $5 budget alarm, for your own account), `scripts/aws-lab-creds.sh` (one-hour credentials, so no long-lived keys) and `scripts/aws-lab-sweep.sh` (delete leftovers; a dry run by default). Guide: `docs/aws-labs.md`.
  - A runbook for giving each audience its own invite code and rotating one (`deploy/README.md`).
- **For lab authors**
  - **Near-miss cases**: `cases/<task>/` scripts (wrong answers the check must reject, `ok-` alternatives it must accept), proven by `validate-labs`.
  - **Setup for skipping ahead**: `setup/<task>.sh` (with `# cwd:` and `# no-skip:` lines); `validate-labs` proves every task is solvable after skipping ahead.
  - `lab.yaml` can say `requires: aws`, and `hint` can be a list of tiers.
  - `npm run lab:lint` gives advice: tasks without a success message, checks that only read the typed history, hints that repeat the answer or are too short, labs over 15 minutes, tasks without a near-miss case. It never fails a build; `--notes` lists them.
  - **Real-browser tests** (`npm run e2e`, Chrome via puppeteer-core as a dev dependency): a learner's whole journey, hints, Restart, Skip, accessibility with axe-core, and the hosted profile (invite code, seat cap, idle and time-limit ends, two tabs, a server restart). CI runs them and keeps the screenshots.
  - CI plays **every offline lab through the real WebSocket server path**, fails when the image outgrows its size budget (`image-size-budget.json`, 520 MB) and builds the AWS overlay.
  - The `server.js` request handler is split into a router, route modules, guards and the terminal (no behaviour change).

### Changed
- **Kubernetes now sits on the DevOps line** (with a cross-link to Cloud), since its labs are manifest practice that needs no cluster. The home map allows seven topics per line and its orbit draws all seven.
- The learner shell has full `vim` (syntax highlighting; `vi` opens it) and working `man` with the standard manual pages. The image grows by about 80 MB uncompressed.
- The README pitch now says "every **offline** task proven solvable by a script": account labs are proven on a real account, not in CI.
- A failed Check's button reads "Check again" instead of an error-like label.

### Fixed
- **A command you typed but did not run** is noticed: a failed Check says "You have a command typed but not run yet. Press Enter", and the keyboard goes back to the terminal so Enter works at once.
- **When a session ends you are told why**, in plain words (idle, time limit, you typed `exit`, the connection dropped or the server restarted), with "Press Restart lab to start again", instead of `[session ended: 4000]`. The countdown no longer keeps a stale value, and waiting-for-a-seat messages wrap at word boundaries.
- **Italics** (`*word*`, `_word_`) in lab text render as emphasis instead of showing the asterisks; step buttons no longer wrap into two lines.
- **Accessibility**: faint text meets the WCAG AA contrast ratio on the dark theme; keyboard focus shows a thin ring everywhere, with a skip link and a `main` landmark; `Shift+Tab` leaves the terminal (Tab still goes to the shell); the logo no longer reads twice to screen readers.
- **Checks that were too lax or too strict**, found by the new cases: Navigating (`cat readme.txt` from the wrong folder passed), Files (extra lines passed "exactly"), Shell scripting (a single-quoted `$NAME` passed), Services (omitting `type` was rejected), Process management (`pkill` and `kill -KILL` were rejected), Dockerfile craft (copying only the app file was rejected), GitHub Actions (an empty `name:` passed; an `exclude` by one key was rejected), Ports and sockets (typing the expected error by hand passed).
- The lab page stops polling `/session/remaining` once the session ends. Reported by Preetham Pereira (#36).
- Track pages carry `data-track` on their wrapper, which the progress script needs (#38, #39), and the roadmap loader's station link no longer has two identical branches (#40, #41). Both reported and fixed by Preetham Pereira.
- The HTTP tests no longer hardcode how many topics are live, so a topic's first lab goes live without a test edit. Reported by Preetham Pereira (#30).
- `LAB_IDLE_SEC` and `LAB_HARD_CAP_SEC` (testing knobs, seconds) next to the minute settings.

### Upgrade notes
- **Local:** rebuild the image once (`./start_local_labs.sh` does it for you). No settings changed. To try the AWS lab: set up the role (`docs/aws-labs.md`) and start with `AWS=1`.
- **Hosted:** the image changed, so the next push to `main` redeploys it through `deploy.yml`. No Terraform changes. The hosted app now sets `USAGE_STATS=1`; its `usage` lines appear in the application log group. Optional repo secrets: `ADMIN_TOKEN` (turns on `/admin/stats`) and `USAGE_SALT` (consistent visitor counts across replicas); neither is required.
- **New, optional files:** `docker-compose.aws.yml` and `Dockerfile.aws` (the AWS overlay). The default image is unchanged in purpose and stays under the 520 MB CI budget.
- **Authors:** `npm ci` now also installs `puppeteer-core` and `axe-core` (dev only, not in the image) for `npm run e2e`.

## [1.1.0] - 2026-10-06

### Highlights
- **Nine new labs on three new topics.** Docker, Networking and CI/CD with GitHub Actions are now live (19 labs in 6 tracks).
- **A passing Check now says so.** You get a short green confirmation, and failing checks keep the amber hint.

### Added
- **Docker** (3 labs): containers are just processes, writing a Dockerfile that builds fast, and layers, secrets and compose.
  There is no Docker daemon in the sandbox; the labs grade the files you write and real evidence from the sandbox itself.
- **Networking** (3 labs): IP addresses and CIDR, ports and sockets, and name to page (DNS, the Host header, TLS). Each session gets its own port,
  so two learners never collide.
- **CI/CD with GitHub Actions** (3 labs): workflow anatomy, jobs, matrix and secrets, and OIDC to AWS.
- Optional `success:` text on a lab step, shown in green when its check passes (see `docs/authoring.md`).
- Check-script helpers in `labs/lib.sh`: `listening`, `http_code` and `yaml_get`.
- A new README: demo GIF, badges, a "Start here" table by goal, and a route table. `npm run readme:stats` regenerates the lab and task counts
  and the route table from the real catalog; a unit test fails if the README is stale.
- A 1280x640 social preview image (`docs/media/social-preview.png`).

### Changed
- The image now includes `jq`, `dig` (dnsutils), `ss` (iproute2), `nc` (netcat-openbsd) and `openssl`.
- Docker, Networking and CI/CD with GitHub Actions moved from "next" to live on the roadmap and the home map.

### Upgrade notes
- **Local:** rebuild the image once (`./start_local_labs.sh` does it for you). No settings changed.
- **Hosted:** the image changed, so the next push to `main` redeploys it through `deploy.yml`. No Terraform changes. The new labs were run end to end on the hosted
  profile after deploy (see `deploy/CHECKLIST.md`). The Networking labs use `bash`, `nc` and `openssl` servers rather than `node`, because learner shells run under the hosted address-space cap.

## [1.0.0] - 2026-10-01

First public release: Linux fundamentals, shell scripting, Git basics and the Elastic Beanstalk Cluster Mode lab, one lab server for
local (`docker compose up`) and hosted (Elastic Beanstalk Cluster Mode) use, MIT licensed.
