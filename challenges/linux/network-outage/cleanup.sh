#!/bin/bash
set -euo pipefail

# 1. Base Resolution Decision Sequence
SELECTED_BASE=""
if [ -n "${LAB_HOME:-}" ] && [ -d "$LAB_HOME" ]; then
  SELECTED_BASE="$LAB_HOME"
elif [ -n "${HOME:-}" ] && [ -d "$HOME" ]; then
  SELECTED_BASE="$HOME"
else
  echo "Fatal: Neither LAB_HOME nor HOME points to a valid existing directory." >&2
  exit 1
fi

CANONICAL_BASE="$(realpath -e "$SELECTED_BASE" 2>/dev/null)" || {
  echo "Fatal: Failed to resolve canonical base directory for: $SELECTED_BASE" >&2
  exit 1
}

case "$CANONICAL_BASE" in
  /|/home|/root|/tmp|/var|/usr|/bin|/etc)
    echo "Fatal: Base directory cannot be a top-level system mount: $CANONICAL_BASE" >&2
    exit 1
    ;;
esac

# 2. Workspace Safety Validation
WORKSPACE_DIR="$CANONICAL_BASE/lnx-ch-050"
if [ ! -e "$WORKSPACE_DIR" ]; then
  echo "Cleanup: Workspace $WORKSPACE_DIR does not exist. Nothing to clean."
  exit 0
fi

if [ -L "$WORKSPACE_DIR" ]; then
  echo "Fatal: $WORKSPACE_DIR is a symlink. Refusing to operate on symlinked workspace parent." >&2
  exit 1
fi

if [ ! -d "$WORKSPACE_DIR" ]; then
  echo "Fatal: $WORKSPACE_DIR exists but is not a directory." >&2
  exit 1
fi

INTENDED_ROOT="$WORKSPACE_DIR/incident"
if [ ! -e "$INTENDED_ROOT" ]; then
  rmdir "$WORKSPACE_DIR" 2>/dev/null || true
  echo "Cleanup: Incident root does not exist. Workspace cleaned."
  exit 0
fi

if [ -L "$INTENDED_ROOT" ]; then
  echo "Fatal: $INTENDED_ROOT is a symlink. Refusing to operate on symlinked challenge root." >&2
  exit 1
fi

if [ ! -d "$INTENDED_ROOT" ]; then
  echo "Fatal: $INTENDED_ROOT exists but is not a directory." >&2
  exit 1
fi

INCIDENT_ROOT="$(realpath -e "$INTENDED_ROOT" 2>/dev/null)" || {
  echo "Fatal: Failed to canonically resolve $INTENDED_ROOT." >&2
  exit 1
}

if [ "$(dirname "$INCIDENT_ROOT")" != "$CANONICAL_BASE/lnx-ch-050" ] || [ "$(basename "$INCIDENT_ROOT")" != "incident" ]; then
  echo "Fatal: INCIDENT_ROOT ($INCIDENT_ROOT) fails boundary verification." >&2
  exit 1
fi

# 3. Subdirectory Symlink Validation
for sub in bin config run run/net reports var var/log; do
  TARGET_PATH="$INCIDENT_ROOT/$sub"
  if [ -L "$TARGET_PATH" ]; then
    echo "Fatal: Subdirectory $TARGET_PATH is an unexpected symlink. Aborting cleanup." >&2
    exit 1
  fi
done

# 4. Safe Removal of Challenge-Owned Directory
rm -rf "$INCIDENT_ROOT"
rmdir "$WORKSPACE_DIR" 2>/dev/null || true

echo "Network outage incident workspace cleaned successfully."
exit 0
