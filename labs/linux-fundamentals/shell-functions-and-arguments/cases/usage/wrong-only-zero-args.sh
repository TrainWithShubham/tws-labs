printf '#!/bin/bash\nif [ "$#" -eq 0 ]; then\n  echo "Usage: copy.sh SOURCE DEST" >&2\n  exit 1\nfi\ncp -- "$1" "$2"\n' > copy.sh
