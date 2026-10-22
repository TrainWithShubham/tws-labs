printf 'apiVersion: v1\nkind: PersistentVolumeClaim\nmetadata:\n  name: app-storage\nspec:\n  accessModes:\n    - ReadWriteOnce\n  resources:\n    requests:\n      storage: 500Mi\n' > app/pvc.yaml

