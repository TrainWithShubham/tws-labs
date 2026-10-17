set -eu
git init -q -b main proj
cd proj
git config merge.conflictStyle merge
git config rerere.enabled false
printf '%s\n' 'PORT=3000 LOG_LEVEL=info' > app.conf
git add app.conf
git commit -q -m "Add application configuration"
git branch feature
printf '%s\n' 'PORT=8080 LOG_LEVEL=info' > app.conf
git commit -q -am "Change application port"
git tag main-start
git switch -q feature
printf '%s\n' 'PORT=3000 LOG_LEVEL=debug' > app.conf
git commit -q -am "Enable debug logging"
git tag feature-start
git switch -q main
