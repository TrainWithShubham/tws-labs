#!/bin/bash
set -euo pipefail
chmod 0775 "$HOME/access/projects/backend" 2>/dev/null || true
sed -i 's/^deploy-agent:.*$/deploy-agent:guest/' "$HOME/access/config/group-membership.conf" 2>/dev/null || true
