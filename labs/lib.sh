# Helpers for lab check scripts. Source it first:   . "$LAB_LIB"
#
# Environment provided by the server (and by `npm run lab:validate`):
#   LAB_HOME        the learner's home directory (also $HOME, also the cwd)
#   LAB_SHELL_PID   pid of the learner's shell (also its Linux session id)
#   LAB_HISTORY     file with the learner's Enter-submitted command lines
#
# A check exits 0 to pass. Anything printed on its first line is shown to the
# learner when it fails - make it a useful nudge, never the answer.
# Prefer checking real state (files, git, processes). Use `ran` only when
# there is no state to inspect (e.g. "run ls -l").

fail() { echo "$*"; exit 1; }

# ran CMD : the learner ran CMD as a command (not merely typed the word in `echo CMD`)
ran() { grep -Eq "(^|[;&|(][[:space:]]*)$1([[:space:]]|\$|[;&|)])" "$LAB_HISTORY" 2>/dev/null; }

# ran_re REGEX : some submitted line matches the extended regex
ran_re() { grep -Eq -- "$1" "$LAB_HISTORY" 2>/dev/null; }

# file_has PATH REGEX : PATH exists and has a line matching REGEX
file_has() { [ -f "$1" ] && grep -Eq -- "$2" "$1"; }

# shell_cwd : the learner's shell's current directory right now
shell_cwd() { readlink "/proc/$LAB_SHELL_PID/cwd" 2>/dev/null; }

# proc_running NAME : a process called NAME is alive in the learner's shell session
# (zombies are already dead - waiting for their parent to reap them - so they do not count)
proc_running() { ps -s "$LAB_SHELL_PID" -o stat=,comm= 2>/dev/null | awk -v n="$1" '$1 !~ /^Z/ && $2 == n { f = 1 } END { exit !f }'; }

# in_repo DIR git-args... : run git inside $LAB_HOME/DIR
in_repo() { local d="$1"; shift; git -C "$LAB_HOME/$d" "$@"; }

# listening PORT : something is accepting TCP connections on PORT (IPv4 or IPv6, any address)
listening() { local h; h=$(printf '%04X' "$1"); awk -v h=":$h" '$4 == "0A" && $2 ~ h"$" { f = 1 } END { exit !f }' /proc/net/tcp /proc/net/tcp6 2>/dev/null; }

# http_code URL [curl-args...] : print the HTTP status code (000 if nothing answers within 2 seconds)
http_code() { local u="$1"; shift; curl -s -o /dev/null -m 2 -w '%{http_code}' "$@" "$u" 2>/dev/null; }

# yaml_get FILE EXPR : load FILE as YAML into `d`, print EXPR (JavaScript). Objects print as JSON; nothing prints if FILE is not valid YAML.
# YAML 1.1 reads a bare `on:` key as boolean true, so the trigger section is  d[true] || d.on
yaml_get() {
  node -e 'const y = require(process.argv[1] + "/node_modules/js-yaml"); const d = y.load(require("fs").readFileSync(process.argv[2], "utf8"));
    const r = new Function("d", "return (" + process.argv[3] + ")")(d); console.log(r !== null && typeof r === "object" ? JSON.stringify(r) : r);' \
    "${LAB_LIB%/labs/lib.sh}" "$1" "$2" 2>/dev/null
}

# --- Account labs (`requires: aws`): checks that read the learner's own AWS account. Keep them read-only. ---

# _timeout SECONDS CMD... : bound a call when `timeout` exists (it does in the image; some laptops lack it)
_timeout() { if command -v timeout >/dev/null 2>&1; then timeout "$@"; else shift; "$@"; fi; }

# aws_ready : call first in every account lab check. Fails with a friendly line if the AWS CLI is missing, the credentials are missing
# or expired, or they belong to the account root user. Never prints keys.
aws_ready() {
  command -v aws >/dev/null 2>&1 || fail "The aws command is not here: start the labs with  AWS=1 ./start_local_labs.sh  (see docs/aws-labs.md)."
  local arn
  arn=$(_timeout 20 aws sts get-caller-identity --query Arn --output text 2>/dev/null) ||
    fail "Your AWS credentials are missing or have expired. Get fresh ones and restart the labs: see docs/aws-labs.md."
  case "$arn" in
    *:root) fail "These are root user credentials. Use the tws-labs-learner role instead (docs/aws-labs.md)." ;;
  esac
}

# aws_account : print the 12-digit account id of the credentials in use
aws_account() { _timeout 20 aws sts get-caller-identity --query Account --output text 2>/dev/null; }

# aws_region_is REGION : the learner's configured region is REGION
aws_region_is() { [ -n "$1" ] && [ "${AWS_REGION:-${AWS_DEFAULT_REGION:-}}" = "$1" ]; }

# retry TRIES SECONDS CMD... : run CMD until it succeeds (AWS is eventually consistent); returns the last status
retry() {
  local _tries="$1" _secs="$2" _i=0 _rc=1   # underscore names: bash locals are dynamically scoped, so the command must not see ours
  shift 2
  while [ "$_i" -lt "$_tries" ]; do
    "$@" && return 0
    _rc=$?
    _i=$((_i + 1))
    [ "$_i" -lt "$_tries" ] && sleep "$_secs"
  done
  return "$_rc"
}
