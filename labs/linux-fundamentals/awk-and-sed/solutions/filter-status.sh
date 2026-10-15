awk '$9 == 500 {print $1, $7}' web-server/access.log > server-errors.txt

