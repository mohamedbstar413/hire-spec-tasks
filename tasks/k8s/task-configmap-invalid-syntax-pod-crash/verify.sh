#!/bin/bash
set -e

echo "=== Kubernetes Lab Verification: ConfigMap Syntax Invalid and Pod Crash ==="

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

# 3. Check ConfigMap app-config content for syntax error string
CONFIG_DATA=$(kubectl get configmap app-config -n default -o jsonpath='{.data.default\.conf}' 2>/dev/null || true)
if [[ "$CONFIG_DATA" == *"invalid_directive_broken_syntax"* ]]; then
    echo "ERROR: ConfigMap 'app-config' still contains the invalid directive syntax ('invalid_directive_broken_syntax')."
    exit 1
fi

# 4. Check readyReplicas for deployment web-app (must be >= 1)
READY_REPLICAS=$(kubectl get deployment web-app -n default -o jsonpath='{.status.readyReplicas}')
if [ -z "$READY_REPLICAS" ]; then
    READY_REPLICAS=0
fi

echo "Current Deployment Ready Replicas: $READY_REPLICAS / 1"

if [ "$READY_REPLICAS" -lt 1 ]; then
    echo "ERROR: Deployment 'web-app' is not ready. Required: 1/1, Actual: $READY_REPLICAS/1."
    echo "Check 'kubectl logs -l app=web-app' to view configuration parsing errors."
    exit 1
fi

# 5. Verify pod status phase
RUNNING_PODS=$(kubectl get pods -n default -l app=web-app --field-selector=status.phase=Running -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)
if [ -z "$RUNNING_PODS" ]; then
    echo "ERROR: No pods for deployment 'web-app' are in Running phase."
    exit 1
fi

echo "SUCCESS: ConfigMap syntax fixed and Deployment 'web-app' is 1/1 READY!"
exit 0
