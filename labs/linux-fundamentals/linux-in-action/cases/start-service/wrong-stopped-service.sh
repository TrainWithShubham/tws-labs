./start.sh
kill $(awk '{print $1}' payment.pid)
sleep 0.1
