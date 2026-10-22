printf 'apiVersion: v1\nkind: PersistentVolumeClaim\nmetadata:\n  name: app-storage\nspec:\n  accessModes:\n    - ReadWriteMany\n  resources:\n    requests:\n      storage: 1Gi\n' > app/pvc.yaml

