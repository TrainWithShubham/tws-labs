mkdir -p batch
[ -f batch/job.yaml ] || printf '%s\n' 'apiVersion: batch/v1' 'kind: Job' 'metadata:' '  name: report' 'spec:' '  template:' '    spec:' '      containers:' '        - name: report' '          image: busybox:1.36' '          command: ["sh", "-c", "echo working"]' '      restartPolicy: Never' > batch/job.yaml
