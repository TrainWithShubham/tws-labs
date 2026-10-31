git log --oneline hotfix
git switch release
git cherry-pick "$(git log hotfix --grep='Fix crash' --format=%h -1)"
