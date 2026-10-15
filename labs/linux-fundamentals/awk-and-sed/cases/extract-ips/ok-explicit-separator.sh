awk -F' ' '{ print $1 }' web-server/access.log > client-ips.txt
