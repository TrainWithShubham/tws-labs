printf '#!/bin/bash\n[ -s "$1" ] && { echo ok; exit 0; }\necho "empty or missing"\nexit 3\n' > nonempty.sh
