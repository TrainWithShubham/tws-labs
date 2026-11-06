sed -i '/namespace: default/d' app/monitoring-ns.yaml
sed -i '/metadata:/a \  namespace: development' app/app-config.yaml

