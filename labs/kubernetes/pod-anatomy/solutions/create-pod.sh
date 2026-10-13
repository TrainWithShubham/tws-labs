printf 'apiVersion: v1\nkind: Pod\nmetadata:\n  name: web-pod\n  labels:\n    app: web\nspec:\n  containers:\n    - name: nginx\n      image: nginx:1.27\n' > app/pod.yaml
