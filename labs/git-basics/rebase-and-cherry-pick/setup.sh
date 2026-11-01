export GIT_AUTHOR_NAME="Ada Dev" GIT_AUTHOR_EMAIL="ada@example.com" GIT_COMMITTER_NAME="Ada Dev" GIT_COMMITTER_EMAIL="ada@example.com"
n=0
commit() {
  n=$((n + 1))
  GIT_AUTHOR_DATE="2026-01-$(printf '%02d' $n)T10:00:00Z" GIT_COMMITTER_DATE="2026-01-$(printf '%02d' $n)T10:00:00Z" git commit -q -m "$1"
}
commit_a() { git add -A; commit "$1"; }
git init -q -b main proj
cd proj
printf '# Shop\n' > README.md
git add README.md
commit "Add README"
printf 'catalog\n' > app.txt
printf 'cart: items\n' > cart.txt
git add app.txt cart.txt
commit "Add app and cart"
git branch feature
git branch hotfix
git branch release
git switch -q hotfix
printf 'Welcome to the shop\n' > banner.txt
git add banner.txt
commit "Fix typo in banner"
printf 'cart: items, empty-cart guard\n' > cart.txt
git add cart.txt
commit "Fix crash on empty cart"
printf 'debug=on\n' > debug.txt
git add debug.txt
commit "Add debug logging"
git switch -q release
printf '1.0\n' > release.txt
git add release.txt
commit "Prepare release 1.0"
git switch -q feature
printf 'login form\n' > login.txt
git add login.txt
commit "Add login form"
printf 'validation\n' > validation.txt
git add validation.txt
commit "Add login validation"
git switch -q main
printf 'v1.0 notes\n' > CHANGELOG.txt
git add CHANGELOG.txt
commit "Add changelog"
git switch -q -c search
printf 'box\n' > search.txt
git add search.txt
commit "Add search box"
printf 'box\nindex\n' > search.txt
commit_a "WIP"
printf 'box\nindex\nresults\n' > search.txt
commit_a "WIP again"
git switch -q feature
