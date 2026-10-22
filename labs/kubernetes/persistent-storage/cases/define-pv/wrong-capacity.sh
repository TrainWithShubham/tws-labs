printf 'apiVersion: v1\nkind: PersistentVolume\nmetadata:\n  name: local-pv\nspec:\n  capacity:\n    storage: 500Mi\n  accessModes:\n    - ReadWriteOnce\n  persistentVolumeReclaimPolicy: Retain\n  hostPath:\n    path: /mnt/data\n' > app/pv.yaml

