# Release notes

What changed in each version of TWS Labs, newest first. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and versions follow [Semantic Versioning](https://semver.org/): a new lab or feature is a minor version, a fix is a patch, and anything
that needs action from you (a new image, a changed setting, a Terraform apply) is called out under **Upgrade notes**.

To see what you are running, check `version` in `package.json`. Self-hosters: `git pull && ./start_local_labs.sh` rebuilds the image when it changed.

## [Unreleased]

### Added
- **Terraform learning track**: a new hands-on track of five labs (*Your First Terraform Project*, *Providers and Resources*, *Variables, Outputs and References*, *State and Remote Backends*, and the integrated *Terraform in Action* practice lab), teaching declarative HCL syntax, provider configuration, resource definitions, input variables, outputs, resource references, state inspection, and native S3 remote locking. Contributed by Prakhar Srivastava, [@Heyyprakhar1](https://github.com/Heyyprakhar1), #71.
- **Git and GitHub: stashing uncommitted work** (`git stash`, `git stash list`, `git stash pop`): save in-progress changes, ship a hotfix on `main`, then restore them. Contributed by Sanket Dangat, [@srdangat](https://github.com/srdangat), #69.
- **GitHub Actions: multi-environment CI/CD with reusable workflows** (`workflow_call` inputs and secrets, calling a workflow with `uses:` and `with:`, staging to production with `needs:`). Contributed by Sanket Dangat, [@srdangat](https://github.com/srdangat), #70.
- **Linux Fundamentals: production incident triage**: find and stop a runaway process, truncate a runaway log without breaking its open file, lock down a world-writable credentials file, then start the service. Contributed by Preetham Pereira, [@cloudwithpreetham](https://github.com/cloudwithpreetham), #67.
- **Git and GitHub: resolving merge conflicts** (read conflict markers, resolve `app.conf`, stage it, complete the merge): the conflict a teammate's branch leaves behind, fixed by hand. Contributed by Rakesh Patra, [@Rakesh-Patra](https://github.com/Rakesh-Patra), #68.
- **Python for DevOps: automating with Python** (the first lab of a new Python track; the topic goes live on the AI line): read a log and count by level, summarise it as JSON, take a command-line argument, and archive big files with `gzip`. Every script is graded by running it against a log it has not seen.

### Changed
- **Python 3 is now in the lab image** (Debian's `python3`, about 55 MB, standard library only: no `pip`), so labs can teach scripting for operations. The image budget in `image-size-budget.json` rises from 520 MB to 540 MB for it (the CI image is 520 MB with it; about 20 MB of headroom is kept on purpose). `PYTHONDONTWRITEBYTECODE` is set so learners' folders do not fill with `__pycache__`.

### Upgrade notes
- Self-hosters: `git pull && ./start_local_labs.sh` rebuilds the image once (about 55 MB larger). Nothing in `deploy/` changes.

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
