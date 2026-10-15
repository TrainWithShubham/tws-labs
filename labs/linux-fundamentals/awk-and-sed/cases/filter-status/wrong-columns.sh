awk '$9 == 500 {print $1, $9}' web-server/access.log > server-errors.txt
