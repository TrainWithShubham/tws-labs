printf '%s\n' '#!/bin/bash' 'n=3' 'while [ $n -gt 0 ]; do echo $n; n=$((n-1)); done' 'echo Liftoff!' > countdown.sh
