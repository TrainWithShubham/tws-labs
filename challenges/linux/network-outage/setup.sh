#!/bin/bash
set -euo pipefail

# 1. Base Resolution Decision Sequence
SELECTED_BASE=""
if [ -n "${LAB_HOME:-}" ] && [ -d "$LAB_HOME" ]; then
  SELECTED_BASE="$LAB_HOME"
elif [ -n "${HOME:-}" ] && [ -d "$HOME" ]; then
  SELECTED_BASE="$HOME"
else
  echo "Fatal: Neither LAB_HOME nor HOME points to a valid existing directory." >&2
  exit 1
fi

CANONICAL_BASE="$(realpath -e "$SELECTED_BASE" 2>/dev/null)" || {
  echo "Fatal: Failed to resolve canonical base directory for: $SELECTED_BASE" >&2
  exit 1
}

case "$CANONICAL_BASE" in
  /|/home|/root|/tmp|/var|/usr|/bin|/etc)
    echo "Fatal: Base directory cannot be a top-level system mount: $CANONICAL_BASE" >&2
    exit 1
    ;;
esac

# 2. Workspace Pre-Creation Safety Validation
WORKSPACE_DIR="$CANONICAL_BASE/lnx-ch-050"
INTENDED_ROOT="$WORKSPACE_DIR/incident"

if [ -e "$WORKSPACE_DIR" ]; then
  if [ -L "$WORKSPACE_DIR" ]; then
    echo "Fatal: $WORKSPACE_DIR is a symlink. Refusing to operate on symlinked workspace parent." >&2
    exit 1
  fi
  if [ ! -d "$WORKSPACE_DIR" ]; then
    echo "Fatal: $WORKSPACE_DIR exists but is not a directory." >&2
    exit 1
  fi
else
  mkdir -m 0755 "$WORKSPACE_DIR"
fi

if [ -e "$INTENDED_ROOT" ]; then
  if [ -L "$INTENDED_ROOT" ]; then
    echo "Fatal: $INTENDED_ROOT is a symlink. Refusing to operate on symlinked challenge root." >&2
    exit 1
  fi
  if [ ! -d "$INTENDED_ROOT" ]; then
    echo "Fatal: $INTENDED_ROOT exists but is not a directory." >&2
    exit 1
  fi
else
  mkdir -m 0755 "$INTENDED_ROOT"
fi

INCIDENT_ROOT="$(realpath -e "$INTENDED_ROOT" 2>/dev/null)" || {
  echo "Fatal: Failed to canonically resolve $INTENDED_ROOT." >&2
  exit 1
}

if [ "$(dirname "$INCIDENT_ROOT")" != "$CANONICAL_BASE/lnx-ch-050" ] || [ "$(basename "$INCIDENT_ROOT")" != "incident" ]; then
  echo "Fatal: INCIDENT_ROOT ($INCIDENT_ROOT) fails boundary verification." >&2
  exit 1
fi

# 3. Subdirectory Symlink Validation
for sub in bin config run run/net reports var var/log; do
  TARGET_PATH="$INCIDENT_ROOT/$sub"
  if [ -L "$TARGET_PATH" ]; then
    echo "Fatal: Subdirectory $TARGET_PATH is an unexpected symlink. Aborting." >&2
    exit 1
  fi
done

# 4. Idempotent Directory Reset
rm -rf "$INCIDENT_ROOT/run" "$INCIDENT_ROOT/reports" "$INCIDENT_ROOT/var"
mkdir -p "$INCIDENT_ROOT/bin" "$INCIDENT_ROOT/config" \
         "$INCIDENT_ROOT/run/net" "$INCIDENT_ROOT/reports" "$INCIDENT_ROOT/var/log"
chmod 0755 "$INCIDENT_ROOT/bin" "$INCIDENT_ROOT/config" \
           "$INCIDENT_ROOT/run/net" "$INCIDENT_ROOT/reports" "$INCIDENT_ROOT/var/log"

# 5. Provision Network Interface Configuration
cat << 'NET_EOF' > "$INCIDENT_ROOT/config/network.env"
# Local Client Network Interface Configuration (client-01)
HOSTNAME=client-01
INTERFACE=eth0
IPV4_ADDRESS=10.0.1.10
IPV4_NETMASK=255.255.255.0
IPV4_CIDR=24
IPV4_BROADCAST=10.0.1.255
MAC_ADDRESS=02:42:0a:00:01:0a
NET_EOF
chmod 0644 "$INCIDENT_ROOT/config/network.env"

# 6. Provision DNS Resolv Configuration
cat << 'RESOLV_EOF' > "$INCIDENT_ROOT/config/resolv.conf"
# Simulated internal resolver
nameserver 10.0.2.53
search internal.corp
RESOLV_EOF
chmod 0644 "$INCIDENT_ROOT/config/resolv.conf"

# 7. Provision Topology Metadata Definition
cat << 'TOPO_EOF' > "$INCIDENT_ROOT/config/topology.json"
{
  "nodes": {
    "client-01": {
      "ip": "10.0.1.10",
      "subnet": "10.0.1.0/24",
      "interface": "eth0"
    },
    "router-gw": {
      "interfaces": {
        "eth0": "10.0.1.1/24",
        "eth1": "10.0.2.1/24"
      }
    },
    "dns-internal": {
      "ip": "10.0.2.53",
      "subnet": "10.0.2.0/24",
      "port": 53,
      "hostname": "dns.internal.corp"
    },
    "app-api-01": {
      "ip": "10.0.2.100",
      "subnet": "10.0.2.0/24",
      "port": 8080,
      "hostname": "api.internal.corp"
    }
  }
}
TOPO_EOF
chmod 0644 "$INCIDENT_ROOT/config/topology.json"

# 8. Provision Initial Broken Routing Table (Missing default route and missing 10.0.2.0/24 route)
cat << 'ROUTES_EOF' > "$INCIDENT_ROOT/config/routes.conf"
10.0.1.0/24 dev eth0 proto kernel scope link src 10.0.1.10
10.0.2.53 via 10.0.1.1 dev eth0
ROUTES_EOF
chmod 0644 "$INCIDENT_ROOT/config/routes.conf"

cp -f "$INCIDENT_ROOT/config/routes.conf" "$INCIDENT_ROOT/run/net/routes.state"
chmod 0644 "$INCIDENT_ROOT/run/net/routes.state"

# 9. Provision Incident Telemetry Status
cat << 'STATUS_EOF' > "$INCIDENT_ROOT/reports/incident.status"
[INCIDENT TELEMETRY] 2026-11-05T10:15:00Z
SEVERITY: SEV-1 CRITICAL OUTAGE
DESCRIPTION: Payment frontend service cannot reach payment backend at api.internal.corp:8080.
SYMPTOMS OBSERVED:
  - Application connections to api.internal.corp fail immediately with network error.
  - Initial triage notes suspect DNS failure or backend server crash.
SIMULATION BOUNDARY:
  Controlled userland network simulation inside ~/lnx-ch-050/incident.
  No host interfaces, sockets, host network namespaces, or root permissions are used.
AVAILABLE COMMANDS:
  ./bin/netmap          - Interactive network topology and reachability explorer
  ./bin/ip addr         - Inspect local client IP addresses and network interfaces
  ./bin/ip route        - Inspect or manage client routing table
  ./bin/ping            - Test simulated ICMP reachability to remote hosts
  ./bin/traceroute      - Trace simulated hop-by-hop packet path to destination
  ./bin/getent hosts    - Query simulated internal DNS resolver
  ./bin/ss              - Inspect simulated client sockets
  ./bin/network-audit   - Verify end-to-end network recovery and record success marker
ACTION REQUIRED:
  1. Discover network topology and verify DNS resolution (reports/discovery.env).
  2. Trace packet journey to application target and observe failure (reports/packet-trace.env).
  3. Diagnose missing route root cause (reports/root-cause.env).
  4. Install missing route via ./bin/ip route add.
  5. Verify full end-to-end recovery via ./bin/network-audit.
STATUS_EOF
chmod 0644 "$INCIDENT_ROOT/reports/incident.status"

# 10. Provision Command: ./bin/netmap
cat << 'NETMAP_EOF' > "$INCIDENT_ROOT/bin/netmap"
#!/bin/bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$DIR")"
ROUTES="$ROOT/run/net/routes.state"
[ -f "$ROUTES" ] || ROUTES="$ROOT/config/routes.conf"

has_route_to_app() {
  local has_r=false
  while IFS= read -r line || [ -n "$line" ]; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    if echo "$line" | grep -Eq "^[[:space:]]*(default|0\.0\.0\.0/0|10\.0\.2\.0/24|10\.0\.2\.100(/32)?)[[:space:]]+via[[:space:]]+10\.0\.1\.1([[:space:]]|$)"; then
      if echo "$line" | grep -Eq "[[:space:]]+dev[[:space:]]+"; then
        if echo "$line" | grep -Eq "[[:space:]]+dev[[:space:]]+eth0([[:space:]]|$)"; then
          has_r=true
        fi
      else
        has_r=true
      fi
    fi
  done < "$ROUTES"
  [ "$has_r" = "true" ]
}

print_topology() {
  local app_status="UNREACHABLE (No route to 10.0.2.0/24)"
  if has_route_to_app; then
    app_status="REACHABLE via 10.0.1.1"
  fi

  cat << MAP_EOF
=== Network Topology Explorer (Simulated NetOps v1) ===
Local Node: [client-01] (10.0.1.10/24 on eth0)

[Subnet 10.0.1.0/24 - Client LAN]
  ├─ [client-01] 10.0.1.10 (Local Endpoint)
  └─ [router-gw] 10.0.1.1  (Gateway eth0) [REACHABLE]

[Router Gateway: router-gw]
  ├─ eth0: 10.0.1.1/24 (Client LAN)
  └─ eth1: 10.0.2.1/24 (Services LAN)
  └─ Forwarding: ENABLED

[Subnet 10.0.2.0/24 - Services LAN]
  ├─ [dns-internal] 10.0.2.53:53 (dns.internal.corp) [REACHABLE via 10.0.1.1]
  └─ [app-api-01]   10.0.2.100:8080 (api.internal.corp) [$app_status]

Active Client Routes:
$(sed 's/^/  /' "$ROUTES")
MAP_EOF
}

inspect_node() {
  local node="${1:-}"
  case "$node" in
    client-01|client|1)
      cat << 'NODE_EOF'
=== Node Inspector: client-01 ===
Role: Client / Operations Terminal
Primary Interface: eth0 (10.0.1.10/24)
MAC Address: 02:42:0a:00:01:0a
Gateway Required: 10.0.1.1
Configured DNS: 10.0.2.53 (in config/resolv.conf)
Status: LOCAL ENDPOINT (ACTIVE)
NODE_EOF
      ;;
    router-gw|gateway|router|2)
      cat << 'NODE_EOF'
=== Node Inspector: router-gw ===
Role: Dual-Homed Subnet Router / Gateway
Interfaces:
  eth0: 10.0.1.1/24 (Client Subnet)
  eth1: 10.0.2.1/24 (Services Subnet)
IP Forwarding: ENABLED (net.ipv4.ip_forward = 1)
Reachability from client-01: REACHABLE (Direct local subnet 10.0.1.0/24)
NODE_EOF
      ;;
    dns-internal|dns|3)
      cat << 'NODE_EOF'
=== Node Inspector: dns-internal ===
Role: Internal Domain Name Resolver (dns.internal.corp)
Interface: eth0 (10.0.2.53/24)
Listening Ports: 53/UDP, 53/TCP
Hosted Records:
  api.internal.corp -> 10.0.2.100
  db.internal.corp  -> 10.0.2.150
  dns.internal.corp -> 10.0.2.53
Reachability from client-01: REACHABLE (Static host route 10.0.2.53 via 10.0.1.1)
NODE_EOF
      ;;
    app-api-01|app|api|4)
      local st="UNREACHABLE (No route to 10.0.2.0/24 from client)"
      local nexthop="NONE (Dropped locally by client kernel routing)"
      if has_route_to_app; then
        st="REACHABLE (TCP/8080 ONLINE)"
        nexthop="10.0.1.1 (router-gw eth0)"
      fi
      cat << NODE_EOF
=== Node Inspector: app-api-01 ===
Role: Backend Payments API Server (api.internal.corp)
Interface: eth0 (10.0.2.100/24)
Listening Ports: 8080/TCP (HTTP Service: /health, /api/v1)
Next Hop from client: $nexthop
Status: $st
NODE_EOF
      ;;
    *)
      echo "Unknown node '$node'. Valid nodes: client-01, router-gw, dns-internal, app-api-01." >&2
      return 1
      ;;
  esac
}

probe_all() {
  echo "Probing simulated network nodes from client-01..."
  printf "%-18s %-15s %-8s %s\n" "NODE" "IP ADDRESS" "PORT" "STATUS"
  printf "%-18s %-15s %-8s %s\n" "------------------" "---------------" "--------" "-------------------------"
  printf "%-18s %-15s %-8s %s\n" "client-01" "10.0.1.10" "local" "ONLINE (Local host)"
  printf "%-18s %-15s %-8s %s\n" "router-gw" "10.0.1.1" "-" "ONLINE (Direct Subnet)"
  printf "%-18s %-15s %-8s %s\n" "dns-internal" "10.0.2.53" "53/udp" "ONLINE (Host Route)"
  if has_route_to_app; then
    printf "%-18s %-15s %-8s %s\n" "app-api-01" "10.0.2.100" "8080/tcp" "ONLINE (HTTP 200 OK)"
  else
    printf "%-18s %-15s %-8s %s\n" "app-api-01" "10.0.2.100" "8080/tcp" "UNREACHABLE (No route)"
  fi
}

run_interactive() {
  if [ ! -t 0 ] || [ ! -t 1 ]; then
    print_topology
    exit 0
  fi
  while true; do
    clear 2>/dev/null || true
    print_topology
    echo ""
    echo "Interactive Explorer Navigation:"
    echo "  [1] Inspect client-01      [2] Inspect router-gw"
    echo "  [3] Inspect dns-internal   [4] Inspect app-api-01"
    echo "  [p] Probe Reachability     [r] Refresh Topology"
    echo "  [q] Exit Explorer"
    echo ""
    read -r -p "Select option: " -n 1 opt || break
    echo ""
    case "$opt" in
      1) echo ""; inspect_node client-01; read -r -p "Press Enter to continue..." _ ;;
      2) echo ""; inspect_node router-gw; read -r -p "Press Enter to continue..." _ ;;
      3) echo ""; inspect_node dns-internal; read -r -p "Press Enter to continue..." _ ;;
      4) echo ""; inspect_node app-api-01; read -r -p "Press Enter to continue..." _ ;;
      p|P) echo ""; probe_all; read -r -p "Press Enter to continue..." _ ;;
      r|R) continue ;;
      q|Q) echo "Exiting explorer."; break ;;
      *) echo "Invalid option."; sleep 1 ;;
    esac
  done
}

ACTION="${1:-show}"
case "$ACTION" in
  show|map|"")
    print_topology
    ;;
  inspect)
    inspect_node "${2:-}"
    ;;
  probe)
    probe_all
    ;;
  -i|--interactive|interactive)
    run_interactive
    ;;
  *)
    echo "Usage: ./bin/netmap [show | inspect <node> | probe | -i]" >&2
    exit 1
    ;;
esac
NETMAP_EOF
chmod 0755 "$INCIDENT_ROOT/bin/netmap"

# 11. Provision Command: ./bin/ip
cat << 'IP_EOF' > "$INCIDENT_ROOT/bin/ip"
#!/bin/bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$DIR")"
ROUTES="$ROOT/run/net/routes.state"
CONFIG_ROUTES="$ROOT/config/routes.conf"

CMD="${1:-}"
shift || true

case "$CMD" in
  addr|a|address)
    SUBCMD="${1:-show}"
    shift || true
    cat << 'ADDR_OUT'
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 02:42:0a:00:01:0a brd ff:ff:ff:ff:ff:ff
    inet 10.0.1.10/24 brd 10.0.1.255 scope global eth0
       valid_lft forever preferred_lft forever
ADDR_OUT
    exit 0
    ;;

  route|r|ro)
    SUBCMD="${1:-show}"
    shift || true
    case "$SUBCMD" in
      show|list|ls|"")
        [ -f "$ROUTES" ] || cp -f "$CONFIG_ROUTES" "$ROUTES"
        cat "$ROUTES"
        exit 0
        ;;
      add)
        [ $# -gt 0 ] || { echo "Usage: ip route add <target> via <gateway> [dev <dev>]" >&2; exit 1; }
        TARGET="$1"
        shift
        GW=""
        DEV="eth0"

        while [ $# -gt 0 ]; do
          case "$1" in
            via)
              shift
              [ $# -gt 0 ] || { echo "Error: 'via' requires gateway address." >&2; exit 1; }
              GW="$1"
              ;;
            dev)
              shift
              [ $# -gt 0 ] || { echo "Error: 'dev' requires interface name." >&2; exit 1; }
              DEV="$1"
              ;;
            *)
              echo "Error: Unknown argument '$1'." >&2
              exit 1
              ;;
          esac
          shift || true
        done

        # Validate arguments strictly against command injection
        metachar_pattern='[\$\`&|;<>\!]'
        if [[ "$TARGET" =~ $metachar_pattern ]] || [[ "$GW" =~ $metachar_pattern ]] || [[ "$DEV" =~ $metachar_pattern ]]; then
          echo "Error: Illegal metacharacters in route specification." >&2
          exit 1
        fi

        if [ "$DEV" != "eth0" ]; then
          echo "Error: Device '$DEV' does not exist." >&2
          exit 1
        fi

        if [ "$GW" != "10.0.1.1" ]; then
          echo "Error: Nexthop gateway '$GW' is unreachable or invalid (expected 10.0.1.1 on eth0)." >&2
          exit 2
        fi

        case "$TARGET" in
          default|0.0.0.0/0)
            ENTRY="default via 10.0.1.1 dev eth0"
            ;;
          10.0.2.0/24)
            ENTRY="10.0.2.0/24 via 10.0.1.1 dev eth0"
            ;;
          10.0.2.100|10.0.2.100/32)
            ENTRY="10.0.2.100 via 10.0.1.1 dev eth0"
            ;;
          *)
            echo "Error: Invalid or unsupported route destination '$TARGET'." >&2
            exit 1
            ;;
        esac

        mkdir -p "$(dirname "$ROUTES")"
        [ -f "$ROUTES" ] || cp -f "$CONFIG_ROUTES" "$ROUTES"

        if grep -Fxq "$ENTRY" "$ROUTES" 2>/dev/null; then
          echo "RTNETLINK answers: File exists" >&2
          exit 2
        fi

        echo "$ENTRY" >> "$ROUTES"
        echo "$ENTRY" >> "$CONFIG_ROUTES"
        exit 0
        ;;
      del|delete)
        TARGET="${1:-}"
        [ -n "$TARGET" ] || { echo "Usage: ip route del <target>" >&2; exit 1; }
        if [ -f "$ROUTES" ]; then
          sed -i "/^[[:space:]]*${TARGET//\//\\/}[[:space:]]/d" "$ROUTES"
          sed -i "/^[[:space:]]*${TARGET//\//\\/}[[:space:]]/d" "$CONFIG_ROUTES"
        fi
        exit 0
        ;;
      *)
        echo "Error: Unsupported ip route command '$SUBCMD'." >&2
        exit 1
        ;;
    esac
    ;;

  *)
    echo "Usage: ./bin/ip {addr|route} ..." >&2
    exit 1
    ;;
esac
IP_EOF
chmod 0755 "$INCIDENT_ROOT/bin/ip"

# 12. Provision Command: ./bin/ping
cat << 'PING_EOF' > "$INCIDENT_ROOT/bin/ping"
#!/bin/bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$DIR")"
ROUTES="$ROOT/run/net/routes.state"
[ -f "$ROUTES" ] || ROUTES="$ROOT/config/routes.conf"

COUNT=2
TARGET=""

while [ $# -gt 0 ]; do
  case "$1" in
    -c)
      shift
      [ $# -gt 0 ] || { echo "ping: option requires an argument -- 'c'" >&2; exit 1; }
      COUNT="$1"
      ;;
    -*)
      # Ignore other flags
      ;;
    *)
      TARGET="$1"
      ;;
  esac
  shift || true
done

[ -n "$TARGET" ] || { echo "Usage: ./bin/ping [-c count] destination" >&2; exit 1; }

# Hostname resolution
case "$TARGET" in
  api.internal.corp)
    IP="10.0.2.100"
    ;;
  dns.internal.corp)
    IP="10.0.2.53"
    ;;
  router-gw.internal.corp)
    IP="10.0.1.1"
    ;;
  client-01.internal.corp)
    IP="10.0.1.10"
    ;;
  *)
    IP="$TARGET"
    ;;
esac

# Check route table reachability
is_reachable=false
if [ "$IP" = "127.0.0.1" ] || [ "$IP" = "10.0.1.10" ] || [ "$IP" = "10.0.1.1" ]; then
  is_reachable=true
elif [ "$IP" = "10.0.2.53" ] || [ "$IP" = "10.0.2.100" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    if [ "$IP" = "10.0.2.53" ] && echo "$line" | grep -Eq "^[[:space:]]*(10\.0\.2\.53|10\.0\.2\.0/24|default|0\.0\.0\.0/0)[[:space:]]+via[[:space:]]+10\.0\.1\.1([[:space:]]|$)"; then
      if echo "$line" | grep -Eq "[[:space:]]+dev[[:space:]]+"; then
        if echo "$line" | grep -Eq "[[:space:]]+dev[[:space:]]+eth0([[:space:]]|$)"; then
          is_reachable=true
        fi
      else
        is_reachable=true
      fi
    elif [ "$IP" = "10.0.2.100" ] && echo "$line" | grep -Eq "^[[:space:]]*(10\.0\.2\.100(/32)?|10\.0\.2\.0/24|default|0\.0\.0\.0/0)[[:space:]]+via[[:space:]]+10\.0\.1\.1([[:space:]]|$)"; then
      if echo "$line" | grep -Eq "[[:space:]]+dev[[:space:]]+"; then
        if echo "$line" | grep -Eq "[[:space:]]+dev[[:space:]]+eth0([[:space:]]|$)"; then
          is_reachable=true
        fi
      else
        is_reachable=true
      fi
    fi
  done < "$ROUTES"
fi

if [ "$is_reachable" = "false" ]; then
  echo "connect: Network is unreachable" >&2
  exit 2
fi

echo "PING $TARGET ($IP) 56(84) bytes of data."
for ((i=1; i<=COUNT; i++)); do
  echo "64 bytes from $IP: icmp_seq=$i ttl=63 time=0.4$((RANDOM % 50 + 10)) ms"
done
echo "--- $TARGET ping statistics ---"
echo "$COUNT packets transmitted, $COUNT received, 0% packet loss, time 1001ms"
exit 0
PING_EOF
chmod 0755 "$INCIDENT_ROOT/bin/ping"

# 13. Provision Command: ./bin/traceroute
cat << 'TRACE_EOF' > "$INCIDENT_ROOT/bin/traceroute"
#!/bin/bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$DIR")"
ROUTES="$ROOT/run/net/routes.state"
[ -f "$ROUTES" ] || ROUTES="$ROOT/config/routes.conf"

TARGET="${1:-}"
[ -n "$TARGET" ] || { echo "Usage: ./bin/traceroute destination" >&2; exit 1; }

case "$TARGET" in
  api.internal.corp) IP="10.0.2.100" ;;
  dns.internal.corp) IP="10.0.2.53" ;;
  *) IP="$TARGET" ;;
esac

# Check route table reachability
is_reachable=false
if [ "$IP" = "10.0.2.53" ] || [ "$IP" = "10.0.2.100" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    if [ "$IP" = "10.0.2.53" ] && echo "$line" | grep -Eq "^[[:space:]]*(10\.0\.2\.53|10\.0\.2\.0/24|default|0\.0\.0\.0/0)[[:space:]]+via[[:space:]]+10\.0\.1\.1([[:space:]]|$)"; then
      if echo "$line" | grep -Eq "[[:space:]]+dev[[:space:]]+"; then
        if echo "$line" | grep -Eq "[[:space:]]+dev[[:space:]]+eth0([[:space:]]|$)"; then
          is_reachable=true
        fi
      else
        is_reachable=true
      fi
    elif [ "$IP" = "10.0.2.100" ] && echo "$line" | grep -Eq "^[[:space:]]*(10\.0\.2\.100(/32)?|10\.0\.2\.0/24|default|0\.0\.0\.0/0)[[:space:]]+via[[:space:]]+10\.0\.1\.1([[:space:]]|$)"; then
      if echo "$line" | grep -Eq "[[:space:]]+dev[[:space:]]+"; then
        if echo "$line" | grep -Eq "[[:space:]]+dev[[:space:]]+eth0([[:space:]]|$)"; then
          is_reachable=true
        fi
      else
        is_reachable=true
      fi
    fi
  done < "$ROUTES"
fi

if [ "$is_reachable" = "false" ]; then
  echo "traceroute: sendto: Network is unreachable" >&2
  exit 2
fi

echo "traceroute to $TARGET ($IP), 30 hops max, 60 byte packets"
echo " 1  router-gw (10.0.1.1)  0.412 ms  0.320 ms  0.285 ms"
if [ "$IP" = "10.0.2.53" ]; then
  echo " 2  dns-internal (10.0.2.53)  0.645 ms  0.580 ms  0.520 ms"
elif [ "$IP" = "10.0.2.100" ]; then
  echo " 2  app-api-01 (10.0.2.100)  0.782 ms  0.690 ms  0.645 ms"
fi
exit 0
TRACE_EOF
chmod 0755 "$INCIDENT_ROOT/bin/traceroute"

# 14. Provision Command: ./bin/getent
cat << 'GETENT_EOF' > "$INCIDENT_ROOT/bin/getent"
#!/bin/bash
set -euo pipefail

CMD="${1:-}"
TARGET="${2:-}"

if [ "$CMD" != "hosts" ] || [ -z "$TARGET" ]; then
  echo "Usage: ./bin/getent hosts <hostname>" >&2
  exit 1
fi

case "$TARGET" in
  api.internal.corp)
    printf "10.0.2.100       api.internal.corp\n"
    exit 0
    ;;
  dns.internal.corp)
    printf "10.0.2.53        dns.internal.corp\n"
    exit 0
    ;;
  router-gw.internal.corp)
    printf "10.0.1.1         router-gw.internal.corp\n"
    exit 0
    ;;
  client-01.internal.corp)
    printf "10.0.1.10        client-01.internal.corp\n"
    exit 0
    ;;
  *)
    exit 2
    ;;
esac
GETENT_EOF
chmod 0755 "$INCIDENT_ROOT/bin/getent"

# 15. Provision Command: ./bin/ss
cat << 'SS_EOF' > "$INCIDENT_ROOT/bin/ss"
#!/bin/bash
set -euo pipefail

cat << 'SS_OUT'
Netid State  Recv-Q Send-Q Local Address:Port Peer Address:Port Process
udp   UNCONN 0      0      10.0.1.10:48291    0.0.0.0:*
tcp   LISTEN 0      128    127.0.0.1:9090     0.0.0.0:*
SS_OUT
exit 0
SS_EOF
chmod 0755 "$INCIDENT_ROOT/bin/ss"

# 16. Provision Command: ./bin/network-audit
cat << 'AUDIT_EOF' > "$INCIDENT_ROOT/bin/network-audit"
#!/bin/bash
set -euo pipefail

fail() {
  echo "[AUDIT FAILED] $*" >&2
  exit 1
}

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$DIR")"
ROUTES="$ROOT/run/net/routes.state"
[ -f "$ROUTES" ] || ROUTES="$ROOT/config/routes.conf"

[ -f "$ROUTES" ] || fail "Routing table configuration missing."

# 1. Audit route to destination services network
has_valid_route=false
while IFS= read -r line || [ -n "$line" ]; do
  [[ "$line" =~ ^[[:space:]]*# ]] && continue
  [[ "$line" =~ ^[[:space:]]*$ ]] && continue
  if echo "$line" | grep -Eq "^[[:space:]]*(default|0\.0\.0\.0/0|10\.0\.2\.0/24|10\.0\.2\.100(/32)?)[[:space:]]+via[[:space:]]+10\.0\.1\.1([[:space:]]|$)"; then
    if echo "$line" | grep -Eq "[[:space:]]+dev[[:space:]]+"; then
      if echo "$line" | grep -Eq "[[:space:]]+dev[[:space:]]+eth0([[:space:]]|$)"; then
        has_valid_route=true
      fi
    else
      has_valid_route=true
    fi
  fi
done < "$ROUTES"

[ "$has_valid_route" = "true" ] || fail "No route found forwarding 10.0.2.0/24 via gateway 10.0.1.1 on interface eth0 in routing table."

# 3. Audit DNS configuration
[ -f "$ROOT/config/resolv.conf" ] || fail "DNS configuration config/resolv.conf is missing."
grep -Eq "^[[:space:]]*nameserver[[:space:]]+10\.0\.2\.53([[:space:]]|$)" "$ROOT/config/resolv.conf" || fail "DNS resolver must be configured to 10.0.2.53."

# 4. Generate success marker
cat << 'MARKER_EOF' > "$ROOT/reports/audit-success.marker"
NETWORK_STATUS=RECOVERED
CLIENT_IP=10.0.1.10
ACTIVE_GATEWAY=10.0.1.1
TARGET_REACHABLE=10.0.2.100
DNS_RESOLVED=api.internal.corp
AUDITED_BY=netops_audit_v1
MARKER_EOF

echo "[AUDIT OK] Network connectivity fully restored and verified. Generated reports/audit-success.marker."
exit 0
AUDIT_EOF
chmod 0755 "$INCIDENT_ROOT/bin/network-audit"

echo "Network outage incident environment provisioned successfully."
