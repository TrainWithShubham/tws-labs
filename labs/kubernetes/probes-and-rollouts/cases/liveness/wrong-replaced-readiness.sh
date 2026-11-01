sed -i 's|^          readinessProbe:$|          livenessProbe:|' app/deployment.yaml
