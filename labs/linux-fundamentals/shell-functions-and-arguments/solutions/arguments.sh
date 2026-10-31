printf '#!/bin/bash\necho "count=$#"\nfor a in "$@"; do\n  echo "- $a"\ndone\n' > args.sh
bash args.sh one "two words"
