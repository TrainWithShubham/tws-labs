INC_DIR="${LAB_HOME:-$HOME}/lnx-ch-050/incident"
(
  cd "$INC_DIR"
  ./bin/ip route add default via 10.0.1.1 dev eth0
)
