awk '$9 == 500 {print $1, $7}' logs/service.log > reports/failures.txt
