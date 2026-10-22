printf 'apiVersion: v1\nkind: PersistentVolume\nmetadata:\n  name: local-pv\nspec:\n  capacity:\n    storage: 1Gi\n  accessModes:\n    - ReadWriteOnce\n  persistentVolumeReclaimPolicy: Delete\n  hostPath:\n    path: /mnt/data\n' > app/pv.yaml

