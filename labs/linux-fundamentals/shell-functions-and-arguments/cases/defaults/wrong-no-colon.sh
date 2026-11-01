printf '#!/bin/bash\nname="${1-friend}"\necho "${GREETING:-Hello}, $name!"\n' > welcome.sh
