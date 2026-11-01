printf '#!/bin/bash\nif [ -s "$1" ]; then\n  echo ok\n  exit 0\nfi\necho "empty or missing"\nexit 1\n' > nonempty.sh
