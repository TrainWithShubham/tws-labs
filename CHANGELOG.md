# Release notes

What changed in each version of TWS Labs, newest first. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and versions follow [Semantic Versioning](https://semver.org/): a new lab or feature is a minor version, a fix is a patch, and anything
that needs action from you (a new image, a changed setting, a Terraform apply) is called out under **Upgrade notes**.

To see what you are running, check `version` in `package.json`. Self-hosters: `git pull && ./start_local_labs.sh` rebuilds the image when it changed.

## [Unreleased]

### Added
- **Near-miss cases for labs**: authors can add `cases/<task>/` scripts (wrong answers the check must reject, `ok-` alternatives it must accept) and `validate-labs` proves them. Every offline lab now has them: about 370 cases across 27 labs.
- **Git and GitHub: ignoring files with `.gitignore`**, a lab on ignore rules, `git check-ignore` and untracking a committed file with `git rm --cached`. Contributed by Sanket Dangat ([@srdangat](https://github.com/srdangat), #27).
- **GitHub Actions: artifacts and caching**, a lab on `actions/cache`, artifacts between jobs and `if: always()`. Contributed by Preetham Pereira ([@cloudwithpreetham](https://github.com/cloudwithpreetham), #26).
- **Kubernetes** is now a live topic with its first lab, **Pod and Deployment anatomy**: Pod specs, resource requests and limits, liveness probes and Deployments. Contributed by Preetham Pereira ([@cloudwithpreetham](https://github.com/cloudwithpreetham), #35).
- **Linux Fundamentals: text processing with `awk` and `sed`**, a lab on extracting and filtering log columns and rewriting or masking text in a stream. Contributed by Sanket Dangat ([@srdangat](https://github.com/srdangat), #32).
- **Kubernetes: exposing Pods with Services**, a lab on ClusterIP Services, label selectors and `port`/`targetPort`. Contributed by Sanket Dangat ([@srdangat](https://github.com/srdangat), #42).
- **Usage counters** (opt-in): sessions per lab, distinct visitors per day, and task pass/fail per lab, with no IP address or invite code stored. Read them at `/admin/stats` with an `ADMIN_TOKEN`, or from the `usage` log lines. Off by default for self-hosters (`USAGE_STATS=1`); on for the hosted deployment.
- **Task progress** is remembered in your browser: a track page shows "3 of 5 tasks" for a lab you started, and the lab's step dots show which tasks you passed on an earlier visit. The terminal still starts fresh each time, so earlier tasks are marked, not restored. Nothing leaves your browser.
- A runbook for giving each audience its own invite code and rotating one (`deploy/README.md`).
- **Linux Fundamentals: process management** (`ps`, `top`, background jobs, `kill` and `kill -9`). Contributed by Muhammad Ishaq ([@techwithiishaq](https://github.com/techwithiishaq), #45).
- `npm run lab:lint` now gives advice on labs: tasks without a success message, checks that only read the typed history, hints that repeat the answer or are too short, and labs over 15 minutes. It never fails a build; `--notes` lists them all.
- **Hints in tiers.** A task's `hint` in `lab.yaml` can be a list of up to three, gentle to specific. After a failed Check a "Need a hint?" button reveals them one at a time. A single hint works as before.
- **Restart lab** button: starts a fresh session with fresh starting files and a clean command history, after a second click to confirm. Your "done before" marks stay.
- `/admin/stats` lists the **hardest tasks**: the lowest pass rates over at least 5 graded attempts, so vague tasks and unfair checks stand out.
- **Kubernetes: two new labs.** *ConfigMaps and Secrets* (settings as env vars and files, base64 Secrets, `secretKeyRef`) and *Fix the broken manifest* (a removed API version, a selector that matches nothing, an unpinned image, a wrong `targetPort`).
- **Labs can say `requires: aws`** (for lab authors): such a lab uses the learner's own AWS account, so it opens as a read-only walkthrough on the hosted site (which never asks for AWS keys) and runs only on a learner's own machine, where their AWS variables are passed to the shell and checks for these labs only. The offline validator skips them. First account labs follow.
- **AWS overlay for labs that use your own AWS account**: `AWS=1 ./start_local_labs.sh` builds an image with the AWS CLI v2 (trimmed to the services the labs use, about +190 MB, only with `AWS=1`) and passes your `AWS_*` variables to those labs only. Includes `deploy/learner-role.yaml` (a least-privilege role and a $5 budget alarm, for your own account) and `scripts/aws-lab-creds.sh` (one-hour credentials, so no long-lived keys). Guide: `docs/aws-labs.md`.
- **AWS: AWS CLI first steps**, the first lab that runs on your own AWS account (identity, an S3 bucket, tags, versioning, `--query`, cleanup). Needs the AWS overlay (`AWS=1 ./start_local_labs.sh`, see `docs/aws-labs.md`); also adds `scripts/aws-lab-sweep.sh` to delete leftovers (dry run by default).

### Changed
- **Kubernetes now sits on the DevOps line** (with a cross-link to Cloud), since its labs are manifest practice that needs no cluster. The home map allows seven topics per line.
- The learner shell now has full `vim` (syntax highlighting; `vi` opens it) and working `man` with the standard manual pages (`man ls`, `man 5 hosts`, `man 7 signal`).
  The image grows by about 80 MB uncompressed, mostly the `vim` runtime files (36 MB) and the manual pages.

### Fixed
- **Accessibility**: faint text (labels, notes, tags) now meets the WCAG AA contrast ratio on the dark theme; keyboard focus shows a thin ring everywhere, with a skip link to the content and a `main` landmark; `Shift+Tab` leaves the terminal, so a keyboard user is never trapped in it (Tab still goes to the shell); the logo no longer reads twice to screen readers. A browser test (axe-core) now keeps every page type free of serious violations.
- **Checks that were too lax or too strict, found by the new near-miss cases:** Navigating (`cat readme.txt` from the wrong folder passed), Files (extra lines passed "exactly"), Shell scripting (a single-quoted `$NAME` passed), Services (omitting `type` was rejected despite the message saying it is allowed), Process management (`pkill` and `kill -KILL` were rejected), Dockerfile craft (copying only the app file was rejected), GitHub Actions (an empty `name:` passed; an `exclude` by one key was rejected), Ports and sockets (typing the expected error by hand passed).
- **A command you typed but did not run** is now noticed: a failed Check says "You have a command typed but not run yet. Press Enter", and the keyboard goes back to the terminal so Enter works at once.
- **Italics** (`*word*`, `_word_`) in lab text render as emphasis instead of showing the asterisks.
- **Step buttons no longer wrap** into two lines ("Another / hint"); the Check button reads "Check again" after a miss instead of an error-like label.
- The HTTP tests no longer hardcode how many topics are live or have a "Practice" link, so a topic's first lab goes live without a test edit. Reported by Preetham Pereira ([@cloudwithpreetham](https://github.com/cloudwithpreetham), #30).
- The lab page stops polling `/session/remaining` once the session ends (terminal closed, time ran out or End lab). Reported by Preetham Pereira ([@cloudwithpreetham](https://github.com/cloudwithpreetham), #36).
- Track pages now carry `data-track` on their wrapper, which the progress script needs to draw each track's completion. Reported and fixed by Preetham Pereira ([@cloudwithpreetham](https://github.com/cloudwithpreetham), #38, #39).
- The roadmap loader's station link no longer has two identical branches. Reported and fixed by Preetham Pereira ([@cloudwithpreetham](https://github.com/cloudwithpreetham), #40, #41).

### Upgrade notes
- New, optional: `docker-compose.aws.yml` and `Dockerfile.aws` (the AWS overlay). The default image, the hosted deployment and Terraform are unchanged.
- Optional repo secrets `ADMIN_TOKEN` (turns on `/admin/stats`) and `USAGE_SALT` (consistent visitor counts across replicas). `deploy.yml` passes both to `03-deploy.sh`; neither is required. The hosted app now sets `USAGE_STATS=1`.
- The runtime image changed, so the next push to `main` redeploys it through `deploy.yml`. No Terraform or settings changes.

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
