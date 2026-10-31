printf '#!/bin/bash\nif [ $# != 2 ]; then\n  echo "usage: copy.sh SOURCE DEST"\n  exit 2\nfi\ncp -- "$1" "$2"\n' > copy.sh
