# cwd: proj
set -eu
cd "$LAB_HOME/proj"
git merge feature >/dev/null 2>&1 || [ -f .git/MERGE_HEAD ]
printf '%s\n' 'PORT=8080 LOG_LEVEL=debug' > app.conf
git add app.conf
