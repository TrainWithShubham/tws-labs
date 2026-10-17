# cwd: proj
set -eu
cd "$LAB_HOME/proj"
git merge feature >/dev/null 2>&1 || [ -f .git/MERGE_HEAD ]
