git switch search
git reset --soft "$(git merge-base main search)"
git commit -m "Add search"
