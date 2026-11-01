printf '#!/bin/bash\nif [ "$#" -ne 2 ]; then\n  echo "Usage: copy.sh SOURCE DEST" >&2\n  exit 0\nfi\ncp -- "$1" "$2"\n' > copy.sh
