#!/bin/bash
set -e

echo "=== Kubernetes Lab Verification: StatefulSet PVC Not Deleted After Deletion ==="

# Set KUBECONFIG if k3s is used
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
fi

# 1. Verify cluster connection
if ! kubectl get nodes >/dev/null 2>&1; then
    echo "ERROR: Unable to communicate with Kubernetes cluster."
    exit 1
fi

# 2. Check if StatefulSet stateful-app exists
if ! kubectl get statefulset stateful-app -n default >/dev/null 2>&1; then
    echo "ERROR: StatefulSet 'stateful-app' not found in default namespace."
    exit 1
fi

# 3. Verify persistentVolumeClaimRetentionPolicy settings
WHEN_DELETED=$(kubectl get statefulset stateful-app -n default -o jsonpath='{.spec.persistentVolumeClaimRetentionPolicy.whenDeleted}' 2>/dev/null || true)
WHEN_SCALED=$(kubectl get statefulset stateful-app -n default -o jsonpath='{.spec.persistentVolumeClaimRetentionPolicy.whenScaled}' 2>/dev/null || true)

echo "Current persistentVolumeClaimRetentionPolicy - whenDeleted: '$WHEN_DELETED', whenScaled: '$WHEN_SCALED'"

if [ "$WHEN_DELETED" != "Delete" ]; then
    echo "ERROR: persistentVolumeClaimRetentionPolicy.whenDeleted is not set to 'Delete'. Current: '$WHEN_DELETED'"
    exit 1
fi

if [ "$WHEN_SCALED" != "Delete" ]; then
    echo "ERROR: persistentVolumeClaimRetentionPolicy.whenScaled is not set to 'Delete'. Current: '$WHEN_SCALED'"
    exit 1
fi

echo "SUCCESS: StatefulSet 'stateful-app' has persistentVolumeClaimRetentionPolicy correctly configured to auto-delete PVCs on scale down and deletion!"
exit 0
