awk '{print $1}' web-server/access.log | sort > client-ips.txt
