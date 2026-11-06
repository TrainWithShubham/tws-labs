sed -i 's/WORKER_MODE=runaway/WORKER_MODE=standard/' "$HOME/incident/config/worker.env"
sed -i 's/BATCH_CONCURRENCY=16/BATCH_CONCURRENCY=2/' "$HOME/incident/config/worker.env"
sed -i 's/MAX_MEMORY_MB=2048/MAX_MEMORY_MB=512/' "$HOME/incident/config/worker.env"
(cd "$HOME/incident" && ./bin/report-worker --queue=reports --start)
