sed -i 's/storage: 1Gi/storage: 5Gi/' app/pv.yaml
sed -i 's/- ReadWriteOnce/- ReadWriteMany/' app/pv.yaml
