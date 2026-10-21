# A week of service logs to automate: one line per event, "date time LEVEL service: message".
mkdir -p logs
levels=(INFO INFO INFO WARN INFO ERROR INFO INFO WARN INFO)
services=(auth payments search auth payments)
for i in $(seq 1 48); do
  lv=${levels[$((i % 10))]}
  sv=${services[$((i % 5))]}
  if [ "$lv" = INFO ] && [ $((i % 7)) = 0 ]; then msg="recovered from ERROR state"; else msg="request handled in $((i * 13 % 90 + 10)) ms"; fi
  printf '2026-10-01 09:%02d:%02d %s %s: %s\n' $((i / 4)) $(((i % 4) * 15)) "$lv" "$sv" "$msg"
done > logs/app.log
for i in $(seq 1 70); do printf '10.0.0.%d GET /api/items/%d 200 %d\n' $((i % 9 + 1)) "$i" $((i * 37 % 900 + 100)); done > logs/access.log
printf 'cache warmed\nworker 1 started\nworker 2 started\n' > logs/debug.log
