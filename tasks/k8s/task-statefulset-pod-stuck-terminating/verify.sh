#!/bin/bash
set -e

echo "=== Kubernetes Lab Verification: StatefulSet Pod Stuck Terminating ==="

# Set KUBECONFIG if k3s is used
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
fi

# 1. Verify cluster connection
if ! kubectl get nodes >/dev/null 2>&1; then
    echo "ERROR: Unable to communicate with Kubernetes cluster."
    exit 1
fi

# 2. Check if StatefulSet db-ss exists
if ! kubectl get statefulset db-ss -n default >/dev/null 2>&1; then
    echo "ERROR: StatefulSet 'db-ss' not found in default namespace."
    exit 1
fi

# 3. Verify no pods in namespace default are stuck in Terminating status
TERMINATING_PODS=$(kubectl get pods -n default --no-headers | grep -i "Terminating" | wc -l || true)
if [ "$TERMINATING_PODS" -gt 0 ]; then
    echo "ERROR: Found $TERMINATING_PODS pod(s) still stuck in Terminating state."
    exit 1
fi

# 4. Check if pod db-ss-0 still has custom blocking finalizer
FINALIZERS=$(kubectl get pod db-ss-0 -n default -o jsonpath='{.metadata.finalizers}' 2>/dev/null || true)
if echo "$FINALIZERS" | grep -q "custom.finalizer/cleanup-protection"; then
    echo "ERROR: Pod 'db-ss-0' still contains blocking finalizer 'custom.finalizer/cleanup-protection'."
    exit 1
fi

# 5. Check ready replicas count for StatefulSet db-ss (must be 3/3)
READY_REPLICAS=$(kubectl get statefulset db-ss -n default -o jsonpath='{.status.readyReplicas}')
if [ -z "$READY_REPLICAS" ]; then
    READY_REPLICAS=0
fi

echo "Current StatefulSet Ready Replicas: $READY_REPLICAS / 3"

if [ "$READY_REPLICAS" -lt 3 ]; then
    echo "ERROR: StatefulSet 'db-ss' is not fully ready. Required: 3/3, Actual: $READY_REPLICAS/3."
    exit 1
fi

echo "SUCCESS: Pod 'db-ss-0' stuck in Terminating is resolved, and StatefulSet 'db-ss' is 3/3 READY!"
exit 0
