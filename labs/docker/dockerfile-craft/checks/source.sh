. "$LAB_LIB"
. "$(dirname "$0")/_df.sh"
[ -f app/Dockerfile ] || fail "No app/Dockerfile yet - create it inside the app folder."
df_load app/Dockerfile
inst=$(df_n "$RE_INSTALL")
[ -n "$inst" ] || fail "Install the dependencies first (RUN npm ci), then copy the source after it."
# any COPY after the install that brings in something other than the package files (and not from another build stage)
src=$(printf '%s\n' "$DFL" | awk -v inst="$inst" 'NR > inst && /^copy / && !/--from=/ {
  l = $0; sub(/^copy( --[^ ]+)* /, "", l); n = split(l, a, " ")
  for (i = 1; i < n; i++) if (a[i] !~ /package[^ ]*\.json$/) { print NR; exit } }')
[ -n "$src" ] || fail "Copy the rest of the source after the install step, so editing code does not redo the install."
