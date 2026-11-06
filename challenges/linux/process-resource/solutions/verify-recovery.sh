BASE="${LAB_HOME:-$HOME}"
sed -i 's/WORKER_MODE=runaway/WORKER_MODE=standard/' "$BASE/incident/config/worker.env"
sed -i 's/BATCH_CONCURRENCY=16/BATCH_CONCURRENCY=2/' "$BASE/incident/config/worker.env"
sed -i 's/MAX_MEMORY_MB=2048/MAX_MEMORY_MB=512/' "$BASE/incident/config/worker.env"
(cd "$BASE/incident" && ./bin/report-worker --queue=reports --start)
(cd "$BASE/incident" && ./bin/audit-processes)
