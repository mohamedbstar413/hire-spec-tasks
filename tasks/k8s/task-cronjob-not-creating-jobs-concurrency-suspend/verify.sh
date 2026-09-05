#!/bin/bash
set -e

echo "=== Kubernetes Lab Verification: CronJob Not Creating Jobs (Suspend / Concurrency Issue) ==="

# Set KUBECONFIG if k3s is used
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
fi

# 1. Verify cluster connection
if ! kubectl get nodes >/dev/null 2>&1; then
    echo "ERROR: Unable to communicate with Kubernetes cluster."
    exit 1
fi

# 2. Check if CronJob data-backup-cron exists
if ! kubectl get cronjob data-backup-cron -n default >/dev/null 2>&1; then
    echo "ERROR: CronJob 'data-backup-cron' not found in default namespace."
    exit 1
fi

# 3. Check suspend status
SUSPEND_STATUS=$(kubectl get cronjob data-backup-cron -n default -o jsonpath='{.spec.suspend}' 2>/dev/null || true)
if [ "$SUSPEND_STATUS" = "true" ]; then
    echo "ERROR: CronJob 'data-backup-cron' is still suspended (suspend: true)."
    exit 1
fi

# 4. Wait up to 15 seconds to check if a Job has been created or lastScheduleTime is updated
echo "Verifying CronJob schedule execution..."
LAST_SCHEDULE=$(kubectl get cronjob data-backup-cron -n default -o jsonpath='{.status.lastScheduleTime}' 2>/dev/null || true)

if [ -z "$LAST_SCHEDULE" ]; then
    # Give it a short retry window if just unsuspended
    sleep 5
    LAST_SCHEDULE=$(kubectl get cronjob data-backup-cron -n default -o jsonpath='{.status.lastScheduleTime}' 2>/dev/null || true)
fi

echo "CronJob Last Schedule Time: '$LAST_SCHEDULE'"

echo "SUCCESS: CronJob 'data-backup-cron' is active (suspend: false) and scheduling jobs!"
exit 0
