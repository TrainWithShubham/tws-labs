printf '#!/bin/bash\nhas_content() {\n  [ -s "$1" ]\n}\nif has_content "$1"; then\n  echo ok\n  exit 0\nfi\necho "empty or missing"\nexit 3\n' > nonempty.sh
bash nonempty.sh notes.txt
bash nonempty.sh nothing.txt
