cd "$HOME/proj"
git diff --no-ext-diff --no-color main feature -- app.conf > ../changes.diff
cat ../changes.diff
