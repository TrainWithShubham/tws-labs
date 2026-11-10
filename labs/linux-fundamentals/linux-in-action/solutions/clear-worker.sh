kill $(awk '{print $1}' .worker.pid)
rm .service.lock
