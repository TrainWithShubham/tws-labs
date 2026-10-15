awk '$1=="Max" && $2=="processes" {print $3}' /proc/self/limits > maxprocs.txt
