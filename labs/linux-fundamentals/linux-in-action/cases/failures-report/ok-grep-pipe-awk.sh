grep ' 500 ' logs/service.log | awk '{print $1, $7}' > reports/failures.txt
