printf '#!/bin/bash\nname=$1\nif [ -z "$name" ]; then\n  name=friend\nfi\necho "${GREETING:-Hello}, $name!"\n' > welcome.sh
