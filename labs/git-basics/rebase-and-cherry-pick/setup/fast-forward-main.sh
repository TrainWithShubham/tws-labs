#!/bin/bash
# Starting state if you skipped ahead. Safe to run again: rebases feature only when it is not already on main.
# cwd: proj
cd proj
git merge-base --is-ancestor main feature || git rebase -q main feature
