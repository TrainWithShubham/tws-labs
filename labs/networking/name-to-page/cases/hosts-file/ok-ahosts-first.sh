getent ahosts localhost | awk 'NR==1{print $1}' > ip.txt
