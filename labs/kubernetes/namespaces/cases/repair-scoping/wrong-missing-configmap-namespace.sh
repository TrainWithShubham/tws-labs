# Removes namespace from monitoring-ns.yaml, but forgets ConfigMap
sed -i '/namespace: default/d' app/monitoring-ns.yaml

