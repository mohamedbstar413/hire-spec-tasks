#!/bin/bash
set -e

echo "Deploying Kubernetes environment for CronJob Not Creating Jobs task..."

# Deploy CronJob data-backup-cron with suspend: true preventing Job execution
cat << 'EOF' | kubectl apply -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: data-backup-cron
  namespace: default
spec:
  schedule: "* * * * *"
  concurrencyPolicy: Forbid
  suspend: true
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: busybox:1.36
            command: ["/bin/sh", "-c", "echo 'Backup completed successfully!'; exit 0"]
          restartPolicy: OnFailure
EOF

echo "Setup completed: CronJob data-backup-cron deployed with suspend: true (No Jobs being created)."
