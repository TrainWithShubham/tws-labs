#!/usr/bin/env bash
# Start TWS Labs on this machine: ./start_local_labs.sh
# Works on macOS, Linux, and Windows (Git Bash or WSL). The only thing you need is Docker.
#   LABS_PORT=9090 ./start_local_labs.sh     use another port
#   NO_BROWSER=1   ./start_local_labs.sh     don't open the browser
#   AWS=1 ./start_local_labs.sh              run the labs that use YOUR AWS account (needs AWS_* in your shell; see docs/aws-labs.md)
#   ./start_local_labs.sh stop               stop and clean up
set -euo pipefail
cd "$(dirname "$0")"

PORT="${LABS_PORT:-8080}"
export LABS_PORT="$PORT"
URL="http://localhost:$PORT"
OS="$(uname -s)"

say()  { printf '\033[1m%s\033[0m\n' "$*"; }
fail() { printf '\033[31m%s\033[0m\n' "$*" >&2; exit 1; }

case "$OS" in
  Darwin) INSTALL="Install Docker Desktop: https://www.docker.com/products/docker-desktop/ (then open it once)." ;;
  MINGW*|MSYS*|CYGWIN*) INSTALL="Install Docker Desktop for Windows (WSL2 backend): https://www.docker.com/products/docker-desktop/ - start it, then run this again." ;;
  *) INSTALL="Install Docker Engine: https://docs.docker.com/engine/install/ (and make sure your user can run 'docker')." ;;
esac

command -v docker >/dev/null 2>&1 || fail "Docker is not installed. $INSTALL"

if ! docker info >/dev/null 2>&1; then
  # Tell "daemon is off" apart from "no permission" (a common Linux first-run snag).
  if docker info 2>&1 | grep -qi 'permission denied'; then
    fail "Docker is running but your user may not use it. Add yourself to the docker group, then log out and in again:
  sudo usermod -aG docker \$USER"
  fi
  fail "Docker is installed but not running. Start Docker Desktop (or the docker service) and run this again."
fi

# AWS=1 adds the AWS overlay (the CLI image, and your AWS_* variables passed into the labs that need them).
FILES=()
if [ -n "${AWS:-}" ]; then
  [ -n "${AWS_ACCESS_KEY_ID:-}" ] || fail "AWS=1 needs your AWS credentials in this shell (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and AWS_SESSION_TOKEN if temporary).
Short-lived ones are safest: see docs/aws-labs.md (scripts/aws-lab-creds.sh prints them)."
  FILES=(-f docker-compose.yml -f docker-compose.aws.yml)
fi

if docker compose version >/dev/null 2>&1; then
  compose() { docker compose ${FILES[@]+"${FILES[@]}"} "$@"; }
elif command -v docker-compose >/dev/null 2>&1; then
  compose() { docker-compose ${FILES[@]+"${FILES[@]}"} "$@"; }
else
  fail "Docker Compose is missing. Update Docker Desktop, or install the compose plugin: https://docs.docker.com/compose/install/"
fi

if [ "${1:-}" = "stop" ]; then
  compose down
  say "Stopped."
  exit 0
fi

# A tiny HTTP probe that needs no extra tools: curl, wget, or bash's own /dev/tcp.
up() {
  if command -v curl >/dev/null 2>&1; then curl -fs "$URL/healthz" >/dev/null 2>&1
  elif command -v wget >/dev/null 2>&1; then wget -q -O /dev/null "$URL/healthz" >/dev/null 2>&1
  else (exec 3<>"/dev/tcp/127.0.0.1/$PORT") 2>/dev/null
  fi
}

# Is something else already on the port? Our own running labs is fine (compose recreates it).
if up || (exec 3<>"/dev/tcp/127.0.0.1/$PORT") 2>/dev/null; then
  if ! compose ps -q 2>/dev/null | grep -q .; then
    fail "Port $PORT is already in use by another program. Try: LABS_PORT=9090 ./start_local_labs.sh"
  fi
fi

say "Building and starting TWS Labs (the first run takes a few minutes)..."
# The AWS image is built on top of the normal one, so build that first.
if [ -n "${AWS:-}" ]; then   # through compose(), so a machine with only the legacy docker-compose works too
  AWS_FILES=("${FILES[@]}"); FILES=(-f docker-compose.yml); compose build labs; FILES=("${AWS_FILES[@]}")
fi
compose up --build -d

stop() { echo; say "Stopping TWS Labs..."; compose down >/dev/null 2>&1 || true; exit 0; }
trap stop INT TERM

printf 'Waiting for the server'
ready=""
for _ in $(seq 1 90); do
  if up; then ready=1; break; fi
  printf '.'; sleep 1
done
echo
[ -n "$ready" ] || { compose logs --tail 40; fail "The server did not come up. Logs above."; }

say "TWS Labs is running at $URL   (Ctrl+C to stop)"

if [ -z "${NO_BROWSER:-}" ]; then
  case "$OS" in
    Darwin) open "$URL" || true ;;
    MINGW*|MSYS*|CYGWIN*) cmd.exe //c start "" "$URL" >/dev/null 2>&1 || start "" "$URL" >/dev/null 2>&1 || echo "Open $URL in your browser." ;;
    *)
      if command -v xdg-open >/dev/null 2>&1; then xdg-open "$URL" >/dev/null 2>&1 || echo "Open $URL in your browser."
      elif command -v wslview >/dev/null 2>&1; then wslview "$URL" || echo "Open $URL in your browser."
      else echo "Open $URL in your browser."; fi ;;
  esac
fi

compose logs -f --tail 0 labs
