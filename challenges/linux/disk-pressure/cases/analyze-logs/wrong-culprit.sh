printf '%s\n' 'CULPRIT_ENDPOINT=redis-cache:6379' 'ERROR_SIGNATURE=ConnectionRefused' 'ROOT_CAUSE=DOWNSTREAM_TIMEOUT' > "$HOME/incident/reports/root-cause.env"
