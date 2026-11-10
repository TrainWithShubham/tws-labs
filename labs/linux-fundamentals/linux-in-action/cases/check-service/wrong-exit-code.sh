printf '%s\n' '#!/bin/bash' 'check() {' '  if [ "$#" -ne 1 ]; then echo "Usage: check-service <config>" >&2; exit 0; fi' '  if [ ! -e "$1" ] || [ ! -s "$1" ]; then echo "CONFIG ERROR"; echo "Error: file missing or empty" >&2; exit 2; fi' '  echo "CONFIG OK"' '  exit 0' '}' 'check "$@"' > bin/check-service
chmod +x bin/check-service
