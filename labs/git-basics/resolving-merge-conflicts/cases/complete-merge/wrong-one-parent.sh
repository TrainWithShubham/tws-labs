git merge --abort
printf '%s\n' 'PORT=8080 LOG_LEVEL=debug' > app.conf
git add app.conf
git commit -m "Copied settings without merging"
