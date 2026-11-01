printf '#!/bin/bash\nname="${1:-friend}"\ngreeting="${GREETING:-Hello}"\necho "$greeting, $name!"\n' > welcome.sh
bash welcome.sh
GREETING=Hi bash welcome.sh Bob
