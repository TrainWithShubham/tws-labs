printf '#!/bin/bash\necho "count=$#"\nwhile [ $# -gt 0 ]; do\n  echo "- $1"\n  shift\ndone\n' > args.sh
