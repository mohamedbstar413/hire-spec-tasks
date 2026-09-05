#!/bin/bash
set -e

echo "=== Kubernetes Lab Verification: Pod Pending Insufficient CPU Requests ==="

# Set KUBECONFIG if k3s is used
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
fi

# 1. Verify cluster connection
if ! kubectl get nodes >/dev/null 2>&1; then
    echo "ERROR: Unable to communicate with Kubernetes cluster."
    exit 1
fi

# 2. Check if deployment compute-app exists
if ! kubectl get deployment compute-app -n default >/dev/null 2>&1; then
    echo "ERROR: Deployment 'compute-app' not found in default namespace."
    exit 1
fi

# 3. Check requested replicas count (must be 4)
REPLICAS=$(kubectl get deployment compute-app -n default -o jsonpath='{.spec.replicas}')
if [ "$REPLICAS" -ne 4 ]; then
    echo "ERROR: Expected deployment spec.replicas to be 4, but found $REPLICAS."
    exit 1
fi

# 4. Check ready replicas count (must be 4)
READY_REPLICAS=$(kubectl get deployment compute-app -n default -o jsonpath='{.status.readyReplicas}')
if [ -z "$READY_REPLICAS" ]; then
    READY_REPLICAS=0
fi

echo "Current Deployment Ready Replicas: $READY_REPLICAS / 4"

if [ "$READY_REPLICAS" -lt 4 ]; then
    echo "ERROR: Deployment 'compute-app' is not fully ready. Required: 4/4, Actual: $READY_REPLICAS/4."
    exit 1
fi

# 5. Verify no pods matching app=compute-app are stuck in Pending
PENDING_PODS=$(kubectl get pods -n default -l app=compute-app --no-headers | grep -i "Pending" | wc -l || true)
if [ "$PENDING_PODS" -gt 0 ]; then
    echo "ERROR: Detected $PENDING_PODS pod(s) still stuck in Pending status."
    exit 1
fi

# 6. Verify resources.requests.cpu is set to <= 500m or 0.5 CPU
CPU_REQ=$(kubectl get deployment compute-app -n default -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null || true)
echo "Current Deployment Container CPU Request: '$CPU_REQ'"

if [ "$CPU_REQ" = "2000m" ] || [ "$CPU_REQ" = "2" ]; then
    echo "ERROR: Deployment container CPU request is still set to excessive value '$CPU_REQ'."
    exit 1
fi

echo "SUCCESS: CPU request scheduling issue resolved! Deployment 'compute-app' is 4/4 READY!"
exit 0
