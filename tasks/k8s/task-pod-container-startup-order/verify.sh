#!/bin/bash
set -e

echo "=== Kubernetes Lab Verification: Container Startup Order ==="

# Set KUBECONFIG if k3s is used
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
fi

# 1. Verify cluster connection
if ! kubectl get nodes >/dev/null 2>&1; then
    echo "ERROR: Unable to communicate with Kubernetes cluster."
    exit 1
fi

# 2. Check if deployment app-deployment exists
if ! kubectl get deployment app-deployment -n default >/dev/null 2>&1; then
    echo "ERROR: Deployment 'app-deployment' not found in default namespace."
    exit 1
fi

# 3. Verify initContainers spec contains config-initializer
INIT_CONTAINERS=$(kubectl get deployment app-deployment -n default -o jsonpath='{.spec.template.spec.initContainers[*].name}' 2>/dev/null || true)
if ! echo "$INIT_CONTAINERS" | grep -q "config-initializer"; then
    echo "ERROR: Container 'config-initializer' is not configured under 'initContainers'."
    exit 1
fi

# 4. Check readyReplicas for deployment app-deployment (must be 1)
READY_REPLICAS=$(kubectl get deployment app-deployment -n default -o jsonpath='{.status.readyReplicas}')
if [ -z "$READY_REPLICAS" ]; then
    READY_REPLICAS=0
fi

echo "Current Deployment Ready Replicas: $READY_REPLICAS / 1"

if [ "$READY_REPLICAS" -lt 1 ]; then
    echo "ERROR: Deployment 'app-deployment' is not fully ready. Required: 1/1, Actual: $READY_REPLICAS/1."
    exit 1
fi

# 5. Verify no pods matching app=multi-container-app are stuck in CrashLoopBackOff or Error
CRASHING_PODS=$(kubectl get pods -n default -l app=multi-container-app --no-headers | grep -iE "CrashLoopBackOff|Error" | wc -l || true)
if [ "$CRASHING_PODS" -gt 0 ]; then
    echo "ERROR: Detected $CRASHING_PODS pod(s) still stuck in CrashLoopBackOff or Error status."
    exit 1
fi

echo "SUCCESS: Container startup order enforced via initContainers! Deployment 'app-deployment' is 1/1 READY!"
exit 0
