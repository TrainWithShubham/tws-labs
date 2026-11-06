printf '%s\n' 'CULPRIT_ENDPOINT=postgres-primary:5432' 'ERROR_SIGNATURE=NullPointer' 'ROOT_CAUSE=DOWNSTREAM_TIMEOUT' > "$HOME/incident/reports/root-cause.env"
