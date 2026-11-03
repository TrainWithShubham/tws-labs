kill -9 $(awk '{print $1}' .worker.pid)
rm -f .service.lock
