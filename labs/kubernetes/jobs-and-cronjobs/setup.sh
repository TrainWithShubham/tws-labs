#!/bin/bash
set -e

mkdir -p batch

cat <<'YAML' > batch/cleanup-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: cleanup
spec:
  backoffLimit: 2
  template:
    spec:
      containers:
        - name: cleanup
          image: busybox:1.36
          command: ["sh", "-c", "echo working"]
      restartPolicy: Always
YAML

cat <<'YAML' > batch/backup-cronjob.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: backup
spec:
  schedule: "30 2 * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: backup
              image: busybox:1.36
              command: ["sh", "-c", "echo working"]
          restartPolicy: OnFailure
YAML
