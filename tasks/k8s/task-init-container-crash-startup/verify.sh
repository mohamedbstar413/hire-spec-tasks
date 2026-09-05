#!/bin/bash
set -e

echo "=== Kubernetes Lab Verification: Init Container Crash Startup ==="

# Set KUBECONFIG if k3s is used
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
fi

# 1. Verify cluster connection
if ! kubectl get nodes >/dev/null 2>&1; then
    echo "ERROR: Unable to communicate with Kubernetes cluster."
    exit 1
fi

# 2. Check if deployment web-app exists
if ! kubectl get deployment web-app -n default >/dev/null 2>&1; then
    echo "ERROR: Deployment 'web-app' not found in default namespace."
    exit 1
fi

# 3. Verify no pods matching app=web-app are stuck in Init:CrashLoopBackOff or Init:Error
INIT_CRASHING_PODS=$(kubectl get pods -n default -l app=web-app --no-headers | grep -iE "Init:CrashLoopBackOff|Init:Error|CrashLoopBackOff" | wc -l || true)
if [ "$INIT_CRASHING_PODS" -gt 0 ]; then
    echo "ERROR: Found $INIT_CRASHING_PODS pod(s) still stuck in Init:CrashLoopBackOff or CrashLoopBackOff."
    exit 1
fi

# 4. Verify readyReplicas for deployment web-app is 1
READY_REPLICAS=$(kubectl get deployment web-app -n default -o jsonpath='{.status.readyReplicas}')
if [ -z "$READY_REPLICAS" ]; then
    READY_REPLICAS=0
fi

echo "Current Deployment Ready Replicas: $READY_REPLICAS / 1"

if [ "$READY_REPLICAS" -lt 1 ]; then
    echo "ERROR: Deployment 'web-app' is not fully ready. Required: 1/1, Actual: $READY_REPLICAS/1."
    exit 1
fi

# 5. Check if the typo 'db-servcie' is resolved in deployment initContainers spec
INIT_SPEC=$(kubectl get deployment web-app -n default -o jsonpath='{.spec.template.spec.initContainers[*].command}' 2>/dev/null || true)
if echo "$INIT_SPEC" | grep -q "db-servcie"; then
    echo "ERROR: Deployment initContainers spec still contains the typo 'db-servcie'."
    exit 1
fi

echo "SUCCESS: Init container crash resolved and Deployment 'web-app' is 1/1 READY!"
exit 0
