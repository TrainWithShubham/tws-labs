printf '#!/bin/bash\nfor a in "$@"; do\n  echo "- $a"\ndone\n' > args.sh
