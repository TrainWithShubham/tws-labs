# Leaves namespace in monitoring-ns.yaml, only fixes ConfigMap
sed -i '/metadata:/a \  namespace: development' app/app-config.yaml

