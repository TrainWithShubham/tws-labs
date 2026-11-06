INC_DIR="${LAB_HOME:-$HOME}/lnx-ch-050/incident"
# Candidate action: learner inspected status but added no route
cd "$INC_DIR"
./bin/ip route >/dev/null
