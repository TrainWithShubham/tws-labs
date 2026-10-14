printf 'apiVersion: v1\nkind: Service\nmetadata:\n  name: nginx-service\nspec:\n  type: ClusterIP\n  selector:\n    app: nginx\n  ports:\n    - protocol: TCP\n      port: 80\n      targetPort: 80\n' > app/service.yaml

