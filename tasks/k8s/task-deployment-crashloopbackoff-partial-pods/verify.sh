#!/bin/bash
set -e

echo "=== Kubernetes Lab Verification: Deployment CrashLoopBackOff ==="

# Set KUBECONFIG if k3s is used
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
fi

# 1. Verify kubectl is functional
if ! kubectl get nodes >/dev/null 2>&1; then
    echo "ERROR: Unable to communicate with Kubernetes cluster."
    exit 1
fi

# 2. Check if deployment api-deployment exists
if ! kubectl get deployment api-deployment -n default >/dev/null 2>&1; then
    echo "ERROR: Deployment 'api-deployment' not found in default namespace."
    exit 1
fi

# 3. Check requested replicas count (should be 15)
REPLICAS=$(kubectl get deployment api-deployment -n default -o jsonpath='{.spec.replicas}')
if [ "$REPLICAS" -ne 15 ]; then
    echo "ERROR: Expected deployment spec.replicas to be 15, but found $REPLICAS."
    exit 1
fi

# 4. Check ready replicas count (must be 15)
READY_REPLICAS=$(kubectl get deployment api-deployment -n default -o jsonpath='{.status.readyReplicas}')
if [ -z "$READY_REPLICAS" ]; then
    READY_REPLICAS=0
fi

echo "Current Deployment Ready Replicas: $READY_REPLICAS / 15"

if [ "$READY_REPLICAS" -lt 15 ]; then
    echo "ERROR: Deployment is not fully ready. Required: 15/15, Actual: $READY_REPLICAS/15."
    exit 1
fi

# 5. Check if any pods under label app=api-server are in CrashLoopBackOff, Error, or ImagePullBackOff
CRASHING_PODS=$(kubectl get pods -n default -l app=api-server --no-headers | grep -E "CrashLoopBackOff|Error|ImagePullBackOff" | wc -l || true)
if [ "$CRASHING_PODS" -gt 0 ]; then
    echo "ERROR: Detected $CRASHING_PODS pod(s) still stuck in CrashLoopBackOff or Error status."
    exit 1
fi

# 6. Check ConfigMap contents for DB_HOST parameter
CM_DATA=$(kubectl get configmap api-config -n default -o jsonpath='{.data.app\.json}' 2>/dev/null || true)
if ! echo "$CM_DATA" | grep -q "DB_HOST"; then
    echo "ERROR: ConfigMap 'api-config' is missing required 'DB_HOST' setting."
    exit 1
fi

echo "SUCCESS: Deployment 'api-deployment' is fully healthy with 15/15 ready replicas and no crashing pods!"
exit 0
