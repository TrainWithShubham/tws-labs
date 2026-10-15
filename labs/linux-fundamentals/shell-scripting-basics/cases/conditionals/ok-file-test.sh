printf '%s\n' '#!/bin/bash' 'if [ -f "$1" ]; then echo exists; else echo missing; fi' > exists.sh
