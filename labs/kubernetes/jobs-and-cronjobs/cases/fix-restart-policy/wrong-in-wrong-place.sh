sed -i '/restartPolicy: Always/d' batch/cleanup-job.yaml
sed -i 's/^spec:/spec:\n  restartPolicy: OnFailure/' batch/cleanup-job.yaml
