INC_DIR="${LAB_HOME:-$HOME}/lnx-ch-050/incident"
cat << 'EOF' > "$INC_DIR/config/routes.conf"
10.0.1.0/24 dev eth0 proto kernel scope link src 10.0.1.10
10.0.2.53 via 10.0.1.1 dev eth0
default via 10.0.1.254 dev eth0
EOF
cp -f "$INC_DIR/config/routes.conf" "$INC_DIR/run/net/routes.state"
